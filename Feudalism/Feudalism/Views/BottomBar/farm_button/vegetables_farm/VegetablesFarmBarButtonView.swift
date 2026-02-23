//
//  VegetablesFarmBarButtonView.swift
//  Feudalism
//
//  Gumb „Povrče” (vegetables) u donjem izborniku – kategorija Farma.
//

import SwiftUI

struct VegetablesFarmBarButtonView: View {
    @EnvironmentObject private var gameState: GameState
    var action: () -> Void
    var iconOnly: Bool = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                BarIconView(assetName: "vegetable", systemName: "carrot.fill")
                if !iconOnly {
                    Text(LocalizedStrings.string(for: "vegetables_farm", language: gameState.appLanguage))
                        .font(.system(size: 10))
                        .foregroundStyle(.white.opacity(0.9))
                }
            }
        }
        .buttonStyle(.plain)
    }
}
