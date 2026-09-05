import Foundation
import SwiftUI
import UserNotifications

/// Claude 認證狀態。
///
/// 這個 App 呼叫 `claude -p` 時完全沒有帶憑證——ProcessRunner 不碰 environment，
/// 環境裡也沒有 ANTHROPIC_API_KEY，所以 claude CLI 是用 `claude login` 存在
/// macOS Keychain（service = "Claude Code-credentials"）裡的登入憑證，
/// 也就是使用者本人的 Claude 帳號。
///
/// 憑證會過期，而這個 App 跑在 LaunchAgent 底下、照片流程又是背景觸發的，
/// 失效時使用者很可能只會發現「日記沒更新」卻不知道原因。這裡負責讓它可見。
enum AuthState: Equatable {
    case unknown          // 還沒查過
    case checking         // 正在驗證
    case ok               // 最近一次呼叫成功
    case noCredentials    // Keychain 裡根本沒有憑證，沒登入過
    case expired(String)  // 呼叫回報認證失敗，需要重新登入

    var label: String {
        switch self {
        case .unknown:        return "尚未檢查"
        case .checking:       return "檢查中…"
        case .ok:             return "已登入"
        case .noCredentials:  return "未登入"
        case .expired:        return "認證失效"
        }
    }

    var symbol: String {
        switch self {
        case .unknown:        return "questionmark.circle"
        case .checking:       return "arrow.triangle.2.circlepath"
        case .ok:             return "checkmark.circle.fill"
        case .noCredentials:  return "person.crop.circle.badge.xmark"
        case .expired:        return "exclamationmark.triangle.fill"
        }
    }

    var color: Color {
        switch self {
        case .unknown, .checking: return .secondary
        case .ok:                 return .green
        case .noCredentials:      return .orange
        case .expired:            return .red
        }
    }

    /// 需要使用者出手處理的狀態——選單列圖示會因此改變。
    var needsAttention: Bool {
        switch self {
        case .noCredentials, .expired: return true
        default:                       return false
        }
    }
}

@MainActor
final class AuthService: ObservableObject {
    static let shared = AuthService()

    @Published private(set) var state: AuthState = .unknown
    @Published private(set) var lastCheck: Date?

    private var notifiedForCurrentFailure = false

    private init() {}

    // MARK: - 便宜的檢查：Keychain 裡有沒有憑證

    /// 只確認「登入過」，不保證沒過期。不需要網路、不花 token。
    private func hasStoredCredentials() -> Bool {
        guard let securityPath = findExecutable("security") else { return false }
        let result = try? runProcess(
            securityPath,
            ["find-generic-password", "-s", "Claude Code-credentials"]
        )
        return (result?.exitCode ?? 1) == 0
    }

    /// App 啟動與 popover 打開時呼叫。不花 token，只做本機判斷：
    /// 沒有憑證 → 明確標成未登入；有憑證但先前失敗過 → 保留失敗狀態不要蓋掉。
    func refreshLocally() {
        if !hasStoredCredentials() {
            setState(.noCredentials)
            return
        }
        if case .expired = state { return }  // 失敗狀態要留著，直到重新驗證成功
        if case .ok = state { return }
        setState(.unknown)
    }

    // MARK: - 真實驗證：跑一次最小的 claude 呼叫

    /// 花費極小的一次 haiku 呼叫，用來確認憑證真的還能用。
    func verify() {
        guard state != .checking else { return }
        setState(.checking)

        Task.detached(priority: .utility) {
            guard let claudePath = findExecutable("claude") else {
                await MainActor.run { self.setState(.noCredentials) }
                return
            }
            let result = try? runProcess(
                claudePath,
                ["-p", "ping", "--output-format", "json", "--model", "haiku"]
            )
            await MainActor.run {
                guard let result else {
                    self.setState(.expired("無法執行 claude"))
                    return
                }
                if result.exitCode == 0 {
                    self.markSuccess()
                } else {
                    let msg = result.stderr.isEmpty ? "exit \(result.exitCode)" : result.stderr
                    if Self.looksLikeAuthFailure(msg) {
                        self.setState(.expired(Self.firstLine(msg)))
                    } else {
                        // 不是認證問題（可能是網路或額度），不要誤報成要重新登入
                        self.setState(.unknown)
                    }
                }
            }
        }
    }

    // MARK: - 由實際的日記／照片流程回報

    /// 任何一次 claude 呼叫成功後呼叫，把狀態拉回正常。
    func markSuccess() {
        notifiedForCurrentFailure = false
        setState(.ok)
        lastCheck = Date()
    }

    /// claude 呼叫失敗時呼叫。只有在 stderr 看起來像認證問題時才改狀態並通知，
    /// 避免把網路錯誤、額度用盡誤判成「要重新登入」。
    func noteFailure(_ message: String) {
        guard Self.looksLikeAuthFailure(message) else { return }
        setState(.expired(Self.firstLine(message)))
        lastCheck = Date()
        if !notifiedForCurrentFailure {
            notifiedForCurrentFailure = true
            postNotification()
        }
    }

    static func looksLikeAuthFailure(_ message: String) -> Bool {
        let m = message.lowercased()
        let needles = [
            "authentication", "unauthorized", "not authenticated", "invalid api key",
            "please run /login", "claude login", "oauth", "token has expired",
            "expired", "401", "403", "credentials",
        ]
        return needles.contains { m.contains($0) }
    }

    private static func firstLine(_ s: String) -> String {
        s.split(separator: "\n").first.map(String.init)?
            .trimmingCharacters(in: .whitespaces) ?? s
    }

    private func setState(_ new: AuthState) {
        if state != new { state = new }
    }

    // MARK: - 讓使用者實際去登入

    /// `claude login` 是互動式的，GUI App 沒辦法自己跑完，
    /// 所以開一個 Terminal 視窗把指令送進去。
    func openLogin() {
        let claudePath = findExecutable("claude") ?? "claude"
        let script = """
        tell application "Terminal"
            activate
            do script "\(claudePath) login"
        end tell
        """
        guard let osascript = findExecutable("osascript") else { return }
        Task.detached(priority: .userInitiated) {
            _ = try? runProcess(osascript, ["-e", script])
        }
    }

    // MARK: - 通知

    func requestNotificationPermissionIfNeeded() {
        UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    private func postNotification() {
        let content = UNMutableNotificationContent()
        content.title = "日記沒有上傳"
        content.body = "Claude 認證已失效，請從選單列重新登入。"
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "diary-auth-\(UUID().uuidString)",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
    }
}

/// 每個 `claude -p` 呼叫點在拿到結果後呼叫這個，讓認證狀態能反映真實情況。
/// 這些呼叫發生在背景執行緒，所以跳回 main actor 更新 @Published。
func reportAuth(exitCode: Int32, stderr: String) {
    Task { @MainActor in
        if exitCode == 0 {
            AuthService.shared.markSuccess()
        } else {
            AuthService.shared.noteFailure(stderr)
        }
    }
}
