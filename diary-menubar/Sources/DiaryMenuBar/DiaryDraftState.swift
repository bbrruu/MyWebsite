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

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()
    private static let draftKey = "diary-draft-text-v1"

    private init() {
        rawText = UserDefaults.standard.string(forKey: Self.draftKey) ?? ""
    }

    func clear() {
        rawText = ""
        phase = .editing
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
                phase = .reviewing(fields, dateStr: dateStr)
            } catch {
                phase = .failure(error.localizedDescription)
            }
        }
    }

    func confirmSave(fields: DiaryFields, dateStr: String) {
        phase = .saving(fields, dateStr: dateStr)

        Task {
            do {
                let outcome = try await Task.detached(priority: .userInitiated) {
                    try DiaryService.save(fields: fields, dateStr: dateStr)
                }.value
                rawText = ""
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
