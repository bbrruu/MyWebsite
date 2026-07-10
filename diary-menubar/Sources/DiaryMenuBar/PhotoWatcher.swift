import Foundation
import Combine

/// 監看 Google Drive 裡的 DiaryPhotos/Inbox 資料夾，手機把照片分享進去後，
/// 這裡會偵測到新照片並排進佇列給 UI 處理。全程本機運作，沒有對外開放任何服務。
final class PhotoWatcher: ObservableObject {
    static let shared = PhotoWatcher()
    private init() {}

    @Published var queue: [String] = []

    private var source: DispatchSourceFileSystemObject?
    private var pollTimer: DispatchSourceTimer?
    private var fileDescriptor: CInt = -1
    private var debounceWorkItem: DispatchWorkItem?
    private var notifiedPaths = Set<String>()
    private var inboxDir = ""
    private var processedDir = ""

    private let imageExtensions: Set<String> = ["jpg", "jpeg", "png", "heic", "heif"]

    /// 找不到 Google Drive（還沒裝、還沒登入、或還沒同步出資料夾）就每隔一段時間自動重試，
    /// 這樣使用者晚一點才裝 Google Drive 也不用手動重開 App。
    func start() {
        guard source == nil else { return } // 已經在跑了，不重複啟動
        guard let inbox = Config.photoInboxDir, let processed = Config.photoProcessedDir else {
            DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 60) { [weak self] in
                self?.start()
            }
            return
        }
        inboxDir = inbox
        processedDir = processed

        let fm = FileManager.default
        try? fm.createDirectory(atPath: inboxDir, withIntermediateDirectories: true)
        try? fm.createDirectory(atPath: processedDir, withIntermediateDirectories: true)

        fileDescriptor = open(inboxDir, O_EVTONLY)
        guard fileDescriptor >= 0 else { return }

        let src = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fileDescriptor,
            eventMask: .write,
            queue: DispatchQueue.global(qos: .utility)
        )
        src.setEventHandler { [weak self] in
            self?.scheduleScan()
        }
        src.setCancelHandler { [weak self] in
            if let fd = self?.fileDescriptor, fd >= 0 { close(fd) }
        }
        src.resume()
        source = src

        scheduleScan() // App 沒開的時候進來的照片，啟動時補掃一次

        // Google Drive 同步中的檔案就算大小已經穩定，還是可能被同步行程鎖住
        // （open() 會丟 Resource deadlock avoided）。目錄本身在鎖釋放前不會再
        // 觸發變更事件，所以額外用一個定時器每 5 秒重掃一次，直到鎖真的放開。
        let timer = DispatchSource.makeTimerSource(queue: DispatchQueue.global(qos: .utility))
        timer.schedule(deadline: .now() + 5, repeating: 5)
        timer.setEventHandler { [weak self] in self?.scan() }
        timer.resume()
        pollTimer = timer
    }

    func stop() {
        source?.cancel()
        source = nil
        pollTimer?.cancel()
        pollTimer = nil
    }

    private func scheduleScan() {
        debounceWorkItem?.cancel()
        let item = DispatchWorkItem { [weak self] in self?.scan() }
        debounceWorkItem = item
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 1.5, execute: item)
    }

    private func scan() {
        let fm = FileManager.default
        guard let entries = try? fm.contentsOfDirectory(atPath: inboxDir) else { return }

        for entry in entries.sorted() {
            if entry.hasPrefix(".") { continue } // .DS_Store、同步中的暫存檔等

            let ext = (entry as NSString).pathExtension.lowercased()
            guard imageExtensions.contains(ext) else { continue }

            let fullPath = inboxDir + "/" + entry
            guard !notifiedPaths.contains(fullPath) else { continue }
            guard isStable(path: fullPath) else { continue }

            notifiedPaths.insert(fullPath)
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                if !self.queue.contains(fullPath) {
                    self.queue.append(fullPath)
                }
            }
        }
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
