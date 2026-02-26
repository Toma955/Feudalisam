//
//  SoloSetupView.swift
//  Feudalism
//
//  Solo: gore odabir veličine; sredina crni prikaz mape; dolje resursi (veće ikone, bez okvira) + Nazad | Počni.
//

import SwiftUI

private let soloSetupCornerRadius: CGFloat = 20
private let stepperButtonSize: CGFloat = 40
private let resourceStep: Int = 25
private let resourceMax: Int = 9999

/// Tip solo mape: bundle level ili proceduralna.
enum SoloMapType: String, CaseIterable, Identifiable {
    case level = "Level (bundle)"
    case procedural = "Proceduralna"
    var id: String { rawValue }
    var levelName: String? {
        switch self {
        case .level: return "Level"
        case .procedural: return nil
        }
    }
}

/// Odabrani panel u donjem dijelu: Mapa, Resursi ili Pravila (Nazad/Pokreni su akcije).
private enum SoloSetupSection: String, CaseIterable {
    case map = "Mapa"
    case resources = "Resursi"
    case rules = "Pravila"
}

/// Shape: Capsule ili Circle da kompajler ne zapne na ternaru.
private struct CapsuleOrCircleShape: Shape {
    var useCapsule: Bool
    func path(in rect: CGRect) -> Path {
        useCapsule ? Capsule().path(in: rect) : Circle().path(in: rect)
    }
}

struct SoloSetupView: View {
    @EnvironmentObject private var gameState: GameState
    @Binding var isPresented: Bool
    @State private var selectedMapSize: MapSizePreset = .size200
    @State private var selectedMapType: SoloMapType = .level
    @State private var initialGold: Int = 0
    @State private var initialWood: Int = 0
    @State private var initialIron: Int = 0
    @State private var initialStone: Int = 0
    @State private var initialFood: Int = 0
    @State private var initialHop: Int = 0
    @State private var initialHay: Int = 0
    @State private var initialChicken: Int = 0
    @State private var initialEggs: Int = 0
    @State private var initialCorn: Int = 0
    @State private var initialGrapes: Int = 0
    @State private var initialMeat: Int = 0
    @State private var initialCheese: Int = 0
    @State private var initialBeer: Int = 0
    @State private var initialApple: Int = 0
    @State private var initialBanana: Int = 0
    @State private var initialCandle: Int = 0
    @State private var initialFlowers: Int = 0
    @State private var initialLeather: Int = 0
    @State private var initialMedicine: Int = 0
    @State private var initialShield: Int = 0
    @State private var initialSausages: Int = 0
    @State private var initialSpear: Int = 0
    @State private var initialSpices: Int = 0
    @State private var initialSword: Int = 0
    @State private var initialVegetables: Int = 0
    @State private var initialVine: Int = 0
    @State private var initialCrossbow: Int = 0
    @State private var initialMace: Int = 0
    @State private var initialBowAndSparrow: Int = 0
    @State private var selectedSection: SoloSetupSection = .map
    /// Indeks odabrane mape u listi za trenutnu veličinu (0-based). Koristi se kad u folderu ima mapa.
    @State private var selectedMapIndex: Int = 0
    // Opcije generiranja (kad je Generiraj odabrano)
    @State private var randomVegetacija: Bool = true
    @State private var randomRadnaPozicija: Bool = true
    @State private var randomRijeke: Bool = true
    @State private var randomOscilacijeTerena: Bool = true
    @State private var randomZemlje: Bool = true

    var body: some View {
        VStack(spacing: 0) {
            if selectedSection == .resources {
                sectionContent
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                Spacer(minLength: 0)
            } else {
                Spacer(minLength: 0)
                sectionContent
            }
            soloSetupBottomBar
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea(edges: .bottom)
        .onAppear { loadDefaultsFromFile() }
    }

    /// Sadržaj ovisno o odabiru: Mapa, Resursi ili Pravila.
    private var sectionContent: some View {
        Group {
            switch selectedSection {
            case .map:
                SoloMapChoiceView(
                    selectedMapSize: $selectedMapSize,
                    selectedMapIndex: $selectedMapIndex,
                    selectedMapType: $selectedMapType,
                    randomVegetacija: $randomVegetacija,
                    randomRadnaPozicija: $randomRadnaPozicija,
                    randomRijeke: $randomRijeke,
                    randomOscilacijeTerena: $randomOscilacijeTerena,
                    randomZemlje: $randomZemlje
                )
                .environmentObject(gameState)
            case .resources:
                resourcesSection
            case .rules:
                rulesSection
            }
        }
        .frame(maxWidth: .infinity)
        .animation(.easeInOut(duration: 0.2), value: selectedSection)
    }

    /// Donji bar: Nazad | Mapa | Resursi | Pravila | [Nazad/Naprijed ili Kreiraj] | 2,4,6,8,10 | Pokreni. Cijelo vrijeme pri dnu.
    private var soloSetupBottomBar: some View {
        HStack(spacing: 0) {
            Spacer(minLength: 0)
            HStack(alignment: .center, spacing: 16) {
                nazadButton
                sectionButtonsGroup
                mapNavOrCreateView
                mapSizeChoiceView
                pokreniButton
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(Color.white.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: soloSetupCornerRadius, style: .continuous))
            Spacer(minLength: 0)
        }
        .padding(.bottom, 10)
    }

    private var nazadButton: some View {
        Button { isPresented = false } label: {
            Label("Nazad", systemImage: "chevron.backward")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.white)
                .frame(minWidth: 88, minHeight: 44)
                .background(Color.black)
                .clipShape(RoundedRectangle(cornerRadius: soloSetupCornerRadius, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    /// Mapa | Resursi | Pravila: obli kvadrati unutar jednog oblog kvadrata.
    private static let sectionInnerSpacing: CGFloat = 6
    private static let sectionInnerCorner: CGFloat = 12

    private var sectionButtonsGroup: some View {
        HStack(spacing: Self.sectionInnerSpacing) {
            sectionButton(.map, label: "Mapa")
            sectionButton(.resources, label: "Resursi")
            sectionButton(.rules, label: "Pravila")
        }
        .padding(Self.sectionInnerSpacing)
        .background(Color.white.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: soloSetupCornerRadius, style: .continuous))
    }

    private func sectionButton(_ section: SoloSetupSection, label: String) -> some View {
        Button { selectedSection = section } label: {
            Text(label)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(selectedSection == section ? .white : .white.opacity(0.8))
                .frame(minWidth: 88, minHeight: 44)
                .background(selectedSection == section ? Color.green.opacity(0.9) : Color.white.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: Self.sectionInnerCorner, style: .continuous))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    /// Kad Map: jedan element – Kreiraj ili Nazad/Naprijed. Kad Resursi: 3 gumba. Kad Pravila: prazno.
    private static let mapNavBoxWidth: CGFloat = 120
    private static let mapNavBoxHeight: CGFloat = 44
    private static let mapNavContentAnimation: Animation = .easeInOut(duration: 0.32)
    private static let resourcesSlotSpacing: CGFloat = 6
    private static let resourcesSlotCorner: CGFloat = 12
    private static let resourcesThreeButtonsWidth: CGFloat = 156

    private var middleSectionWidth: CGFloat {
        switch selectedSection {
        case .map: return Self.mapNavBoxWidth
        case .resources: return Self.resourcesThreeButtonsWidth
        case .rules: return 0
        }
    }

    private var mapNavOrCreateView: some View {
        Group {
            if selectedSection == .map {
                ZStack {
                    if mapEntriesForCurrentSize.isEmpty {
                        Button {
                            selectedMapType = .procedural
                        } label: {
                            Text(LocalizedStrings.string(for: "solo_map_generate", language: gameState.appLanguage))
                                .font(.system(size: 15, weight: .medium))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .background(Color.green.opacity(0.85))
                                .clipShape(RoundedRectangle(cornerRadius: soloSetupCornerRadius, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        .transition(.opacity)
                    }
                    if !mapEntriesForCurrentSize.isEmpty {
                        HStack(spacing: 0) {
                            Button {
                                withAnimation(.easeInOut(duration: 0.34)) {
                                    selectedMapIndex = (selectedMapIndex - 1 + mapEntriesForCurrentSize.count) % mapEntriesForCurrentSize.count
                                }
                            } label: {
                                Image(systemName: "chevron.left")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(.white.opacity(0.9))
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                            }
                            .buttonStyle(.plain)
                            Button {
                                withAnimation(.easeInOut(duration: 0.34)) {
                                    selectedMapIndex = (selectedMapIndex + 1) % mapEntriesForCurrentSize.count
                                }
                            } label: {
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(.white.opacity(0.9))
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                            }
                            .buttonStyle(.plain)
                        }
                        .background(Color.white.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: soloSetupCornerRadius, style: .continuous))
                        .transition(.opacity)
                    }
                }
                .frame(width: Self.mapNavBoxWidth, height: Self.mapNavBoxHeight)
                .animation(Self.mapNavContentAnimation, value: mapEntriesForCurrentSize.isEmpty)
            } else if selectedSection == .resources {
                resourcesThreeButtonsView
            } else {
                Color.clear
                    .frame(width: 0, height: Self.mapNavBoxHeight)
            }
        }
        .frame(width: middleSectionWidth, height: Self.mapNavBoxHeight)
        .clipped()
        .animation(.easeInOut(duration: 0.3), value: selectedSection)
    }

    /// Kad je Resursi odabran: 3 gumba u jednom elementu (placeholderi za sada).
    private var resourcesThreeButtonsView: some View {
        HStack(spacing: Self.resourcesSlotSpacing) {
            ForEach(0..<3, id: \.self) { _ in
                Color.white.opacity(0.06)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: Self.resourcesSlotCorner, style: .continuous))
            }
        }
        .padding(Self.resourcesSlotSpacing)
        .background(Color.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: soloSetupCornerRadius, style: .continuous))
        .frame(width: Self.resourcesThreeButtonsWidth, height: Self.mapNavBoxHeight)
    }

    private var mapEntriesForCurrentSize: [MapCatalogEntry] {
        MapCatalog.entries(forSide: selectedMapSize.side)
    }

    private var mapSizeChoiceView: some View {
        HStack(spacing: 8) {
            ForEach(MapSizePreset.allCases) { preset in
                mapSizeButton(preset: preset)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.white.opacity(0.06))
        .clipShape(Capsule())
    }

    private func mapSizeButton(preset: MapSizePreset) -> some View {
        let isSelected = selectedMapSize == preset
        return Button {
            selectedMapSize = preset
            let entries = MapCatalog.entries(forSide: preset.side)
            selectedMapIndex = min(selectedMapIndex, max(0, entries.count - 1))
        } label: {
            mapSizeButtonLabel(text: "\(preset.side / 100)", isSelected: isSelected)
        }
        .buttonStyle(.plain)
    }

    private func mapSizeButtonLabel(text: String, isSelected: Bool) -> some View {
        Text(text)
            .font(.system(size: 14, weight: .medium))
            .foregroundStyle(.white.opacity(0.95))
            .frame(width: 40, height: 40)
            .background(isSelected ? Color.white.opacity(0.22) : Color.white.opacity(0.08))
            .clipShape(CapsuleOrCircleShape(useCapsule: isSelected))
    }

    private var pokreniButton: some View {
        Button {
            AudioManager.shared.stopIntroSoundtrack()
            let mapsForSize = MapCatalog.entries(forSide: selectedMapSize.side)
            if !mapsForSize.isEmpty {
                let entry = mapsForSize[min(selectedMapIndex, mapsForSize.count - 1)]
                gameState.startSoloWithMapEntry(
                    entry: entry,
                    initialGold: initialGold,
                    initialWood: initialWood,
                    initialIron: initialIron,
                    initialStone: initialStone,
                    initialFood: initialFood,
                    initialHop: initialHop,
                    initialHay: initialHay
                )
            } else {
                gameState.startNewGameWithSetup(
                    humanName: "Igrač",
                    selectedAIProfileIds: [],
                    mapSize: selectedMapSize,
                    initialGold: initialGold,
                    initialWood: initialWood,
                    initialIron: initialIron,
                    initialStone: initialStone,
                    initialFood: initialFood,
                    initialHop: initialHop,
                    initialHay: initialHay,
                    soloLevelName: selectedMapType.levelName
                )
            }
            isPresented = false
        } label: {
            HStack(spacing: 8) {
                Text("Pokreni")
                Image(systemName: "play.fill")
                    .font(.system(size: 15, weight: .semibold))
            }
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(.white)
            .frame(minWidth: 102, minHeight: 48)
            .background(Color.green)
            .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Resursi: tablica (grid) – 24 ostalih, zadnji red samo oružje (6)
    private static let resourceGridColumns = 6
    private var resourceItems: [(iconName: String, value: Binding<Int>, fallback: String)] {
        [
            // Redovi 1–4: ostali resursi (24)
            ("gold", $initialGold, "dollarsign.circle.fill"),
            ("wood_resource", $initialWood, "leaf.fill"),
            ("iron_resource", $initialIron, "cylinder.fill"),
            ("stone_resource", $initialStone, "mountain.2.fill"),
            ("bread_resource", $initialFood, "fork.knife"),
            ("hop_resource", $initialHop, "mug.fill"),
            ("hay_resource", $initialHay, "circle.hexagongrid.fill"),
            ("chicken_resource", $initialChicken, "bird.fill"),
            ("eggs_resouce", $initialEggs, "oval.fill"),
            ("corn_resource", $initialCorn, "leaf.fill"),
            ("grapes_resource", $initialGrapes, "leaf.circle.fill"),
            ("meat_resouce", $initialMeat, "fork.knife"),
            ("cheese_resource", $initialCheese, "square.fill"),
            ("beer_resource", $initialBeer, "mug.fill"),
            ("apple_resource", $initialApple, "apple.logo"),
            ("banana_resource", $initialBanana, "leaf.fill"),
            ("vegetables_resource", $initialVegetables, "carrot.fill"),
            ("spices_resources", $initialSpices, "leaf.fill"),
            ("candle_resource", $initialCandle, "flame.fill"), // na mjestu soli (sol maknuta)
            ("vine_resources", $initialVine, "drop.fill"),
            ("sosages_resouce", $initialSausages, "fork.knife"),
            ("leather_resources", $initialLeather, "square.fill"),
            ("flowers_resoiurce", $initialFlowers, "camera.macro"),
            ("medicine_reousrce", $initialMedicine, "cross.case.fill"),
            // Zadnji red: samo oružje (6) – gumbi + brojevi
            ("shield_resource", $initialShield, "shield.fill"),
            ("spear_resource", $initialSpear, "line.diagonal"),
            ("sword_resource", $initialSword, "line.diagonal"),
            ("crosbow_resource", $initialCrossbow, "scope"),
            ("mece_resource", $initialMace, "hammer.fill"),
            ("bow_and_sparrow_resouce", $initialBowAndSparrow, "arrow.up"), // bowl and sparrow
        ]
    }

    private var resourcesSection: some View {
        ScrollView(.vertical, showsIndicators: true) {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 20), count: Self.resourceGridColumns), spacing: 20) {
                ForEach(Array(resourceItems.enumerated()), id: \.offset) { _, item in
                    resourceRow(iconName: item.iconName, value: item.value, systemFallback: item.fallback, iconSize: 80, numberFontSize: 20)
                }
            }
            .padding(.horizontal, 32)
            .padding(.top, 0)
            .padding(.bottom, 20)
        }
        .frame(maxWidth: .infinity)
        .scrollContentBackground(.hidden)
    }

    // MARK: - Pravila (placeholder)
    private var rulesSection: some View {
        VStack(spacing: 12) {
            Text("Pravila")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.white.opacity(0.9))
            Text("Pravila igre – uskoro.")
                .font(.system(size: 14))
                .foregroundStyle(.white.opacity(0.6))
        }
        .padding(.vertical, 40)
    }

    private func loadDefaultsFromFile() {
        let def = StartingResourcesLoader.startingResources(for: "solo")
        initialGold = def.gold
        initialWood = def.wood
        initialIron = def.iron
        initialStone = def.stone
        initialFood = def.food
        initialHop = def.hop
        initialHay = def.hay
    }

    private func resourceRow(iconName: String, value: Binding<Int>, systemFallback: String = "cube.fill", alsoTryIconNames: [String] = [], iconSize: CGFloat = 64, numberFontSize: CGFloat = 18) -> some View {
        let img = loadBarIcon(named: iconName)
            ?? alsoTryIconNames.lazy.compactMap { loadBarIcon(named: $0) }.first
        let btnSize: CGFloat = iconSize > 70 ? 44 : stepperButtonSize
        return VStack(spacing: 8) {
            Group {
                if let nsImg = img {
                    Image(nsImage: nsImg)
                        .resizable()
                        .scaledToFit()
                } else {
                    Image(systemName: systemFallback)
                        .font(.system(size: min(iconSize * 0.6, 48)))
                        .foregroundStyle(.white.opacity(0.95))
                }
            }
            .frame(width: iconSize, height: iconSize)
            HStack(spacing: 8) {
                Button {
                    value.wrappedValue = max(0, value.wrappedValue - resourceStep)
                } label: {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.9))
                        .frame(width: btnSize, height: btnSize)
                        .background(Color.white.opacity(0.15))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                Text("\(value.wrappedValue)")
                    .font(.system(size: numberFontSize, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.98))
                    .frame(minWidth: 48, alignment: .center)
                Button {
                    value.wrappedValue = min(resourceMax, value.wrappedValue + resourceStep)
                } label: {
                    Image(systemName: "chevron.up")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.9))
                        .frame(width: btnSize, height: btnSize)
                        .background(Color.white.opacity(0.15))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
    }
}

#Preview {
    SoloSetupView(isPresented: .constant(true))
        .environmentObject(GameState())
        .frame(width: 1600, height: 920)
        .background(Color.black.opacity(0.5))
}
