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
    private static let height: CGFloat = 28
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
    case house
    case cave
    case farm
    case food
    case tools
}

/// Godišnja doba za HUD – ikone spring.png, summer.png, attun.png, winter.png. Redoslijed: zima → proljeće → ljeto → jesen → zima (nova godina).
private enum SeasonIcon: String, CaseIterable {
    case spring = "spring"
    case summer = "summer"
    case attun = "attun"
    case winter = "winter"

    /// Redoslijed u godini: zima, proljeće, ljeto, jesen.
    private static let cycle: [SeasonIcon] = [.winter, .spring, .summer, .attun]

    /// Sljedeće doba; kad attun → winter, jedna godina je prošla.
    static func next(after s: SeasonIcon) -> (season: SeasonIcon, yearCompleted: Bool) {
        guard let idx = cycle.firstIndex(of: s) else { return (.winter, false) }
        let nextIdx = (idx + 1) % cycle.count
        let nextSeason = cycle[nextIdx]
        let yearCompleted = (nextIdx == 0)
        return (nextSeason, yearCompleted)
    }

    /// Doba i godina iz proteklih sekundi od početka igre (60 s = 1 doba, 240 s = 1 godina).
    static func fromElapsedSeconds(_ totalSeconds: Int) -> (season: SeasonIcon, yearOffset: Int) {
        let seasonIndex = (totalSeconds / 60) % cycle.count
        let yearOffset = totalSeconds / 240
        return (cycle[seasonIndex], yearOffset)
    }
}

/// Širina područja sadržaja (za ograničavanje max širine donjeg bara).
private struct ContentAreaWidthKey: PreferenceKey {
    static var defaultValue: CGFloat = 830
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = nextValue() }
}

/// Minimalna širina donjeg bara – uvijek ostaje ta širina; ne smije biti manja ni kad je pretinac prazan.
private let bottomBarMinWidth: CGFloat = 620
/// Kad je pretinac otvoren, bar se minimalno poveća da sadržaj lijepo stane (ne od ruba do ruba).
private let bottomBarExpandedMinWidth: CGFloat = 720

struct ContentView: View {
    @EnvironmentObject private var gameState: GameState
    @State private var showMinijatureWall = false
    @State private var expandedBottomCategory: BottomBarCategory? = nil
    /// Smjer tranzicije proširenog sadržaja: true = novi dolazi s desne, stari ide ulijevo; false = obrnuto.
    @State private var bottomBarTransitionFromRight: Bool = true
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
    /// Trenutno godišnje doba za HUD; počinje zima.
    @State private var displayedSeason: SeasonIcon = .winter
    /// Godina u HUD-u; +1 nakon svakog ciklusa 4 doba.
    @State private var displayedYear: Int = 1100
    /// Ikona koja upravo odlazi (animacija prema dolje); nil kad nema prijelaza.
    @State private var outgoingSeason: SeasonIcon?
    /// Offset za odlazeću ikonu (0 → 36); za dolaznu -36 → 0.
    @State private var seasonAnimOffset: CGFloat = 0
    /// Početak igre – sat ovisi samo o ovom; neprestano broji od ovog trenutka.
    @State private var gameStartTime: Date?

    var body: some View {
        MapScreenLayout(
            topBar: { gameHUD },
            content: {
                ZStack {
                    SceneKitMapView(showGrid: showGrid, handPanMode: $handPanMode, showPivotIndicator: showPivotIndicator)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .ignoresSafeArea()

                    VStack(spacing: 0) {
                        Spacer()
                        // Jedan objekt koji naraste prema gore; ikone dole pri dnu, sadržaj gore
                        HStack(spacing: 0) {
                            Spacer(minLength: 0)
                            VStack(spacing: 0) {
                                if let category = expandedBottomCategory {
                                    expandedBottomBarContent(category: category)
                                        .padding(.horizontal, 20)
                                        .padding(.top, 16)
                                        .padding(.bottom, 10)
                                        .transition(.asymmetric(
                                            insertion: .move(edge: bottomBarTransitionFromRight ? .trailing : .leading),
                                            removal: .move(edge: bottomBarTransitionFromRight ? .leading : .trailing)
                                        ))
                                }
                                Spacer(minLength: 0)
                                bottomBarStrip
                                    .padding(.horizontal, expandedBottomCategory != nil ? 20 : 28)
                                    .padding(.vertical, expandedBottomCategory != nil ? 10 : 14)
                                    .padding(.bottom, expandedBottomCategory != nil ? 10 : 0)
                            }
                            .clipped()
                            .animation(.easeInOut(duration: 0.28), value: expandedBottomCategory)
                            .frame(
                                minWidth: expandedBottomCategory != nil ? bottomBarExpandedMinWidth : bottomBarMinWidth,
                                minHeight: expandedBottomCategory != nil ? 180 : 80,
                                maxHeight: expandedBottomCategory != nil ? 180 : 80
                            )
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
                            .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(.white.opacity(0.25), lineWidth: 1))
                            .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 4)
                            .frame(
                                minWidth: expandedBottomCategory != nil ? bottomBarExpandedMinWidth : bottomBarMinWidth,
                                maxWidth: min(830, contentAreaWidth * 0.92)
                            )
                            Spacer(minLength: 0)
                        }
                        .padding(.bottom, expandedBottomCategory != nil ? 88 : 20)
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
            loadingMessage: gameState.isLevelReady ? nil : (gameState.levelLoadingMessage ?? "Učitavanje levela…"),
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
                gameStartTime = Date()
                AudioManager.shared.playMapMusicIfAvailable(volume: gameState.audioMusicVolume)
            } else {
                gameStartTime = nil
                AudioManager.shared.stopMapMusic()
            }
        }
        .onChange(of: gameState.audioMusicVolume) { vol in
            AudioManager.shared.updateMapMusicVolume(volume: vol)
        }
        .onAppear { printIconDiagnostics() }
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { _ in
            guard let start = gameStartTime, gameState.isLevelReady, !gameState.isShowingMainMenu, !gameState.isMapEditorMode else { return }
            let totalSeconds = Int(Date().timeIntervalSince(start))
            let (newSeason, yearOffset) = SeasonIcon.fromElapsedSeconds(totalSeconds)
            let newYear = 1100 + yearOffset
            if newSeason != displayedSeason {
                applySeasonChange(to: newSeason, year: newYear)
            } else if newYear != displayedYear {
                displayedYear = newYear
            }
        }
    }

    /// Primijeni novo doba i godinu (iz sata) s animacijom.
    private func applySeasonChange(to newSeason: SeasonIcon, year newYear: Int) {
        let leaving = displayedSeason
        outgoingSeason = leaving
        displayedSeason = newSeason
        displayedYear = newYear
        seasonAnimOffset = 0
        withAnimation(.easeInOut(duration: 0.45)) {
            seasonAnimOffset = 36
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            outgoingSeason = nil
            seasonAnimOffset = 0
        }
    }

    /// Sam traka s ikonama – smanjene kad je pretinac otvoren. Sadržaj se prikazuje iznad (island prema gore).
    private var bottomBarStrip: some View {
        barIconsRow(
            compact: expandedBottomCategory != nil,
            expandedCategory: expandedBottomCategory
        )
    }

    /// Red ikona: compact = smanjene (kad je prošireno), inače normalne. Klik na istu ikonu kao trenutno otvorenu vraća početno.
    private func barIconsRow(compact: Bool, expandedCategory: BottomBarCategory?) -> some View {
        let iconSize: CGFloat = compact ? 32 : 48
        let foodIconSize: CGFloat = compact ? 36 : 56
        return HStack(spacing: compact ? 12 : 24) {
            ForEach(BottomBarCategory.allCases, id: \.self) { cat in
                Button {
                    withAnimation(.easeInOut(duration: 0.28)) {
                        if let expanded = expandedCategory, cat == expanded {
                            expandedBottomCategory = nil
                        } else {
                            if expandedCategory != nil, gameState.playBarTransitionSound {
                                AudioManager.shared.playSound(named: "transition", volume: gameState.audioSoundsVolume)
                            }
                            let order = BottomBarCategory.allCases
                            let oldIdx = expandedCategory.flatMap { order.firstIndex(of: $0) }
                            let newIdx = order.firstIndex(of: cat) ?? 0
                            bottomBarTransitionFromRight = (newIdx > (oldIdx ?? -1))
                            expandedBottomCategory = cat
                        }
                    }
                } label: {
                    let size = cat == .food ? foodIconSize : iconSize
                    barIcon(for: cat, size: size)
                        .offset(y: cat == .food ? -4 : 0)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func barIcon(for category: BottomBarCategory, size: CGFloat = 48) -> some View {
        let icon: BarIconView = {
            switch category {
            case .castle: return BarIconView(assetName: "castle", systemName: "building.columns.fill", size: size)
            case .sword: return BarIconView(assetName: "sword", systemName: "crossed.swords", size: size)
            case .mine: return BarIconView(assetName: "mine", systemName: "hammer.fill", size: size)
            case .house: return BarIconView(assetName: "house", systemName: "house.fill", size: size)
            case .cave: return BarIconView(assetName: "cave", systemName: "mountain.2.fill", size: size)
            case .farm: return BarIconView(assetName: "farm", systemName: "leaf.fill", size: size)
            case .food: return BarIconView(assetName: "food", systemName: "fork.knife", size: size)
            case .tools: return BarIconView(assetName: "tools", systemName: "wrench.and.screwdriver.fill", size: size)
            }
        }()
        return icon
    }

    /// Sadržaj proširenog pretinca – minimalno povećan da sve lijepo stane, ne od ruba do ruba.
    private func expandedBottomBarContent(category: BottomBarCategory) -> some View {
        Group {
            switch category {
            case .castle:
                CastleButtonExpandedView(
                    onSelectWall: { gameState.selectedPlacementObjectId = Wall.objectId },
                    onSelectMarket: { gameState.selectedPlacementObjectId = Market.objectId },
                    onSelectArmory: { /* dvor – uskoro */ },
                    onSelectSteps: { /* dvor – uskoro */ },
                    onSelectStairs: { /* dvor – uskoro */ },
                    onSelectTraining: { /* dvor – uskoro */ },
                    onSelectGates: { /* dvor – uskoro */ },
                    onSelectStable: { /* dvor – uskoro */ },
                    onSelectMiners: { /* dvor – uskoro */ },
                    onSelectEngineering: { /* dvor – uskoro */ },
                    onSelectTowers: { /* dvor – uskoro */ },
                    onSelectDrawbridge: { /* dvor – uskoro */ }
                )
            case .farm:
                FarmButtonExpandedView(
                    onSelectAppleFarm: { /* objekt – uskoro */ },
                    onSelectPigFarm: { /* objekt – uskoro */ },
                    onSelectHayFarm: { /* objekt – uskoro */ },
                    onSelectCowFarm: { /* objekt – uskoro */ },
                    onSelectSheepFarm: { /* objekt – uskoro */ },
                    onSelectWheatFarm: { /* objekt – uskoro */ },
                    onSelectCornFarm: { gameState.selectedPlacementObjectId = Corn.objectId },
                    onSelectChickenFarm: { gameState.selectedPlacementObjectId = Chicken.objectId },
                    onSelectVegetablesFarm: { /* objekt – uskoro */ },
                    onSelectGrapesFarm: { /* objekt – uskoro */ },
                    onSelectSpicesFarm: { /* objekt – uskoro */ },
                    onSelectFlowerFarm: { /* objekt – uskoro */ }
                )
            case .sword:
                SwordButtonExpandedView(
                    onSelectSwordHouse: { /* oružje – uskoro */ },
                    onSelectShield: { /* oružje – uskoro */ },
                    onSelectBow: { /* oružje – uskoro */ },
                    onSelectSpear: { /* oružje – uskoro */ },
                    onSelectLeather: { /* oružje – uskoro */ }
                )
            case .mine:
                MineButtonExpandedView(
                    onSelectLager: { /* industrija – uskoro */ },
                    onSelectStump: { /* industrija – uskoro */ },
                    onSelectIronMine: { gameState.selectedPlacementObjectId = Iron.objectId },
                    onSelectStoneMine: { gameState.selectedPlacementObjectId = Stone.objectId },
                    onSelectCarriage: { /* industrija – uskoro */ }
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
            case .house:
                HouseButtonExpandedView(
                    onSelectHouse: { /* kuća – uskoro */ },
                    onSelectPharmacy: { /* kuća – uskoro */ },
                    onSelectGreenHouse: { /* kuća – uskoro */ },
                    onSelectHotel: { gameState.selectedPlacementObjectId = Hotel.objectId },
                    onSelectWaterWell: { gameState.selectedPlacementObjectId = Well.objectId },
                    onSelectChurch: { /* kuća – uskoro */ },
                    onSelectDiplomacy: { /* kuća – uskoro */ }
                )
            case .food:
                FoodButtonExpandedView(
                    onSelectMill: { gameState.selectedPlacementObjectId = Windmill.objectId },
                    onSelectBrewery: { /* hrana – uskoro */ },
                    onSelectDistillery: { /* hrana – uskoro */ },
                    onSelectWineCellar: { /* hrana – uskoro */ },
                    onSelectTavern: { /* hrana – uskoro */ },
                    onSelectPantry: { gameState.selectedPlacementObjectId = Granary.objectId },
                    onSelectBakery: { gameState.selectedPlacementObjectId = Bakery.objectId },
                    onSelectCanteen: { /* hrana – uskoro */ }
                )
            case .cave:
                HStack(spacing: 12) {
                    Text(LocalizedStrings.string(for: "soon", language: gameState.appLanguage))
                        .font(.system(size: 10))
                        .foregroundStyle(.white.opacity(0.6))
                }
            }
        }
        .frame(minWidth: 280)
    }

    // MARK: - HUD (UX: Kamera → Postavljanje → Resursi → Izlaz)

    /// Godišnje doba: lijevo godina, desno simbol. Eksplicitna animacija: stara ide dolje, nova dolazi odozgo.
    private var seasonHUDView: some View {
        HStack(spacing: 8) {
            Text(verbatim: String(displayedYear))
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.95))

            Spacer(minLength: 4)

            ZStack {
                // Odlazeća ikona – lagano ide prema dolje i nestaje
                if let out = outgoingSeason {
                    seasonIconView(out)
                        .offset(y: seasonAnimOffset)
                        .opacity(Double(1.0 - min(1.0, Double(seasonAnimOffset) / 36.0)))
                }
                // Dolazna ikona – dolazi odozgo (počinje iznad, pomakne se na mjesto)
                seasonIconView(displayedSeason)
                    .offset(y: outgoingSeason == nil ? 0 : CGFloat(-36) + seasonAnimOffset)
                    .opacity(outgoingSeason == nil ? 1 : Double(min(1.0, Double(seasonAnimOffset) / 36.0)))
            }
            .frame(width: 22, height: 28)
            .clipped()
        }
        .padding(.horizontal, 10)
        .frame(width: 120, height: 28)
        .clipped()
        .background(Color(white: 0, opacity: 0.35), in: RoundedRectangle(cornerRadius: 6))
        .help("Godina i godišnje doba")
    }

    private func seasonIconView(_ season: SeasonIcon) -> some View {
        Group {
            if let img = loadBarIcon(named: season.rawValue) {
                Image(nsImage: img)
                    .resizable()
                    .scaledToFit()
            } else {
                Image(systemName: "leaf.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(.white.opacity(0.9))
            }
        }
        .frame(width: 22, height: 22)
    }

    private var gameHUD: some View {
        MapScreenHUDBar {
            Button {
                gameState.showMainMenu()
            } label: {
                Label("Nazad", systemImage: "chevron.backward")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white.opacity(0.95))
            }
            .buttonStyle(.plain)
            .help("Nazad na izbornik")

            HUDBarDivider()

            // Mapa – veća ikona gumb, bez sive kutije
            Button {
                // Akcija – npr. pregled mape / fullscreen
            } label: {
                hudIconImage("map", fallback: "map", size: 32)
            }
            .buttonStyle(.plain)
            .help("Mapa")

            // Godišnje doba (samo ikona)
            seasonHUDView

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
