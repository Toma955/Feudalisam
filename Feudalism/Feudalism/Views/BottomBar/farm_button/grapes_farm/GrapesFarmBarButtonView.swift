//
//  GrapesFarmBarButtonView.swift
//  Feudalism
//
//  Gumb „Grožđe” (grapes) u donjem izborniku – kategorija Farma, biljke.
//

import SwiftUI

struct GrapesFarmBarButtonView: View {
    @EnvironmentObject private var gameState: GameState
    var action: () -> Void
    var iconOnly: Bool = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                BarIconView(assetName: "grapes", systemName: "leaf.circle.fill")
                if !iconOnly {
                    Text(LocalizedStrings.string(for: "grapes_farm", language: gameState.appLanguage))
                        .font(.system(size: 10))
                        .foregroundStyle(.white.opacity(0.9))
                }
            }
        }
        .buttonStyle(.plain)
    }
}
