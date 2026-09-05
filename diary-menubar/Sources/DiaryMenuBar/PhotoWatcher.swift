import Foundation
import Combine

/// Google Drive 裡的 DiaryPhotos/Inbox 資料夾——手機把照片分享進去後，
/// 使用者在「圖片」分頁按「掃描 Inbox」才會真的去列目錄找新照片。
///
/// 原本用 DispatchSource + 背景輪詢自動監看，但長時間（好幾天）常駐後這條
/// 背景路徑偶爾會悄悄停止反應，使用者完全看不出來、也難以排查。改成完全
/// 由使用者手動觸發：按下去立刻掃描、立刻有結果，沒有任何長駐的背景機制
/// 可能默默壞掉。
final class PhotoWatcher: ObservableObject {
    static let shared = PhotoWatcher()
    private init() {}

    @Published var queue: [String] = []
    @Published var isScanning = false
    @Published var lastScanMessage: String?

    private var notifiedPaths = Set<String>()
    private var inboxDir = ""
    private var processedDir = ""
    private var directoriesReady = false

    private let imageExtensions: Set<String> = ["jpg", "jpeg", "png", "heic", "heif"]

    /// App 啟動時呼叫一次：只解析 Google Drive 路徑、建好資料夾，不做任何監看。
    /// 找不到 Google Drive（還沒裝、還沒登入）就每隔一段時間自動重試路徑解析，
    /// 這樣使用者晚一點才裝 Google Drive 也不用手動重開 App。
    func prepareDirectories() {
        guard !directoriesReady else { return }
        guard let inbox = Config.photoInboxDir, let processed = Config.photoProcessedDir else {
            DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 60) { [weak self] in
                self?.prepareDirectories()
            }
            return
        }
        inboxDir = inbox
        processedDir = processed

        let fm = FileManager.default
        try? fm.createDirectory(atPath: inboxDir, withIntermediateDirectories: true)
        try? fm.createDirectory(atPath: processedDir, withIntermediateDirectories: true)
        directoriesReady = true
    }

    /// 使用者按下「掃描 Inbox」時觸發，一次性列出資料夾、找新照片排進佇列。
    func scanNow() {
        guard directoriesReady else {
            lastScanMessage = "找不到 Google Drive，請確認已安裝並登入"
            return
        }
        isScanning = true
        lastScanMessage = nil

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }
            let found = self.performScan()
            DispatchQueue.main.async {
                self.isScanning = false
                self.lastScanMessage = found > 0 ? nil : "沒有偵測到新照片"
            }
        }
    }

    @discardableResult
    private func performScan() -> Int {
        let fm = FileManager.default
        guard let entries = try? fm.contentsOfDirectory(atPath: inboxDir) else { return 0 }
        var foundCount = 0

        for entry in entries.sorted() {
            if entry.hasPrefix(".") { continue } // .DS_Store、同步中的暫存檔等

            let ext = (entry as NSString).pathExtension.lowercased()
            guard imageExtensions.contains(ext) else { continue }

            let fullPath = inboxDir + "/" + entry
            guard !notifiedPaths.contains(fullPath) else { continue }
            guard isStable(path: fullPath) else { continue }

            notifiedPaths.insert(fullPath)
            foundCount += 1
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                if !self.queue.contains(fullPath) {
                    self.queue.append(fullPath)
                }
            }
        }
        return foundCount
    }

    /// 等檔案大小穩定下來，且真的能打開讀取，才算「新照片」就緒。
    /// Google Drive 同步中的檔案大小可能已經穩定，但同步行程還握著檔案鎖，
    /// 這時候 open() 會丟 Resource deadlock avoided——只看大小穩定會誤判成可讀。
    private func isStable(path: String) -> Bool {
        let fm = FileManager.default
        guard let size1 = try? fm.attributesOfItem(atPath: path)[.size] as? Int, size1 > 0 else { return false }
        Thread.sleep(forTimeInterval: 1.0)
        guard let size2 = try? fm.attributesOfItem(atPath: path)[.size] as? Int, size1 == size2 else { return false }

        // 刻意不用 FileHandle：它讀取失敗時丟的是 Objective-C exception，Swift 的
        // try/catch 接不住，遇到檔案鎖住會直接讓整個 App crash。改用底層 POSIX
        // open()/read()，失敗只會回傳錯誤碼，不會拋例外。
        let fd = open(path, O_RDONLY)
        guard fd >= 0 else { return false }
        defer { close(fd) }
        var buffer = [UInt8](repeating: 0, count: 16)
        let bytesRead = read(fd, &buffer, buffer.count)
        return bytesRead > 0
    }

    /// 使用者確認處理完（存檔成功或選擇跳過）後，把照片從 Inbox 移到 Processed，避免重複偵測。
    func markHandled(path: String) {
        queue.removeAll { $0 == path }
        notifiedPaths.remove(path)
        let fm = FileManager.default
        let filename = (path as NSString).lastPathComponent
        let dest = processedDir + "/" + filename
        try? fm.moveItem(atPath: path, toPath: dest)
    }
}
