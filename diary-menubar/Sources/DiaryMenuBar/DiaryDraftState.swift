import Foundation

/// 文字草稿的唯一真相來源，原因跟 PhotoProcessor 一樣：MenuBarExtra 的彈出視窗
/// 關掉再打開會重新掛載 View，放在 View 的 @State 裡草稿會不見。這裡額外把
/// 原文存進 UserDefaults，就算 App 被殺掉重開也不會遺失。
@MainActor
final class DiaryDraftState: ObservableObject {
    static let shared = DiaryDraftState()

    @Published var rawText: String {
        didSet { UserDefaults.standard.set(rawText, forKey: Self.draftKey) }
    }
    @Published var date: Date = Date()
    @Published var phase: Phase = .editing

    /// Claude 產生的欄位在確認前是可以改的，所以要放在這裡而不是包在 Phase 的
    /// associated value 裡——那個沒辦法做雙向綁定。一併存進 UserDefaults，
    /// 理由跟 rawText 一樣：彈出視窗關掉再打開會重新掛載 View。
    @Published var fields: DiaryFields = .empty {
        didSet {
            if let data = try? JSONEncoder().encode(fields) {
                UserDefaults.standard.set(data, forKey: Self.fieldsKey)
            }
        }
    }

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()
    private static let draftKey = "diary-draft-text-v1"
    private static let fieldsKey = "diary-draft-fields-v1"

    private init() {
        rawText = UserDefaults.standard.string(forKey: Self.draftKey) ?? ""
        if let data = UserDefaults.standard.data(forKey: Self.fieldsKey),
           let saved = try? JSONDecoder().decode(DiaryFields.self, from: data) {
            fields = saved
        }
    }

    func clear() {
        rawText = ""
        fields = .empty
        UserDefaults.standard.removeObject(forKey: Self.fieldsKey)
        phase = .editing
        date = Date()
    }

    /// App 是常駐跑好幾天的（LaunchAgent），date 若只在 App 啟動當下算一次 Date()，
    /// 跨過午夜後就會停在舊的那天。只有在草稿是空的（還沒開始寫）時才自動校正，
    /// 已經在寫、甚至刻意選了補寫的舊日期時絕對不能動它。
    func refreshDateIfFresh() {
        guard rawText.isEmpty, case .editing = phase else { return }
        date = Date()
    }

    func organize() {
        let text = rawText
        let dateStr = Self.dateFormatter.string(from: date)
        phase = .organizing

        Task {
            do {
                let fields = try await Task.detached(priority: .userInitiated) {
                    try DiaryService.organize(rawText: text, dateStr: dateStr)
                }.value
                self.fields = fields
                phase = .reviewing(dateStr: dateStr)
            } catch {
                phase = .failure(error.localizedDescription)
            }
        }
    }

    func confirmSave(dateStr: String) {
        let edited = fields          // 使用者改過的版本才是要存的
        phase = .saving(dateStr: dateStr)

        Task {
            do {
                let outcome = try await Task.detached(priority: .userInitiated) {
                    try DiaryService.save(fields: edited, dateStr: dateStr)
                }.value
                rawText = ""
                self.fields = .empty
                UserDefaults.standard.removeObject(forKey: Self.fieldsKey)
                if outcome.pushed {
                    phase = .success("已儲存並推送：\(outcome.filePath)")
                } else {
                    phase = .failure("已儲存＋commit，但 push 失敗（\(outcome.filePath)）：\(outcome.pushError ?? "未知錯誤")")
                }
            } catch {
                phase = .failure(error.localizedDescription)
            }
        }
    }
}
