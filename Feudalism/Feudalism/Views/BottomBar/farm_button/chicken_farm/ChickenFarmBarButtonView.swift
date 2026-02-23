//
//  ChickenFarmBarButtonView.swift
//  Feudalism
//
//  Gumb „Kokoš” (chicken) u donjem izborniku – kategorija Farma.
//

import SwiftUI

struct ChickenFarmBarButtonView: View {
    @EnvironmentObject private var gameState: GameState
    var action: () -> Void
    var iconOnly: Bool = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                BarIconView(assetName: "chicken", systemName: "bird.fill")
                if !iconOnly {
                    Text(LocalizedStrings.string(for: "chicken_farm", language: gameState.appLanguage))
                        .font(.system(size: 10))
                        .foregroundStyle(.white.opacity(0.9))
                }
            }
        }
        .buttonStyle(.plain)
    }
}
