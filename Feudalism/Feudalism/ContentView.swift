//
//  ContentView.swift
//  Feudalism
//
//  Glavni ekran – puni zaslon (karta preko cijelog ekrana), na dnu gumb dvora, HUD gore.
//

import SwiftUI
import AppKit
import CoreGraphics

/// Vraća novu sliku s bijelom/svijetlom pozadinom pretvorenom u potpuno transparentnu. Koristi NSBitmapImageRep.
private func imageWithTransparentWhiteBackground(_ image: NSImage, whiteThreshold: UInt8 = 235) -> NSImage? {
    let width = Int(image.size.width)
    let height = Int(image.size.height)
    guard width > 0, height > 0 else { return nil }
    let bytesPerRow = width * 4
    guard let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: width,
        pixelsHigh: height,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: bytesPerRow,
        bitsPerPixel: 32
    ) else { return nil }
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    image.draw(at: .zero, from: NSRect(origin: .zero, size: image.size), operation: .copy, fraction: 1)
    NSGraphicsContext.current = nil
    NSGraphicsContext.restoreGraphicsState()
    guard let data = rep.bitmapData else { return nil }
    let threshold = whiteThreshold
    for y in 0..<height {
        for x in 0..<width {
            let offset = y * bytesPerRow + x * 4
            let r = data[offset]
            let g = data[offset + 1]
            let b = data[offset + 2]
            let a = data[offset + 3]
            let isWhite = r >= threshold && g >= threshold && b >= threshold
            let brightness = (Int(r) + Int(g) + Int(b)) / 3
            let isVeryLight = brightness >= Int(threshold)
            if (isWhite || isVeryLight) && a > 0 {
                data[offset] = 0
                data[offset + 1] = 0
                data[offset + 2] = 0
                data[offset + 3] = 0
            }
        }
    }
    let outImage = NSImage(size: image.size)
    outImage.addRepresentation(rep)
    return outImage
}

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

/// Učita ikonu resursa. Slike su već s transparentnom pozadinom – prikazujemo ih izravno.
private func loadResourceIcon(named name: String) -> NSImage? {
    loadBarIcon(named: name)
}

/// Jedan resurs u HUD-u: ikona iz Icons + broj. Ikone u izvornim bojama. iconSize: veličina ikone (default 44, manje = niža traka).
private struct ResourceRow: View {
    let iconName: String
    let value: Int
    var iconSize: CGFloat = 44
    private var image: NSImage? { loadResourceIcon(named: iconName) }
    var body: some View {
        HStack(spacing: 4) {
            if let img = image {
                Image(nsImage: img)
                    .resizable()
                    .scaledToFit()
                    .frame(width: iconSize, height: iconSize)
            } else {
                Image(systemName: "cube.fill")
                    .font(.system(size: iconSize * 0.6))
                    .foregroundStyle(.white.opacity(0.95))
            }
            Text("\(value)")
                .font(.system(size: 16, weight: .medium, design: .monospaced))
                .foregroundStyle(.white.opacity(0.95))
        }
    }
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
                    .font(.system(size: 34))
            }
        }
        .frame(width: 58, height: 58)
        .foregroundStyle(.white.opacity(0.95))
    }
}

/// Što prikazuje traka resursa: Resources = drvo, kamen, željezo; Food = kruh, hmelj, žito.
private enum ResourceStripMode {
    case resources  // drvo, kamen, željezo
    case food       // kruh, hmelj, žito
}

struct ContentView: View {
    @EnvironmentObject private var gameState: GameState
    @State private var showMinijatureWall = false
    @State private var showGrid = true
    @State private var handPanMode = false
    @State private var showPivotIndicator = false
    @State private var showSettingsPopover = false
    /// resources = drvo, kamen, željezo; food = kruh, hmelj, žito
    @State private var resourceStripMode: ResourceStripMode = .resources

    var body: some View {
        ZStack {
            // Pozadina
            Color.white.ignoresSafeArea()

            // Puni zaslon – 3D mapa (SceneKit): teren, rešetka, kamera s nagibom, zoom, pan
            SceneKitMapView(showGrid: showGrid, handPanMode: $handPanMode, showPivotIndicator: showPivotIndicator)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .ignoresSafeArea()

            // Dno: sivi zaobljeni okvir s ikonama (castle, sword, mine, farm, food)
            VStack {
                Spacer()
                HStack(spacing: 24) {
                    Button { showMinijatureWall = true } label: { BarIcon(assetName: "castle", systemName: "building.columns.fill") }
                    .buttonStyle(.plain)
                    Button { } label: { BarIcon(assetName: "sword", systemName: "crossed.swords") }
                    .buttonStyle(.plain)
                    Button { } label: { BarIcon(assetName: "mine", systemName: "hammer.fill") }
                    .buttonStyle(.plain)
                    Button { } label: { BarIcon(assetName: "farm", systemName: "leaf.fill") }
                    .buttonStyle(.plain)
                    Button { } label: { BarIcon(assetName: "food", systemName: "fork.knife") }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 28)
                .padding(.vertical, 18)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
                .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(.white.opacity(0.25), lineWidth: 1))
                .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 4)
                .padding(.bottom, 28)
            }

            // Zoom – donji lijevi kut, da vidiš koliko je zumirano
            VStack {
                Spacer()
                HStack {
                    Text("Zoom \(String(format: "%.1f×", gameState.mapCameraSettings.currentZoom))")
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(.black.opacity(0.45), in: RoundedRectangle(cornerRadius: 6))
                    Spacer(minLength: 0)
                }
                .padding(.leading, 16)
                .padding(.bottom, 100)
            }
            .allowsHitTesting(false)

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
                    // Zoom – 4 faze (ostaje na traci)
                    ZoomPhaseView(mapCameraSettings: Binding(
                        get: { gameState.mapCameraSettings },
                        set: { gameState.mapCameraSettings = $0 }
                    ))

                    hudDivider

                    // Gear (manje), Foodbottun, Weapons, Resources (veće)
                    HStack(spacing: 10) {
                        Button {
                            showSettingsPopover.toggle()
                        } label: {
                            hudIconImage("gear", fallback: "gearshape.fill", size: 26)
                        }
                        .buttonStyle(.plain)
                        .popover(isPresented: $showSettingsPopover, arrowEdge: .bottom) {
                            settingsPopoverContent
                        }
                        .help("Postavke kamere i prikaza")
                        Button { resourceStripMode = .food } label: { hudIconImage("foodbottun", fallback: "fork.knife", size: 48).scaleEffect(1.5) }
                        .buttonStyle(.plain)
                        Button { } label: { hudIconImage("weapons", fallback: "crossed.swords", size: 48).scaleEffect(1.5) }
                        .buttonStyle(.plain)
                        Button { resourceStripMode = .resources } label: { hudIconImage("resources", fallback: "square.stack.3d.up.fill", size: 48).scaleEffect(1.5) }
                        .buttonStyle(.plain)
                    }

                    hudDivider

                    // Kamera – kompas (rotacija 90°)
                    CompassCubeView(
                        mapRotation: Binding(
                            get: { gameState.mapCameraSettings.mapRotation },
                            set: { new in
                                var s = gameState.mapCameraSettings
                                s.mapRotation = new
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

                    hudDivider

                    // Resursi: Resources botun = drvo, kamen, željezo; Food botun = kruh, hmelj, žito
                    HStack(spacing: 12) {
                        if resourceStripMode == .resources {
                            ResourceRow(iconName: "wood", value: gameState.wood)
                            ResourceRow(iconName: "stone", value: gameState.stone, iconSize: 52)
                            ResourceRow(iconName: "iron", value: gameState.iron, iconSize: 52)
                        } else {
                            ResourceRow(iconName: "bread", value: gameState.food)
                            ResourceRow(iconName: "hop", value: gameState.hop)
                            ResourceRow(iconName: "hay", value: gameState.hay)
                        }
                    }
                    .id(resourceStripMode)
                    .transition(.asymmetric(
                        insertion: .opacity.animation(.easeOut(duration: 0.22)).combined(with: .scale(scale: 0.92)),
                        removal: .opacity.animation(.easeIn(duration: 0.18)).combined(with: .scale(scale: 0.96))
                    ))
                    .animation(.easeInOut(duration: 0.25), value: resourceStripMode)
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 0)
                .frame(width: 1100, height: 52)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
                .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 1)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)

            Text("WASD pomicanje  ·  +/− zoom")
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.5))
                .padding(.top, 6)
                .padding(.bottom, 4)
        }
    }

    /// Mini prozor iz gear gumba: Ruka, Pivot, Ćelije (sukladno temi). Zoom ostaje na traci.
    private var settingsPopoverContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Kamera i prikaz")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white.opacity(0.95))
            Divider().background(.white.opacity(0.3))
            HStack(spacing: 8) {
                Button {
                    handPanMode.toggle()
                } label: {
                    Label(handPanMode ? "Ruka uklj." : "Ruka", systemImage: handPanMode ? "hand.draw.fill" : "hand.draw")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                .tint(handPanMode ? .yellow.opacity(0.4) : .white.opacity(0.2))
                .foregroundStyle(handPanMode ? .yellow : .white.opacity(0.9))
                Button {
                    showPivotIndicator.toggle()
                } label: {
                    Label(showPivotIndicator ? "Pivot uklj." : "Pivot", systemImage: "scope")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                .tint(showPivotIndicator ? .yellow.opacity(0.4) : .white.opacity(0.2))
                .foregroundStyle(showPivotIndicator ? .yellow : .white.opacity(0.9))
            }
            HStack(spacing: 8) {
                Text("Ćelije")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.9))
                Toggle("", isOn: $showGrid)
                    .toggleStyle(.switch)
                    .labelsHidden()
            }
            Divider().background(.white.opacity(0.3))
            Button {
                showSettingsPopover = false
                gameState.showMainMenu()
            } label: {
                Label("Izlaz", systemImage: "rectangle.portrait.and.arrow.right")
                    .font(.caption)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .tint(.white.opacity(0.15))
            .foregroundStyle(.white)
        }
        .frame(width: 200)
        .padding(14)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    /// Ikona za HUD: iz Icons/*.png ili SF Symbol. size: veličina u pt (zadnje dvije veće).
    private func hudIconImage(_ name: String, fallback systemName: String, size: CGFloat = 22) -> some View {
        Group {
            if let img = loadBarIcon(named: name) {
                Image(nsImage: img)
                    .resizable()
                    .scaledToFit()
            } else {
                Image(systemName: systemName)
                    .font(.system(size: size * 0.64))
            }
        }
        .frame(width: size, height: size)
        .foregroundStyle(.white.opacity(0.9))
    }

    private var hudDivider: some View {
        Rectangle()
            .fill(.white.opacity(0.2))
            .frame(width: 1, height: 6)
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
