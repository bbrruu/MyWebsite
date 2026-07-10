import Foundation
import Combine

enum PhotoPhase {
    case idle
    case waiting // 有照片、已轉檔+讀完 EXIF，但還沒呼叫 claude，等使用者按「整理」
    case describing
    case reviewing(PhotoFields)
    case saving(PhotoFields)
    case success(String)
    case failure(String)
}

/// 照片處理狀態的唯一真相來源。刻意不放在 View 的 @State 裡——MenuBarExtra 的彈出視窗
/// 每次關閉再打開，SwiftUI 都會重新掛載 View（.task(id:) 也會跟著重新觸發），如果狀態
/// 放在 View 裡，使用者關掉再打開視窗就會讓還在跑的 claude -p 被「遺忘」、又觸發一次
/// 重複呼叫。這裡用一個跟 App 生命週期綁在一起的 singleton，處理只會針對同一張照片跑一次。
///
/// 照片一出現只會自動做「轉檔 + 讀 EXIF」這種本機、不呼叫 claude 的準備工作；
/// 真正呼叫 claude 一定要使用者在畫面上按下「整理」才會觸發（startDescribing）。
@MainActor
final class PhotoProcessor: ObservableObject {
    static let shared = PhotoProcessor()

    @Published var phase: PhotoPhase = .idle
    @Published var photoDate: Date = Date()
    @Published var normalizedImagePath: String = ""
    @Published var editedCaption: String = ""

    private var cancellables = Set<AnyCancellable>()
    private var currentPath: String?

    private init() {
        PhotoWatcher.shared.$queue
            .receive(on: DispatchQueue.main)
            .sink { [weak self] queue in
                self?.handleQueueChange(queue)
            }
            .store(in: &cancellables)
    }

    private func handleQueueChange(_ queue: [String]) {
        guard let first = queue.first else {
            currentPath = nil
            phase = .idle
            return
        }
        guard first != currentPath else { return } // 已經在處理（或處理完）這張了，不要重複觸發
        currentPath = first
        prepareWaiting(path: first)
    }

    /// 只做本機的轉檔 + 讀 EXIF，不呼叫 claude，讓使用者在按「整理」前就能先看到縮圖跟預設日期。
    private func prepareWaiting(path: String) {
        phase = .waiting
        normalizedImagePath = ""
        editedCaption = ""
        photoDate = Date()

        Task {
            let normalizedPath = (try? await Task.detached(priority: .userInitiated) {
                try PhotoService.normalizeToJPEG(sourcePath: path, workDir: NSTemporaryDirectory())
            }.value) ?? path
            guard currentPath == path else { return }

            normalizedImagePath = normalizedPath
            photoDate = PhotoService.exifCaptureDate(imagePath: normalizedPath) ?? Date()
        }
    }

    var dateStr: String { Self.dateFormatter.string(from: photoDate) }

    /// 使用者確認日期沒問題（且當天已有日記）後手動觸發，這一步才會真的呼叫 claude。
    /// Google Drive 同步中的檔案偶爾還是會在這一步才第一次被鎖住（isStable 那關過了不代表
    /// 之後不會再被鎖），失敗時自動重試幾次，比直接丟錯誤給使用者更穩。
    func startDescribing() {
        guard let path = currentPath, case .waiting = phase else { return }
        phase = .describing
        let dateStrAtStart = dateStr
        let imagePath = normalizedImagePath.isEmpty ? path : normalizedImagePath

        Task {
            await attemptDescribe(path: path, imagePath: imagePath, dateStr: dateStrAtStart, retriesLeft: 3)
        }
    }

    private func attemptDescribe(path: String, imagePath: String, dateStr: String, retriesLeft: Int) async {
        do {
            let fields = try await Task.detached(priority: .userInitiated) {
                try PhotoService.describe(imagePath: imagePath, dateStr: dateStr)
            }.value
            guard currentPath == path else { return }
            editedCaption = fields.caption
            phase = .reviewing(fields)
        } catch {
            guard currentPath == path else { return }
            guard retriesLeft > 0 else {
                phase = .failure(error.localizedDescription)
                return
            }
            try? await Task.sleep(nanoseconds: 4_000_000_000)
            guard currentPath == path else { return }
            await attemptDescribe(path: path, imagePath: imagePath, dateStr: dateStr, retriesLeft: retriesLeft - 1)
        }
    }

    /// 失敗後想重試：回到 waiting，讓使用者可以再按一次「整理」（也會再走一次自動重試）。
    func retryFromFailure() {
        guard currentPath != nil else { return }
        phase = .waiting
    }

    func confirmSave(fields: PhotoFields) {
        guard let path = currentPath else { return }
        phase = .saving(fields)
        let dateStrAtSave = dateStr
        let imagePath = normalizedImagePath.isEmpty ? path : normalizedImagePath
        let caption = editedCaption

        Task {
            do {
                let outcome = try await Task.detached(priority: .userInitiated) {
                    try PhotoService.save(imagePath: imagePath, caption: caption, title: fields.title, dateStr: dateStrAtSave)
                }.value
                guard currentPath == path else { return }
                if outcome.pushed {
                    phase = .success("已儲存並推送：\(outcome.filePath)")
                } else {
                    phase = .failure("已儲存＋commit，但 push 失敗（\(outcome.filePath)）：\(outcome.pushError ?? "未知錯誤")")
                }
            } catch {
                guard currentPath == path else { return }
                phase = .failure(error.localizedDescription)
            }
        }
    }

    /// 跳過這張、或成功上傳後點「繼續」：把照片移出 Inbox，佇列往下一張推進。
    func dismissCurrent() {
        guard let path = currentPath else { return }
        PhotoWatcher.shared.markHandled(path: path)
        // markHandled 會更新 PhotoWatcher.queue，經由上面的訂閱自動觸發下一張或回到 .idle
    }

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()
}
