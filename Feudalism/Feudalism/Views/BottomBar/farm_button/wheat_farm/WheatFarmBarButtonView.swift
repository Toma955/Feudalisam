//
//  WheatFarmBarButtonView.swift
//  Feudalism
//
//  Gumb „Pšenica” (wheat farm) u donjem izborniku – kategorija Farma.
//

import SwiftUI

struct WheatFarmBarButtonView: View {
    @EnvironmentObject private var gameState: GameState
    var action: () -> Void
    var iconOnly: Bool = false

    var body: some View {
        Button(action: action) {
            VStack(alignment: .center, spacing: 2) {
                BarIconView(assetName: "wheat", systemName: "wheat")
                if !iconOnly {
                    Text(LocalizedStrings.string(for: "wheat_farm", language: gameState.appLanguage))
                        .font(.system(size: 10))
                        .foregroundStyle(.white.opacity(0.9))
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .buttonStyle(.plain)
    }
}
