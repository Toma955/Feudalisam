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
    /// Kad je iconOnly true, veličina ikone (default 34); u proširenom farm panelu može biti 68 da ikona bude duplo veća.
    var iconOnlySize: CGFloat = 34

    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                BarIconView(assetName: "apple", systemName: "leaf.fill", size: iconOnly ? iconOnlySize : 52)
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
