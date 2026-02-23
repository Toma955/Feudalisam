//
//  SheepFarmBarButtonView.swift
//  Feudalism
//
//  Gumb „Ovca” (sheep farm) u donjem izborniku – kategorija Farma.
//

import SwiftUI

struct SheepFarmBarButtonView: View {
    @EnvironmentObject private var gameState: GameState
    var action: () -> Void
    var iconOnly: Bool = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                BarIconView(assetName: "sheep", systemName: "lamb")
                if !iconOnly {
                    Text(LocalizedStrings.string(for: "sheep_farm", language: gameState.appLanguage))
                        .font(.system(size: 10))
                        .foregroundStyle(.white.opacity(0.9))
                }
            }
        }
        .buttonStyle(.plain)
    }
}
