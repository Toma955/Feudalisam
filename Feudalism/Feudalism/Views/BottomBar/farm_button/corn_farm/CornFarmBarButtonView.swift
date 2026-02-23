//
//  CornFarmBarButtonView.swift
//  Feudalism
//
//  Gumb „Kukuruz” (corn) u donjem izborniku – kategorija Farma.
//

import SwiftUI

struct CornFarmBarButtonView: View {
    @EnvironmentObject private var gameState: GameState
    var action: () -> Void
    var iconOnly: Bool = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                BarIconView(assetName: "corn", systemName: "leaf.fill", size: iconOnly ? 34 : 52)
                if !iconOnly {
                    Text(LocalizedStrings.string(for: "corn_farm", language: gameState.appLanguage))
                        .font(.system(size: 10))
                        .foregroundStyle(.white.opacity(0.9))
                }
            }
        }
        .buttonStyle(.plain)
    }
}
