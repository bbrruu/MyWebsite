import SwiftUI

@main
struct DiaryMenuBarApp: App {
    var body: some Scene {
        MenuBarExtra("寫日記", systemImage: "book.closed") {
            DiaryPopoverView()
        }
        .menuBarExtraStyle(.window)
    }
}
