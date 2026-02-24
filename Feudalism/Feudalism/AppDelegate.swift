//
//  AppDelegate.swift
//  Feudalism
//
//  Fullscreen + crna pozadina pri pokretanju.
//

import Cocoa

class AppDelegate: NSObject, NSApplicationDelegate {
    private static var hasEnteredFullScreen = false
    private var fullScreenRetryCount = 0
    private let fullScreenMaxRetries = 30

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        _ = HugeWall.checkAndLogTextureStatus(bundle: .main)
        tryEnterFullScreen()
    }

    func applicationWillTerminate(_ aNotification: Notification) {}

    private func tryEnterFullScreen() {
        guard !Self.hasEnteredFullScreen else { return }
        guard let window = NSApplication.shared.windows.first(where: { $0.isVisible }) ?? NSApplication.shared.windows.first else {
            fullScreenRetryCount += 1
            guard fullScreenRetryCount < fullScreenMaxRetries else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { self.tryEnterFullScreen() }
            return
        }
        Self.hasEnteredFullScreen = true
        window.backgroundColor = .black
        window.isOpaque = true
        window.contentView?.wantsLayer = true
        window.contentView?.layer?.backgroundColor = NSColor.black.cgColor
        window.collectionBehavior = [.fullScreenPrimary, .fullScreenAllowsTiling]
        if let screen = NSScreen.main {
            window.setFrame(screen.visibleFrame, display: true)
        }
        window.makeKeyAndOrderFront(nil)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            guard !window.styleMask.contains(.fullScreen) else { return }
            window.toggleFullScreen(nil)
        }
    }
}
