//
//  IntroView.swift
//  Feudalism
//
//  Početna animacija: crni ekran, soundtrack, "Feudalism" slovo po slovo (veliki napis), zatim smanjenje i prikaz pozadine + izbornika.
//

import SwiftUI
import AppKit

private let titleFull = "Feudalism"
private let bigTitleFontSize: CGFloat = 140
private let mainMenuTitleFontSize: CGFloat = 44
/// Sporija animacija: slovo po slovo i prijelaz.
private let letterInterval: TimeInterval = 0.22
private let holdAfterLetters: TimeInterval = 1.0
private let transitionDuration: TimeInterval = 1.4

struct IntroView: View {
    @EnvironmentObject private var gameState: GameState
    var onComplete: () -> Void

    @State private var visibleLetterCount: Int = 0
    @State private var bigTitleScale: CGFloat = 1
    @State private var bigTitleOpacity: Double = 1
    @State private var menuOpacity: Double = 0

    private var visibleTitle: String {
        let n = min(visibleLetterCount, titleFull.count)
        return String(titleFull.prefix(n))
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            MainMenuView()
                .opacity(menuOpacity)
                .allowsHitTesting(menuOpacity > 0.99)
                .environmentObject(gameState)

            // Naslov na istoj poziciji kao u MainMenuView (padding 56, 40, VStack spacing 28, title + .bottom 8)
            VStack(spacing: 28) {
                Text(visibleTitle)
                    .font(.custom("Georgia", size: bigTitleFontSize))
                    .fontWeight(.bold)
                    .foregroundStyle(.white.opacity(0.98))
                    .shadow(color: .black.opacity(0.5), radius: 4, x: 0, y: 2)
                    .scaleEffect(bigTitleScale)
                    .opacity(bigTitleOpacity)
                    .padding(.bottom, 8)
                Spacer(minLength: 0)
            }
            .padding(40)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(56)
        }
        .onAppear { startSequence() }
    }

    private func startSequence() {
        let volume = gameState.audioMusicVolume
        AudioManager.shared.playIntroSoundtrackIfAvailable(volume: volume)

        SceneKitMapView.preloadGameAssets()

        for i in 1...titleFull.count {
            DispatchQueue.main.asyncAfter(deadline: .now() + letterInterval * Double(i)) {
                withAnimation(.easeOut(duration: 0.08)) {
                    visibleLetterCount = i
                }
            }
        }

        let lettersEnd = letterInterval * Double(titleFull.count) + holdAfterLetters
        DispatchQueue.main.asyncAfter(deadline: .now() + lettersEnd) {
            withAnimation(.easeInOut(duration: transitionDuration)) {
                bigTitleScale = mainMenuTitleFontSize / bigTitleFontSize
                bigTitleOpacity = 0
                menuOpacity = 1
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + transitionDuration) {
                onComplete()
            }
        }
    }
}

#Preview {
    IntroView(onComplete: {})
        .environmentObject(GameState())
        .frame(width: 800, height: 600)
}
