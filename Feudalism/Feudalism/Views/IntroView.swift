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
/// Sporija animacija: slovo po slovo tijekom učitavanja.
private let letterInterval: TimeInterval = 0.22

struct IntroView: View {
    @EnvironmentObject private var gameState: GameState
    @EnvironmentObject private var assetLoader: GameAssetLoader
    var onComplete: () -> Void

    @State private var visibleLetterCount: Int = 0
    @State private var bigTitleScale: CGFloat = 1
    @State private var bigTitleOpacity: Double = 1
    @State private var menuOpacity: Double = 0
    @State private var didComplete: Bool = false

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

            if !assetLoader.isLoaded {
                VStack(spacing: 8) {
                    ProgressView(value: assetLoader.loadProgress)
                        .tint(.white)
                        .frame(maxWidth: 280)
                    Text(assetLoader.loadStatus.isEmpty ? "Učitavanje…" : assetLoader.loadStatus)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.9))
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 16)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                .padding(.bottom, 48)
            }
        }
        .onAppear { startSequence() }
        .onChange(of: assetLoader.isLoaded) { _, loaded in
            if loaded, !didComplete {
                didComplete = true
                onComplete()
            }
        }
    }

    /// Animacija naslova tijekom učitavanja; izbornik se prikaže tek kad je učitavanje 100% (onChange(isLoaded)).
    private func startSequence() {
        let volume = gameState.audioMusicVolume
        AudioManager.shared.playIntroSoundtrackIfAvailable(volume: volume)

        Task { await assetLoader.loadAllIfNeeded() }

        for i in 1...titleFull.count {
            DispatchQueue.main.asyncAfter(deadline: .now() + letterInterval * Double(i)) {
                withAnimation(.easeOut(duration: 0.08)) {
                    visibleLetterCount = i
                }
            }
        }
    }
}

#Preview {
    IntroView(onComplete: {})
        .environmentObject(GameState())
        .environmentObject(GameAssetLoader.shared)
        .frame(width: 800, height: 600)
}
