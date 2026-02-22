//
//  MainMenuView.swift
//  Feudalism
//
//  Glavni izbornik: mutna vatrena pozadina, stakleni kvadrat s menijem i ikonama.
//

import SwiftUI
import AppKit

private let glassCornerRadius: CGFloat = 24
private let buttonCornerRadius: CGFloat = 22
private let tileWidth: CGFloat = 260
private let tileHeight: CGFloat = 64
private let iconSize: CGFloat = 36
private let iconColumnWidth: CGFloat = 52

struct MainMenuView: View {
    @EnvironmentObject private var gameState: GameState
    @State private var showPostavke = false
    @State private var showGameSetup = false

    var body: some View {
        ZStack {
            FireBackgroundView()

            // Stakleni obi kvadrat – meni s ikonama
            VStack(spacing: 28) {
                Text("Feudalism")
                    .font(.custom("Georgia", size: 44))
                    .fontWeight(.bold)
                    .foregroundStyle(.white.opacity(0.98))
                    .shadow(color: .black.opacity(0.4), radius: 2, x: 0, y: 1)
                    .padding(.bottom, 8)

                VStack(spacing: 14) {
                    menuTile(title: "Solo", icon: "play.circle.fill") {
                        gameState.startNewGameWithSetup(humanName: "Igrač", selectedAIProfileIds: [])
                    }
                    menuTile(title: "Nova igra", icon: "plus.circle.fill") {
                        showGameSetup = true
                    }
                    menuTile(title: "Map Editor", icon: "map.fill") {
                        gameState.openMapEditor()
                    }
                    menuTile(title: "Postavke", icon: "gearshape.fill") {
                        showPostavke = true
                    }
                    menuTile(title: "Izlaz", icon: "power") {
                        exitApp()
                    }
                }
            }
            .padding(40)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: glassCornerRadius, style: .continuous))
            .shadow(color: .black.opacity(0.35), radius: 24, y: 12)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(56)
        }
        .sheet(isPresented: $showPostavke) {
            PostavkeView()
        }
        .sheet(isPresented: $showGameSetup) {
            GameSetupView()
                .environmentObject(gameState)
        }
    }

    private func menuTile(title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            ZStack(alignment: .leading) {
                HStack {
                    Spacer(minLength: 0)
                    Text(title)
                        .font(.custom("Georgia", size: 20))
                        .foregroundStyle(.white.opacity(0.9))
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                HStack(spacing: 0) {
                    Image(systemName: icon)
                        .font(.system(size: iconSize))
                        .foregroundStyle(.white.opacity(0.95))
                        .frame(width: iconColumnWidth, height: tileHeight, alignment: .leading)
                        .padding(.leading, 14)
                    Spacer(minLength: 0)
                }
            }
            .frame(width: tileWidth, height: tileHeight)
            .background(.white.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: buttonCornerRadius, style: .continuous))
        }
        .buttonStyle(PlainMenuButtonStyle())
    }

    private func exitApp() {
        NSApplication.shared.terminate(nil)
    }
}

private struct PlainMenuButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.85 : 1)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

#Preview {
    MainMenuView()
        .environmentObject(GameState())
        .frame(width: 800, height: 600)
}
