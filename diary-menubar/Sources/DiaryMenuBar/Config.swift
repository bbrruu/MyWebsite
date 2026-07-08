import Foundation

enum Config {
    // 你的網站專案根目錄
    static let repoRoot = "/Users/bbrruu0722/Desktop/Develop/mywebsite"
    static let blogDir = repoRoot + "/src/content/blog"

    static let allowedCategories = ["旅行", "日常", "省思"]
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
