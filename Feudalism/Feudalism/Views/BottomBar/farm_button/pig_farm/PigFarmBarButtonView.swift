//
//  PigFarmBarButtonView.swift
//  Feudalism
//
//  Gumb „Svinja” (pig farm) u donjem izborniku – kategorija Farma.
//

import SwiftUI

struct PigFarmBarButtonView: View {
    @EnvironmentObject private var gameState: GameState
    var action: () -> Void
    var iconOnly: Bool = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                BarIconView(assetName: "pig", systemName: "hare.fill")
                if !iconOnly {
                    Text(LocalizedStrings.string(for: "pig_farm", language: gameState.appLanguage))
                        .font(.system(size: 10))
                        .foregroundStyle(.white.opacity(0.9))
                }
            }
        }
        .buttonStyle(.plain)
    }
}
