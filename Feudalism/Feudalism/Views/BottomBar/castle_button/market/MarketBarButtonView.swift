//
//  MarketBarButtonView.swift
//  Feudalism
//
//  Gumb „Market” u donjem izborniku (unutar castle_button).
//

import SwiftUI

struct MarketBarButtonView: View {
    @EnvironmentObject private var gameState: GameState
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                BarIconView(assetName: "market", systemName: "cart.fill")
                Text(LocalizedStrings.string(for: "market", language: gameState.appLanguage))
                    .font(.system(size: 10))
                    .foregroundStyle(.white.opacity(0.9))
            }
            .frame(minWidth: 60, minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
