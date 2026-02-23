//
//  FeudalismApp.swift
//  Feudalism
//
//  Srednjovjekovna strateška igra – SwiftUI ulaz.
//

import SwiftUI

@main
struct FeudalismApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var gameState = GameState()

    var body: some Scene {
        WindowGroup {
            Group {
                if gameState.isShowingMainMenu {
                    MainMenuView()
                } else if gameState.isMapEditorMode {
                    MapEditorView()
                } else {
                    ContentView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.black)
            .environmentObject(gameState)
            .onChange(of: gameState.isShowingMainMenu) { if $0 { AudioManager.shared.stopMapMusic() } }
            .onChange(of: gameState.isMapEditorMode) { if $0 { AudioManager.shared.stopMapMusic() } }
        }
        .windowStyle(.automatic)
        .defaultSize(width: 1920, height: 1080)
        .commands {
            CommandGroup(replacing: .newItem) { }
            CommandGroup(replacing: .appInfo) { }      // About, Settings itd. – ne treba za igru
            CommandGroup(replacing: .windowArrangement) { }  // Window: Minimize, Zoom…
            CommandGroup(replacing: .windowList) { }   // Popis prozora
        }
    }
}
