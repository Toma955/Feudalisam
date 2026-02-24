//
//  WallBarButtonView.swift
//  Feudalism
//
//  Gumb „Zid” u donjem izborniku (unutar castle_button).
//

import SwiftUI

struct WallBarButtonView: View {
    @EnvironmentObject private var gameState: GameState
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                BarIconView(assetName: "wall", systemName: "rectangle.3.group")
                Text(LocalizedStrings.string(for: "huge_wall", language: gameState.appLanguage))
                    .font(.system(size: 10))
                    .foregroundStyle(.white.opacity(0.9))
            }
            .frame(minWidth: 60, minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
