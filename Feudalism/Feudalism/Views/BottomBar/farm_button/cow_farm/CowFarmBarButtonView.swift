//
//  CowFarmBarButtonView.swift
//  Feudalism
//
//  Gumb „Krava” (cow farm) u donjem izborniku – kategorija Farma.
//

import SwiftUI

struct CowFarmBarButtonView: View {
    @EnvironmentObject private var gameState: GameState
    var action: () -> Void
    var iconOnly: Bool = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                BarIconView(assetName: "cow", systemName: "cow")
                if !iconOnly {
                    Text(LocalizedStrings.string(for: "cow_farm", language: gameState.appLanguage))
                        .font(.system(size: 10))
                        .foregroundStyle(.white.opacity(0.9))
                }
            }
        }
        .buttonStyle(.plain)
    }
}
