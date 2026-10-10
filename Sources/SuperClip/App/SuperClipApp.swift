import SwiftUI
import AppKit
import SuperClipCore

@main
struct SuperClipApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}
