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

private let postavkeCategoryIconSize: CGFloat = 28
private let postavkeBottomBarHeight: CGFloat = 52
/// Postojeći okvir za meni (Solo, Nova igra, …); pri Nazad vraća se na ovo.
private let menuPanelMaxWidth: CGFloat = 320
private let menuPanelMaxHeight: CGFloat = 420
/// Veći okvir kad su otvorene postavke.
private let postavkePanelMaxWidth: CGFloat = 540
private let postavkePanelMaxHeight: CGFloat = 500
private let menuPostavkeTransitionDuration: Double = 0.28

struct MainMenuView: View {
    @EnvironmentObject private var gameState: GameState
    @State private var showPostavke = false
    @State private var showGameSetup = false
    @State private var showSoloSetup = false
    @State private var postavkeSection: PostavkeSection = .general
    @State private var showExitConfirmation = false

    var body: some View {
        ZStack {
            FireBackgroundView()

            // Stakleni obi kvadrat – meni (postojeći okvir) ili postavke (veći okvir); Nazad vraća u postojeći
            VStack(spacing: 0) {
                if showPostavke {
                    embeddedPostavkeContent
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .scale(scale: 0.92)),
                            removal: .opacity.combined(with: .scale(scale: 0.92))
                        ))
                } else if showSoloSetup {
                    SoloSetupView(isPresented: $showSoloSetup)
                        .environmentObject(gameState)
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .scale(scale: 0.92)),
                            removal: .opacity.combined(with: .scale(scale: 0.92))
                        ))
                } else {
                    menuContent
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .scale(scale: 0.92)),
                            removal: .opacity.combined(with: .scale(scale: 0.92))
                        ))
                }
            }
            .padding(40)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: glassCornerRadius, style: .continuous))
            .shadow(color: .black.opacity(0.35), radius: 24, y: 12)
            .frame(maxWidth: (showPostavke ? postavkePanelMaxWidth : (showSoloSetup ? 320 : menuPanelMaxWidth)), maxHeight: (showPostavke ? postavkePanelMaxHeight : (showSoloSetup ? 420 : menuPanelMaxHeight)))
            .padding(56)
            .animation(.easeInOut(duration: menuPostavkeTransitionDuration), value: showPostavke)
            .animation(.easeInOut(duration: menuPostavkeTransitionDuration), value: showSoloSetup)
        }
        .sheet(isPresented: $showGameSetup) {
            GameSetupView()
                .environmentObject(gameState)
        }
        .overlay {
            if showExitConfirmation {
                ZStack {
                    Color.black.opacity(0.6)
                        .ignoresSafeArea()
                        .onTapGesture { showExitConfirmation = false }
                    VStack(spacing: 20) {
                        Text("Jeste li sigurni da želite izaći?")
                            .font(.custom("Georgia", size: 18))
                            .fontWeight(.medium)
                            .foregroundStyle(.white.opacity(0.95))
                            .multilineTextAlignment(.center)
                        HStack(spacing: 16) {
                            Button("Ne") {
                                showExitConfirmation = false
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.white.opacity(0.25))
                            .foregroundStyle(.white)
                            Button("Da, izađi") {
                                showExitConfirmation = false
                                exitApp()
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.red.opacity(0.8))
                            .foregroundStyle(.white)
                        }
                    }
                    .padding(28)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: glassCornerRadius, style: .continuous))
                    .shadow(color: .black.opacity(0.4), radius: 20, y: 10)
                }
            }
        }
    }

    private var menuContent: some View {
        VStack(spacing: 28) {
            Text("Feudalism")
                .font(.custom("Georgia", size: 44))
                .fontWeight(.bold)
                .foregroundStyle(.white.opacity(0.98))
                .shadow(color: .black.opacity(0.4), radius: 2, x: 0, y: 1)
                .padding(.bottom, 8)

            VStack(spacing: 14) {
                menuTile(title: "Solo", icon: "play.circle.fill") {
                    withAnimation(.easeInOut(duration: menuPostavkeTransitionDuration)) {
                        showSoloSetup = true
                    }
                }
                menuTile(title: "Nova igra", icon: "plus.circle.fill") {
                    AudioManager.shared.stopIntroSoundtrack()
                    showGameSetup = true
                }
                menuTile(title: "Map Editor", icon: "map.fill") {
                    AudioManager.shared.stopIntroSoundtrack()
                    gameState.openMapEditor()
                }
                    menuTile(title: "Postavke", icon: "gearshape.fill") {
                        withAnimation(.easeInOut(duration: menuPostavkeTransitionDuration)) {
                            showPostavke = true
                        }
                    }
                menuTile(title: "Izlaz", icon: "power") {
                    AudioManager.shared.stopIntroSoundtrack()
                    showExitConfirmation = true
                }
            }
        }
    }

    private var embeddedPostavkeContent: some View {
        VStack(spacing: 0) {
            HStack {
                Button {
                    withAnimation(.easeInOut(duration: menuPostavkeTransitionDuration)) {
                        showPostavke = false
                    }
                } label: {
                    Label("Nazad", systemImage: "chevron.backward")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.white.opacity(0.95))
                }
                .buttonStyle(.plain)
                Spacer(minLength: 0)
                Text("Postavke")
                    .font(.custom("Georgia", size: 22))
                    .fontWeight(.bold)
                    .foregroundStyle(.white.opacity(0.98))
                Spacer(minLength: 0)
                Color.clear.frame(width: 80, height: 24)
            }
            .padding(.bottom, 12)

            ScrollView {
                PostavkeSectionContent(section: postavkeSection)
                    .environmentObject(gameState)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            HStack(spacing: 16) {
                Button {
                    if let prev = postavkeSection.previous { postavkeSection = prev }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.9))
                }
                .buttonStyle(.plain)

                HStack(spacing: 12) {
                    ForEach(PostavkeSection.allCases) { section in
                        Button {
                            postavkeSection = section
                        } label: {
                            Image(systemName: section.icon)
                                .font(.system(size: postavkeCategoryIconSize))
                                .foregroundStyle(section == postavkeSection ? .white : .white.opacity(0.5))
                        }
                        .buttonStyle(.plain)
                    }
                }

                Button {
                    if let next = postavkeSection.next { postavkeSection = next }
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.9))
                }
                .buttonStyle(.plain)
            }
            .frame(height: postavkeBottomBarHeight)
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
