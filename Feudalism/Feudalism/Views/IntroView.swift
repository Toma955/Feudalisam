//
//  IntroView.swift
//  Feudalism
//
//  Početna animacija: crni ekran, soundtrack, "Feudalism" slovo po slovo (veliki napis), zatim smanjenje i prikaz pozadine + izbornika.
//

import SwiftUI
import AppKit

private let titleFull = "Feudallinteligence"
private let bigTitleFontSize: CGFloat = 140
private let cloudTitleFontSize: CGFloat = 38
/// Sporija animacija: slovo po slovo tijekom učitavanja.
private let letterInterval: TimeInterval = 0.22
private let moveToCloudDuration: TimeInterval = 0.58

struct IntroView: View {
    @EnvironmentObject private var gameState: GameState
    @EnvironmentObject private var assetLoader: GameAssetLoader
    var onComplete: () -> Void

    @State private var visibleLetterCount: Int = 0
    @State private var menuOpacity: Double = 0
    @State private var didComplete: Bool = false
    @State private var animationComplete: Bool = false
    /// Kad true, naslov animira gore u obli kvadrat (oblak), zatim onComplete.
    @State private var titleMovingToCloud: Bool = false

    private var visibleTitle: String {
        let n = min(visibleLetterCount, titleFull.count)
        return String(titleFull.prefix(n))
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            MainMenuView(hideTitle: true)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .opacity(menuOpacity)
                .animation(.easeInOut(duration: moveToCloudDuration), value: menuOpacity)
                .allowsHitTesting(menuOpacity > 0.99)
                .environmentObject(gameState)

            // Naslov: u centru veliki, pa animacija gore u oblak (obli kvadrat)
            GeometryReader { geo in
                let centerY = geo.size.height / 2
                let cloudY: CGFloat = 6 + 37
                VStack(spacing: 0) {
                    Text(titleMovingToCloud ? titleFull : visibleTitle)
                        .font(.custom("Georgia", size: titleMovingToCloud ? cloudTitleFontSize : bigTitleFontSize))
                        .fontWeight(.bold)
                        .foregroundStyle(.white.opacity(0.98))
                        .shadow(color: .black.opacity(0.5), radius: titleMovingToCloud ? 2 : 4, x: 0, y: titleMovingToCloud ? 1 : 2)
                        .padding(.horizontal, titleMovingToCloud ? 36 : 0)
                        .padding(.vertical, titleMovingToCloud ? 18 : 0)
                        .background(titleMovingToCloud ? AnyShapeStyle(Material.ultraThin) : AnyShapeStyle(Color.clear))
                        .clipShape(RoundedRectangle(cornerRadius: titleMovingToCloud ? 20 : 0, style: .continuous))
                        .shadow(color: .black.opacity(titleMovingToCloud ? 0.3 : 0), radius: titleMovingToCloud ? 12 : 0, y: titleMovingToCloud ? 6 : 0)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .position(x: geo.size.width / 2, y: titleMovingToCloud ? cloudY : centerY)
                        .animation(.easeInOut(duration: moveToCloudDuration), value: titleMovingToCloud)

                    if !titleMovingToCloud { Spacer(minLength: 0).frame(maxHeight: .infinity) }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.leading, 56)
                .padding(.trailing, 56)
                .padding(.top, 56)
            }
            .ignoresSafeArea()

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
            if loaded { tryComplete() }
        }
        .onChange(of: animationComplete) { _, done in
            if done { tryComplete() }
        }
    }

    /// Kad su animacija i učitavanje gotovi, prvo animiraj naslov gore u oblak, pa onComplete.
    private func tryComplete() {
        guard !didComplete else { return }
        if animationComplete && assetLoader.isLoaded {
            startMoveToCloud()
        }
    }

    private func startMoveToCloud() {
        guard !didComplete else { return }
        visibleLetterCount = titleFull.count
        titleMovingToCloud = true
        menuOpacity = 1
        DispatchQueue.main.asyncAfter(deadline: .now() + moveToCloudDuration) {
            didComplete = true
            onComplete()
        }
    }

    /// Animacija naslova slovo po slovo; kad su sva slova i učitavanje gotovi, naslov ide gore u oblak.
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
        let animationDuration = letterInterval * Double(titleFull.count) + 0.2
        DispatchQueue.main.asyncAfter(deadline: .now() + animationDuration) {
            animationComplete = true
        }
    }
}

#Preview {
    IntroView(onComplete: {})
        .environmentObject(GameState())
        .environmentObject(GameAssetLoader.shared)
        .frame(width: 800, height: 600)
}
