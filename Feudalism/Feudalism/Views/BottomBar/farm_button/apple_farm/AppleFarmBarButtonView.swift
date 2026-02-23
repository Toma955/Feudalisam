//
//  AppleFarmBarButtonView.swift
//  Feudalism
//
//  Gumb „Jabuka” (apple farm) u donjem izborniku – kategorija Farma.
//

import SwiftUI

struct AppleFarmBarButtonView: View {
    @EnvironmentObject private var gameState: GameState
    var action: () -> Void
    var iconOnly: Bool = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                BarIconView(assetName: "apple_farm", systemName: "apple.logo", size: iconOnly ? 34 : 52)
                if !iconOnly {
                    Text(LocalizedStrings.string(for: "apple_farm", language: gameState.appLanguage))
                        .font(.system(size: 10))
                        .foregroundStyle(.white.opacity(0.9))
                }
            }
        }
        .buttonStyle(.plain)
    }
}
