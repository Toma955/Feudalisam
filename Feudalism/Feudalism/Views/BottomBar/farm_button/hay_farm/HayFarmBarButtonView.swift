//
//  HayFarmBarButtonView.swift
//  Feudalism
//
//  Gumb „Ječam” (barley) u donjem izborniku – kategorija Farma; ikona hops.png.
//

import SwiftUI

struct HayFarmBarButtonView: View {
    @EnvironmentObject private var gameState: GameState
    var action: () -> Void
    var iconOnly: Bool = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                BarIconView(assetName: "hop_icon", systemName: "leaf.fill")
                if !iconOnly {
                    Text(LocalizedStrings.string(for: "resource_hop", language: gameState.appLanguage))
                        .font(.system(size: 10))
                        .foregroundStyle(.white.opacity(0.9))
                }
            }
        }
        .buttonStyle(.plain)
    }
}
