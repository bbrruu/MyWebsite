import SwiftUI

@main
struct DiaryMenuBarApp: App {
    @StateObject private var photoWatcher = PhotoWatcher.shared

    init() {
        PhotoWatcher.shared.start()
    }

    var body: some Scene {
        MenuBarExtra(
            "寫日記",
            systemImage: photoWatcher.queue.isEmpty ? "book.closed" : "photo.badge.plus"
        ) {
            DiaryPopoverView()
                .environmentObject(photoWatcher)
        }
        .menuBarExtraStyle(.window)
    }
}
