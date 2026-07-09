import SwiftUI

@main
struct DiaryMenuBarApp: App {
    @StateObject private var photoWatcher = PhotoWatcher.shared
    @StateObject private var photoProcessor = PhotoProcessor.shared
    @StateObject private var draftState = DiaryDraftState.shared

    init() {
        PhotoWatcher.shared.start()
        _ = PhotoProcessor.shared // 確保它的 Combine 訂閱在 App 啟動時就建立好
    }

    var body: some Scene {
        MenuBarExtra(
            "寫日記",
            systemImage: photoWatcher.queue.isEmpty ? "book.closed" : "photo.badge.plus"
        ) {
            DiaryPopoverView()
                .environmentObject(photoWatcher)
                .environmentObject(photoProcessor)
                .environmentObject(draftState)
        }
        .menuBarExtraStyle(.window)
    }
}
