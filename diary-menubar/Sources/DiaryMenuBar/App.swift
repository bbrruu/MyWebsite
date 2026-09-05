import SwiftUI

@main
struct DiaryMenuBarApp: App {
    @StateObject private var photoWatcher = PhotoWatcher.shared
    @StateObject private var photoProcessor = PhotoProcessor.shared
    @StateObject private var draftState = DiaryDraftState.shared
    @StateObject private var auth = AuthService.shared

    init() {
        PhotoWatcher.shared.prepareDirectories()
        _ = PhotoProcessor.shared // 確保它的 Combine 訂閱在 App 啟動時就建立好
        AuthService.shared.requestNotificationPermissionIfNeeded()
        AuthService.shared.refreshLocally()
    }

    var body: some Scene {
        // 用 label 閉包而不是 systemImage: 字串參數——後者在 queue 變化時不會可靠地
        // 重新算圖示（MenuBarExtra 已知的小毛病），閉包形式才會真的隨 @Published 更新。
        MenuBarExtra {
            DiaryPopoverView()
                .environmentObject(photoWatcher)
                .environmentObject(photoProcessor)
                .environmentObject(draftState)
                .environmentObject(auth)
        } label: {
            // 認證出問題優先蓋掉其他狀態——這是唯一會讓整條流程靜默失效的情況
            Image(systemName: menuBarSymbol)
        }
        .menuBarExtraStyle(.window)
    }

    private var menuBarSymbol: String {
        if auth.state.needsAttention { return "exclamationmark.triangle" }
        return photoWatcher.queue.isEmpty ? "book.closed" : "photo.badge.plus"
    }
}
