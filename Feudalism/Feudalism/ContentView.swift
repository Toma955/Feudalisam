//
//  ContentView.swift
//  Feudalism
//
//  Glavni ekran – puni zaslon (karta preko cijelog ekrana), na dnu gumb dvora, HUD gore.
//

import SwiftUI
import AppKit

/// Jednom pri pokretanju ispiše u konzolu zašto ikone (farm, food, castle, sword) nisu vidljive.
private func printIconDiagnostics() {
    let names = ["farm", "food", "castle", "sword"]
    print("---------- [Ikone] Dijagnostika ----------")
    if let rp = Bundle.main.resourcePath {
        print("[Ikone] Bundle resource path: \(rp)")
    }
    for sub in ["Icons", "Feudalism/Icons", "icons"] {
        if let url = Bundle.main.resourceURL?.appendingPathComponent(sub),
           (try? url.checkResourceIsReachable()) == true,
           let contents = try? FileManager.default.contentsOfDirectory(atPath: url.path) {
            print("[Ikone] Mapа '\(sub)' u bundleu sadrži: \(contents.sorted().joined(separator: ", "))")
        } else {
            print("[Ikone] Mapа '\(sub)' u bundleu: NE POSTOJI ili je prazna")
        }
    }
    for name in names {
        let fromAsset = NSImage(named: name)
        let fromIconsURL = Bundle.main.url(forResource: name, withExtension: "png", subdirectory: "Icons")
            ?? Bundle.main.url(forResource: name, withExtension: "png", subdirectory: "Feudalism/Icons")
        let fromIcons = fromIconsURL.flatMap { NSImage(contentsOf: $0) }
        if fromAsset != nil {
            print("[Ikone] \(name): OK iz Assets.xcassets (NSImage(named:))")
        } else if fromIcons != nil {
            print("[Ikone] \(name): OK iz mape Icons (\(fromIconsURL!.lastPathComponent))")
        } else {
            print("[Ikone] \(name): NIJE NAĐEN – NSImage(named:) = nil, u Icons: \(fromIconsURL != nil ? "datoteka postoji ali NSImage ne učitava" : "datoteka nije u bundleu (dodaj Icons u Copy Bundle Resources u Xcodeu)")")
        }
    }
    print("---------- [Ikone] Kraj ----------")
}

/// Učita NSImage za ikonu: prvo iz Assets.xcassets, pa iz mape Icons/icons u bundleu.
private func loadBarIcon(named name: String) -> NSImage? {
    if let img = NSImage(named: name) { return img }
    let subdirs = ["Icons", "icons", "Feudalism/Icons", "Feudalism/icons"]
    for sub in subdirs {
        if let url = Bundle.main.url(forResource: name, withExtension: "png", subdirectory: sub) {
            return NSImage(contentsOf: url)
        }
    }
    return nil
}

/// Ikona s asseta ili iz mape Icons; inače SF Symbol. Nazivi: farm, food, castle, sword.
private struct BarIcon: View {
    let assetName: String
    let systemName: String
    private var image: NSImage? { loadBarIcon(named: assetName) }
    private var hasAsset: Bool { image != nil }
    var body: some View {
        Group {
            if let nsImage = image {
                Image(nsImage: nsImage)
                    .resizable()
                    .scaledToFit()
            } else {
                Image(systemName: systemName)
                    .font(.system(size: 26))
            }
        }
        .frame(width: 44, height: 44)
        .foregroundStyle(.white.opacity(0.95))
    }
}

struct ContentView: View {
    @EnvironmentObject private var gameState: GameState
    @State private var showMinijatureWall = false
    @State private var showGrid = true
    @State private var handPanMode = false

    var body: some View {
        ZStack {
            // Pozadina
            Color.white.ignoresSafeArea()

            // Puni zaslon – 3D mapa (SceneKit): teren, rešetka, kamera s nagibom, zoom, pan
            SceneKitMapView(showGrid: showGrid, handPanMode: $handPanMode)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .ignoresSafeArea()

            // Dno: jedan obli kvadrat od brušenog stakla s ikonama unutra
            VStack {
                Spacer()
                HStack(spacing: 20) {
                    Button { showMinijatureWall = true } label: { BarIcon(assetName: "castle", systemName: "building.columns.fill") }
                    .buttonStyle(.plain)
                    Button { } label: { BarIcon(assetName: "sword", systemName: "crossed.swords") }
                    .buttonStyle(.plain)
                    Button { } label: { BarIcon(assetName: "farm", systemName: "leaf.fill") }
                    .buttonStyle(.plain)
                    Button { } label: { BarIcon(assetName: "food", systemName: "fork.knife") }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 14)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
                .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(.white.opacity(0.25), lineWidth: 1))
                .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 4)
                .padding(.bottom, 28)
            }

            // HUD – jedna traka gore: Kamera | Postavljanje | Resursi | Izlaz
            VStack(spacing: 0) {
                gameHUD
                Spacer()
            }
        }
        .overlay {
            if showMinijatureWall {
                minijatureWallOverlay
            }
        }
        .overlay {
            if !gameState.isLevelReady {
                levelLoadingOverlay
            }
        }
        .onAppear { printIconDiagnostics() }
    }

    /// Prekriva ekran dok se level (mapa, teren) učitava; nestaje kad GameScene pozove onLevelReady.
    private var levelLoadingOverlay: some View {
        ZStack {
            Color.black.opacity(0.85)
                .ignoresSafeArea()
            VStack(spacing: 16) {
                ProgressView()
                    .scaleEffect(1.4)
                    .tint(.white)
                Text("Učitavanje levela…")
                    .font(.title2.weight(.medium))
                    .foregroundStyle(.white)
            }
            .padding(.top, 80)
        }
        .allowsHitTesting(true)
    }

    // MARK: - HUD (UX: Kamera → Postavljanje → Resursi → Izlaz)

    private var gameHUD: some View {
        VStack(spacing: 0) {
            // Kompaktna zaobljena traka – ne od ruba do ruba
            HStack {
                Spacer(minLength: 0)
                HStack(spacing: 16) {
                    // Zum
                    HStack(spacing: 6) {
                        Image(systemName: "magnifyingglass")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.8))
                        Text("Zum")
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.85))
                        Slider(
                            value: Binding(
                                get: { gameState.mapCameraSettings.currentZoom },
                                set: { new in
                                    var s = gameState.mapCameraSettings
                                    s.currentZoom = min(s.zoomMax, max(s.zoomMin, new))
                                    gameState.mapCameraSettings = s
                                }
                            ),
                            in: gameState.mapCameraSettings.zoomMin ... gameState.mapCameraSettings.zoomMax
                        )
                        .frame(maxWidth: 100)
                        Text(String(format: "%.1f×", gameState.mapCameraSettings.currentZoom))
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.9))
                            .frame(width: 24, alignment: .trailing)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(.black.opacity(0.35), in: RoundedRectangle(cornerRadius: 6))
                    .frame(maxWidth: 160)

                    hudDivider

                    // Ruka – klik i povlačenje pomiče kameru
                    Button {
                        handPanMode.toggle()
                    } label: {
                        Image(systemName: handPanMode ? "hand.draw.fill" : "hand.draw")
                            .font(.caption)
                            .foregroundStyle(handPanMode ? .yellow : .white.opacity(0.9))
                    }
                    .buttonStyle(.bordered)
                    .tint(handPanMode ? .yellow.opacity(0.3) : .white.opacity(0.15))

                    hudDivider

                    // Kamera – 3D kocka sa stranama svijeta (povuci za rotaciju i nagib)
                    HStack(spacing: 8) {
                        CompassCubeView(
                            mapRotation: Binding(
                                get: { gameState.mapCameraSettings.mapRotation },
                                set: { new in
                                    var s = gameState.mapCameraSettings
                                    s.mapRotation = new
                                    gameState.mapCameraSettings = s
                                }
                            ),
                            tiltAngle: Binding(
                                get: { gameState.mapCameraSettings.tiltAngle },
                                set: { new in
                                    var s = gameState.mapCameraSettings
                                    s.tiltAngle = min(MapCameraSettings.tiltMax, max(MapCameraSettings.tiltMin, new))
                                    gameState.mapCameraSettings = s
                                }
                            ),
                            panOffset: Binding(
                                get: { gameState.mapCameraSettings.panOffset },
                                set: { new in
                                    var s = gameState.mapCameraSettings
                                    s.panOffset = new
                                    gameState.mapCameraSettings = s
                                }
                            )
                        )
                        Text("\(Int(round(gameState.mapCameraSettings.tiltAngle * 180 / .pi)))°")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.8))
                            .frame(width: 22, alignment: .leading)
                    }

                    hudDivider

                    // Ćelije
                    HStack(spacing: 6) {
                        Toggle(isOn: $showGrid) {
                            Text("Ćelije")
                                .font(.caption2)
                                .foregroundStyle(.white.opacity(0.85))
                        }
                        .toggleStyle(.switch)
                        .scaleEffect(0.8)
                        .labelsHidden()
                        Text("Ćelije")
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.75))
                    }

                    hudDivider

                    if gameState.gold > 0 || gameState.food > 0 {
                        HStack(spacing: 8) {
                            Label("\(gameState.gold)", systemImage: "dollarsign.circle.fill")
                            Label("\(gameState.food)", systemImage: "leaf.fill")
                        }
                        .font(.caption)
                        .foregroundStyle(.white)
                        hudDivider
                    }

                    Button {
                        gameState.showMainMenu()
                    } label: {
                        Label("Izlaz", systemImage: "rectangle.portrait.and.arrow.right")
                            .font(.caption)
                    }
                    .buttonStyle(.bordered)
                    .tint(.white.opacity(0.15))
                    .foregroundStyle(.white)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
                .shadow(color: .black.opacity(0.25), radius: 8, x: 0, y: 2)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 24)
            .padding(.top, 12)

            Text("↑↓ nagib  ·  WASD pomicanje  ·  +/− zoom")
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.5))
                .padding(.top, 6)
                .padding(.bottom, 4)
        }
    }

    private var hudDivider: some View {
        Rectangle()
            .fill(.white.opacity(0.2))
            .frame(width: 1, height: 20)
    }

    /// Minijaturni prikaz zida – otvara se klikom na ikonu dvora u sredini.
    private var minijatureWallOverlay: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture { showMinijatureWall = false }

            VStack(spacing: 0) {
                HStack {
                    Text("Zid (minijatura)")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.white.opacity(0.9))
                    Spacer()
                    Button {
                        showMinijatureWall = false
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.white.opacity(0.8))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 12)
                .padding(.top, 10)
                .padding(.bottom, 6)

                WallPreviewView()
                    .frame(width: 220, height: 220)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .padding(.horizontal, 12)
                    .padding(.bottom, 12)
            }
            .frame(width: 244)
            .background(.ultraThickMaterial, in: RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(.white.opacity(0.25), lineWidth: 1))
            .shadow(color: .black.opacity(0.5), radius: 20, x: 0, y: 8)
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(GameState())
        .frame(width: 1280, height: 800)
}
