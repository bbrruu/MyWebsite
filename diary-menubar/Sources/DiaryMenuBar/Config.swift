import Foundation

enum Config {
    // 你的網站專案根目錄
    static let repoRoot = "/Users/bbrruu0722/Desktop/Develop/mywebsite"
    static let blogDir = repoRoot + "/src/content/blog"
    static let publicImagesDir = repoRoot + "/public/images"

    static let allowedCategories = ["旅行", "日常", "省思"]

    // Google Drive 桌面版把雲端硬碟掛載在 ~/Library/CloudStorage/GoogleDrive-<帳號>/<我的雲端硬碟>，
    // 帳號名稱因人而異，資料夾名稱也會因系統語言不同而不同（例如「My Drive」或「我的雲端硬碟」），
    // 所以兩層都用掃描的方式動態找，而不是寫死路徑。
    // 每次讀取都重新掃一次：這樣如果使用者是先裝好 App 才裝 Google Drive，之後重開 App 就會抓到。
    private static func discoverGoogleDriveRoot() -> String? {
        let fm = FileManager.default
        let cloudStorageDir = fm.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/CloudStorage").path
        guard let accounts = try? fm.contentsOfDirectory(atPath: cloudStorageDir) else { return nil }
        guard let account = accounts.first(where: { $0.hasPrefix("GoogleDrive-") }) else { return nil }
        let accountDir = cloudStorageDir + "/" + account

        guard let entries = try? fm.contentsOfDirectory(atPath: accountDir) else { return nil }
        let visibleDirs = entries.filter { entry in
            guard !entry.hasPrefix(".") else { return false }
            var isDir: ObjCBool = false
            fm.fileExists(atPath: accountDir + "/" + entry, isDirectory: &isDir)
            return isDir.boolValue
        }
        // 個人帳號通常只有一個「我的雲端硬碟」資料夾；如果還有共用雲端硬碟之類的，排除掉再取第一個。
        let myDrive = visibleDirs.first(where: { !$0.localizedCaseInsensitiveContains("shared") && !$0.contains("共用") })
            ?? visibleDirs.first
        guard let myDrive else { return nil }
        return accountDir + "/" + myDrive
    }

    /// 找不到 Google Drive（還沒裝、還沒登入）時回傳 nil，PhotoWatcher 會直接不啟動，不會出錯。
    static var photoInboxDir: String? {
        discoverGoogleDriveRoot().map { $0 + "/DiaryPhotos/Inbox" }
    }
    static var photoProcessedDir: String? {
        discoverGoogleDriveRoot().map { $0 + "/DiaryPhotos/Processed" }
    }

    static func relativePath(_ absolutePath: String) -> String {
        guard absolutePath.hasPrefix(repoRoot) else { return absolutePath }
        return String(absolutePath.dropFirst(repoRoot.count + 1))
    }
}

/// 在常見安裝路徑中尋找執行檔，因為選單列 App 不會繼承終端機的 shell PATH。
func findExecutable(_ name: String) -> String? {
    let home = FileManager.default.homeDirectoryForCurrentUser.path
    let candidates = [
        "\(home)/.local/bin/\(name)",
        "/opt/homebrew/bin/\(name)",
        "/usr/local/bin/\(name)",
        "/usr/bin/\(name)",
        "/bin/\(name)",
    ]
    for path in candidates where FileManager.default.isExecutableFile(atPath: path) {
        return path
    }
    return nil
}
