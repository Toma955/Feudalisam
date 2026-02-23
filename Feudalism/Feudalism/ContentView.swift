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

private func printIconDiagnostics() {
    // Bez ispisa u produkciji
}

/// Učita ikonu resursa. Slike su već s transparentnom pozadinom – prikazujemo ih izravno.
private func loadResourceIcon(named name: String) -> NSImage? {
    loadBarIcon(named: name)
}

/// Max prikazivani broj za resurse (novac do 999999; fiksna širina 6 znamenki – traka se ne mijenja).
private let resourceMaxDisplay = 999_999

/// Širina za broj (6 znamenki: 999999).
private let resourceDigitWidth: CGFloat = 56

/// Jedan resurs u HUD-u: ikona + broj. Broj uvijek u fiksnoj širini (do 6 znamenki) da se traka ne mijenja.
private struct ResourceRow: View {
    let iconName: String
    let value: Int
    var iconSize: CGFloat = 44
    var systemFallback: String = "cube.fill"
    private var image: NSImage? { loadResourceIcon(named: iconName) }
    private var displayValue: Int { min(resourceMaxDisplay, max(0, value)) }
    var body: some View {
        HStack(spacing: 4) {
            if let img = image {
                Image(nsImage: img)
                    .resizable()
                    .scaledToFit()
                    .frame(width: iconSize, height: iconSize)
            } else {
                Image(systemName: systemFallback)
                    .font(.system(size: iconSize * 0.6))
                    .foregroundStyle(.white.opacity(0.95))
            }
            Text("\(displayValue)")
                .font(.system(size: 16, weight: .medium, design: .monospaced))
                .foregroundStyle(.white.opacity(0.95))
                .frame(width: resourceDigitWidth, alignment: .trailing)
        }
        .frame(width: ResourceRow.fixedWidth(iconSize: iconSize))
    }
    static func fixedWidth(iconSize: CGFloat) -> CGFloat { iconSize + 4 + resourceDigitWidth }
}

/// Što prikazuje traka resursa: Resources = novci (zlato), drvo, kamen, željezo; Food = kruh, hmelj, žito.
private enum ResourceStripMode {
    case resources  // zlato, drvo, kamen, željezo
    case food       // kruh, hmelj, žito
}

/// Boja za postotak: 100 zeleno, 80–100 blago zeleno, 50–80 žuto, ispod 50 crveno; 0/0 tamnocrveno.
private func colorForPercent(_ percent: Int, isEmpty: Bool) -> Color {
    if isEmpty { return Color(red: 0.55, green: 0.15, blue: 0.12) }
    switch percent {
    case 100: return Color(red: 0.2, green: 0.75, blue: 0.3)
    case 80..<100: return Color(red: 0.45, green: 0.75, blue: 0.4)
    case 50..<80: return Color(red: 0.9, green: 0.75, blue: 0.2)
    default: return Color(red: 0.85, green: 0.25, blue: 0.2)
    }
}

/// HUD element: current/max (max 999/999) na sredini, vertikalna linija, postotak s bojom (0/0 = tamnocrveno).
private struct HUDScoreView: View {
    let current: Int
    let max: Int

    private static let viewWidth: CGFloat = 160
    private static let height: CGFloat = 24
    private static let cornerRadius: CGFloat = 6

    private var currentClamped: Int { min(999, Swift.max(0, current)) }
    private var maxClamped: Int { min(999, Swift.max(0, max)) }
    private var percent: Int {
        guard maxClamped > 0 else { return 0 }
        return min(100, (currentClamped * 100) / maxClamped)
    }
    private var isEmpty: Bool { maxClamped == 0 }

    var body: some View {
        HStack(spacing: 0) {
            Text("\(currentClamped)/\(maxClamped)")
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)

            Rectangle()
                .fill(.white.opacity(0.4))
                .frame(width: 1, height: 14)

            Text("\(percent)%")
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .foregroundStyle(.white)
                .frame(minWidth: 36)
                .padding(.leading, 6)
        }
        .padding(.trailing, 8)
        .frame(width: Self.viewWidth, height: Self.height)
        .background(.black.opacity(0.35), in: RoundedRectangle(cornerRadius: Self.cornerRadius))
    }
}

/// Donji bar: kategorija koja je otvorena (nil = sve ikone, inače island s pod-ikonama).
private enum BottomBarCategory: String, CaseIterable {
    case castle
    case sword
    case mine
    case cave
    case farm
    case food
    case tools
}

/// Širina područja sadržaja (za ograničavanje max širine donjeg bara).
private struct ContentAreaWidthKey: PreferenceKey {
    static var defaultValue: CGFloat = 830
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = nextValue() }
}

/// Minimalna širina donjeg bara = širina trenutnog rasporeda (7 ikona + padding). Dimenzije se ne smiju sužavati.
private let bottomBarMinWidth: CGFloat = 620

struct ContentView: View {
    @EnvironmentObject private var gameState: GameState
    @State private var showMinijatureWall = false
    @State private var expandedBottomCategory: BottomBarCategory? = nil
    @State private var contentAreaWidth: CGFloat = 830
    @State private var showGrid = true
    @State private var handPanMode = false
    @State private var showPivotIndicator = false
    @State private var showSettingsPopover = false
    /// resources = drvo, kamen, željezo; food = kruh, hmelj, žito
    @State private var resourceStripMode: ResourceStripMode = .resources
    /// HUD ispis 0/0 i postotak – mijenjaju se iz logike (npr. populacija / kapacitet).
    @State private var hudScoreCurrent: Int = 0
    @State private var hudScoreMax: Int = 0

    var body: some View {
        MapScreenLayout(
            topBar: { gameHUD },
            content: {
                ZStack {
                    SceneKitMapView(showGrid: showGrid, handPanMode: $handPanMode, showPivotIndicator: showPivotIndicator)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .ignoresSafeArea()

                    VStack {
                        Spacer()
                        Group {
                            if expandedBottomCategory != nil {
                                HStack(spacing: 0) {
                                    Spacer(minLength: 0)
                                    bottomBarContent
                                        .padding(.horizontal, 20)
                                        .padding(.vertical, 12)
                                        .frame(maxHeight: 96)
                                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
                                        .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(.white.opacity(0.25), lineWidth: 1))
                                        .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 4)
                                        .frame(
                                            minWidth: bottomBarMinWidth,
                                            maxWidth: min(830, contentAreaWidth * 0.92)
                                        )
                                    Spacer(minLength: 0)
                                }
                            } else {
                                bottomBarContent
                                    .padding(.horizontal, 28)
                                    .padding(.vertical, 14)
                                    .frame(minWidth: bottomBarMinWidth)
                                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
                                    .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(.white.opacity(0.25), lineWidth: 1))
                                    .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 4)
                            }
                        }
                        .padding(.bottom, 20)
                        .animation(.easeInOut(duration: 0.28), value: expandedBottomCategory)
                    }
                }
                .background(
                    GeometryReader { geo in
                        Color.clear.preference(key: ContentAreaWidthKey.self, value: geo.size.width)
                    }
                )
                .onPreferenceChange(ContentAreaWidthKey.self) { contentAreaWidth = $0 }
            },
            loadingMessage: gameState.isLevelReady ? nil : "Učitavanje levela…",
            customOverlay: {
                Group {
                    if showMinijatureWall {
                        minijatureWallOverlay
                    }
                }
            }
        )
        .onChange(of: gameState.isLevelReady) { ready in
            if ready {
                AudioManager.shared.playMapMusicIfAvailable(volume: gameState.audioMusicVolume)
            } else {
                AudioManager.shared.stopMapMusic()
            }
        }
        .onChange(of: gameState.audioMusicVolume) { vol in
            AudioManager.shared.updateMapMusicVolume(volume: vol)
        }
        .onAppear { printIconDiagnostics() }
    }

    /// Donji bar: ili 5 ikona (castle, sword, mine, farm, food) ili prošireni island s pod-ikonama.
    @ViewBuilder
    private var bottomBarContent: some View {
        if let category = expandedBottomCategory {
            expandedBottomBar(category: category)
        } else {
            HStack(spacing: 24) {
                ForEach(BottomBarCategory.allCases, id: \.self) { cat in
                    Button {
                        withAnimation(.easeInOut(duration: 0.28)) { expandedBottomCategory = cat }
                    } label: { barIcon(for: cat) }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func barIcon(for category: BottomBarCategory) -> some View {
        let icon: BarIconView = {
            switch category {
            case .castle: return BarIconView(assetName: "castle", systemName: "building.columns.fill")
            case .sword: return BarIconView(assetName: "sword", systemName: "crossed.swords")
            case .mine: return BarIconView(assetName: "mine", systemName: "hammer.fill")
            case .cave: return BarIconView(assetName: "cave", systemName: "mountain.2.fill")
            case .farm: return BarIconView(assetName: "farm", systemName: "leaf.fill")
            case .food: return BarIconView(assetName: "food", systemName: "fork.knife")
            case .tools: return BarIconView(assetName: "tools", systemName: "wrench.and.screwdriver.fill")
            }
        }()
        return VStack(spacing: 2) {
            icon
            if gameState.showBottomBarLabels {
                Text(titleForCategory(category))
                    .font(.system(size: 10))
                    .foregroundStyle(.white.opacity(0.9))
            }
        }
    }

    /// Prošireni island: povećan, centriran, natpisi ispod ikona, lagano odvojeni.
    private func expandedBottomBar(category: BottomBarCategory) -> some View {
        VStack(spacing: 10) {
            switch category {
            case .castle:
                CastleButtonExpandedView(
                    onSelectWall: { gameState.selectedPlacementObjectId = Wall.objectId },
                    onSelectMarket: { gameState.selectedPlacementObjectId = Market.objectId }
                )
                .padding(.horizontal, 24)
                .padding(.vertical, 16)
                .contentShape(Rectangle())
            case .farm:
                FarmButtonExpandedView(
                    onSelectAppleFarm: { /* objekt – uskoro */ },
                    onSelectPigFarm: { /* objekt – uskoro */ },
                    onSelectHayFarm: { /* objekt – uskoro */ },
                    onSelectCowFarm: { /* objekt – uskoro */ },
                    onSelectSheepFarm: { /* objekt – uskoro */ },
                    onSelectWheatFarm: { /* objekt – uskoro */ },
                    onSelectChickenFarm: { /* objekt – uskoro */ },
                    onSelectVegetablesFarm: { /* objekt – uskoro */ },
                    onSelectGrapesFarm: { /* objekt – uskoro */ },
                    onSelectSpicesFarm: { /* objekt – uskoro */ },
                    onSelectFlowerFarm: { /* objekt – uskoro */ }
                )
            case .tools:
                ToolsButtonExpandedView(
                    selectedToolId: $gameState.selectedToolsPanelItem,
                    onSelectSword: { gameState.selectedToolsPanelItem = "sword" },
                    onSelectMace: { gameState.selectedToolsPanelItem = "mace" },
                    onSelectReport: { gameState.selectedToolsPanelItem = "report" },
                    onSelectShovel: { gameState.selectedToolsPanelItem = "shovel" },
                    onSelectPen: { gameState.selectedToolsPanelItem = "pen" }
                )
            case .sword, .mine, .cave, .food:
                HStack(spacing: 12) {
                    Text(LocalizedStrings.string(for: "soon", language: gameState.appLanguage))
                        .font(.system(size: 10))
                        .foregroundStyle(.white.opacity(0.6))
                }
            }
            Button {
                withAnimation(.easeInOut(duration: 0.28)) { expandedBottomCategory = nil }
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white.opacity(0.9))
                    .frame(minWidth: 44, minHeight: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .fixedSize(horizontal: true, vertical: false)
    }

    private func titleForCategory(_ category: BottomBarCategory) -> String {
        let key: String
        switch category {
        case .castle: key = "category_castle"
        case .sword: key = "category_sword"
        case .mine: key = "category_mine"
        case .cave: key = "category_cave"
        case .farm: key = "category_farm"
        case .food: key = "category_food"
        case .tools: key = "category_tools"
        }
        return LocalizedStrings.string(for: key, language: gameState.appLanguage)
    }

    // MARK: - HUD (UX: Kamera → Postavljanje → Resursi → Izlaz)

    private var gameHUD: some View {
        MapScreenHUDBar {
            // Mapa – gumb lijevo od kompasa (map.png)
            Button {
                // Akcija – npr. pregled mape / fullscreen
            } label: {
                hudIconImage("map", fallback: "map", size: 26)
            }
            .buttonStyle(.plain)
            .help("Mapa")

            // Kompas (rotacija 90°)
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

            // Zoom – 3 faze (šuma 2×, 3 stabla 8×, 1 stablo 14×)
            ZoomPhaseView(mapCameraSettings: Binding(
                get: { gameState.mapCameraSettings },
                set: { gameState.mapCameraSettings = $0 }
            ))

            HUDBarDivider()

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

                    HUDBarDivider()

                    // 0/0 i postotak (tamnocrveno kad 0/0); max 999/999; linija između; boja po postotku
                    HUDScoreView(current: hudScoreCurrent, max: hudScoreMax)

                    HUDBarDivider()

                    // Resursi: novci (zlato), drvo, kamen, željezo; Food = kruh, hmelj, žito. Fiksna širina da se sivi element ne mijenja.
                    HStack(spacing: 12) {
                        if resourceStripMode == .resources {
                            ResourceRow(iconName: "gold", value: gameState.gold, iconSize: 52, systemFallback: "dollarsign.circle.fill")
                            ResourceRow(iconName: "wood", value: gameState.wood)
                            ResourceRow(iconName: "stone", value: gameState.stone, iconSize: 52)
                            ResourceRow(iconName: "iron", value: gameState.iron, iconSize: 52)
                        } else {
                            ResourceRow(iconName: "bread", value: gameState.food)
                            ResourceRow(iconName: "hop", value: gameState.hop)
                                .help(LocalizedStrings.string(for: "resource_hop", language: gameState.appLanguage))
                            ResourceRow(iconName: "hay", value: gameState.hay)
                        }
                    }
                    .frame(width: 520)
                    .id(resourceStripMode)
                    .transition(.asymmetric(
                        insertion: .opacity.animation(.easeOut(duration: 0.22)).combined(with: .scale(scale: 0.92)),
                        removal: .opacity.animation(.easeIn(duration: 0.18)).combined(with: .scale(scale: 0.96))
                    ))
                    .animation(.easeInOut(duration: 0.25), value: resourceStripMode)
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
