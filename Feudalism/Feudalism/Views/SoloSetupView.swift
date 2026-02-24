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
    // Opcije generiranja (kad je Generiraj odabrano)
    @State private var randomVegetacija: Bool = true
    @State private var randomRadnaPozicija: Bool = true
    @State private var randomRijeke: Bool = true
    @State private var randomOscilacijeTerena: Bool = true
    @State private var randomZemlje: Bool = true

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 16)

            // Sadržaj ovisno o odabiru: Mapa (s indikatorom veličine) ili Resursi ili Pravila
            Group {
                switch selectedSection {
                case .map:
                    mapSection
                case .resources:
                    resourcesSection
                case .rules:
                    rulesSection
                }
            }
            .frame(maxWidth: .infinity)
            .animation(.easeInOut(duration: 0.2), value: selectedSection)

            Spacer(minLength: 0)

            // 5 gumba pri dnu: Nazad | Mapa | Resursi | Pravila | Pokreni
            HStack(spacing: 0) {
                Spacer(minLength: 0)
                HStack(alignment: .center, spacing: 16) {
                    Button { isPresented = false } label: {
                        Label("Nazad", systemImage: "chevron.backward")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(.white)
                            .frame(minWidth: 88, minHeight: 44)
                            .background(Color.black)
                            .clipShape(RoundedRectangle(cornerRadius: soloSetupCornerRadius, style: .continuous))
                    }
                    .buttonStyle(.plain)

                    Button { selectedSection = .map } label: {
                        Text("Mapa")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(selectedSection == .map ? .white : .white.opacity(0.8))
                            .frame(minWidth: 88, minHeight: 44)
                            .background(selectedSection == .map ? Color.green.opacity(0.9) : Color.white.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: soloSetupCornerRadius, style: .continuous))
                    }
                    .buttonStyle(.plain)

                    Button { selectedSection = .resources } label: {
                        Text("Resursi")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(selectedSection == .resources ? .white : .white.opacity(0.8))
                            .frame(minWidth: 88, minHeight: 44)
                            .background(selectedSection == .resources ? Color.green.opacity(0.9) : Color.white.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: soloSetupCornerRadius, style: .continuous))
                    }
                    .buttonStyle(.plain)

                    Button { selectedSection = .rules } label: {
                        Text("Pravila")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(selectedSection == .rules ? .white : .white.opacity(0.8))
                            .frame(minWidth: 88, minHeight: 44)
                            .background(selectedSection == .rules ? Color.green.opacity(0.9) : Color.white.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: soloSetupCornerRadius, style: .continuous))
                    }
                    .buttonStyle(.plain)

                    Button {
                        AudioManager.shared.stopIntroSoundtrack()
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
                        isPresented = false
                    } label: {
                        Label("Pokreni", systemImage: "play.fill")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(minWidth: 88, minHeight: 44)
                            .background(Color.green)
                            .clipShape(RoundedRectangle(cornerRadius: soloSetupCornerRadius, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .background(Color.white.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: soloSetupCornerRadius, style: .continuous))
                Spacer(minLength: 0)
            }
            .padding(.bottom, 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear { loadDefaultsFromFile() }
    }

    // MARK: - Mapa: prikaz mape s indikatorom veličine + Učitaj/Generiraj
    private var mapSection: some View {
        VStack(spacing: 20) {
            let previewSide: CGFloat = {
                switch selectedMapSize {
                case .size200: return 180
                case .size400: return 260
                case .size800: return 340
                case .size1000: return 400
                }
            }()
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.black.opacity(0.6))
                    .frame(width: previewSide, height: previewSide)
                    .animation(.easeInOut(duration: 0.28), value: selectedMapSize)
            }
            .frame(width: 420, height: 420)

            // Indikator veličine (200×200 … 1000×1000)
            HStack(spacing: 6) {
                ForEach(MapSizePreset.allCases) { preset in
                    Button {
                        selectedMapSize = preset
                    } label: {
                        Text(preset.rawValue)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.white.opacity(0.95))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .background(selectedMapSize == preset ? Color.white.opacity(0.22) : Color.white.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }

            // Učitaj | Generiraj (flip-flop)
            HStack(spacing: 10) {
                Button {
                    selectedMapType = .level
                } label: {
                    Text(LocalizedStrings.string(for: "solo_map_load", language: gameState.appLanguage))
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(selectedMapType == .level ? .white : .white.opacity(0.6))
                        .frame(minWidth: 80, minHeight: 44)
                        .background(selectedMapType == .level ? Color.green.opacity(0.9) : Color.white.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .buttonStyle(.plain)
                Button {
                    selectedMapType = .procedural
                } label: {
                    Text(LocalizedStrings.string(for: "solo_map_generate", language: gameState.appLanguage))
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(selectedMapType == .procedural ? .white : .white.opacity(0.6))
                        .frame(minWidth: 80, minHeight: 44)
                        .background(selectedMapType == .procedural ? Color.green.opacity(0.9) : Color.white.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .buttonStyle(.plain)
            }

            // Kad je Generiraj: gumbi za random opcije (vegetacija, radna pozicija, rijeke, oscilacije terena, zemlje)
            if selectedMapType == .procedural {
                VStack(spacing: 10) {
                    HStack(spacing: 8) {
                        genOptionButton(title: "Random vegetacija", isOn: $randomVegetacija)
                        genOptionButton(title: "Random radna pozicija", isOn: $randomRadnaPozicija)
                        genOptionButton(title: "Random rijeke", isOn: $randomRijeke)
                    }
                    HStack(spacing: 8) {
                        genOptionButton(title: "Random oscilacije terena", isOn: $randomOscilacijeTerena)
                        genOptionButton(title: "Random zemlje", isOn: $randomZemlje)
                    }
                }
                .padding(.top, 8)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    private func genOptionButton(title: String, isOn: Binding<Bool>) -> some View {
        Button {
            isOn.wrappedValue.toggle()
        } label: {
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(isOn.wrappedValue ? .white : .white.opacity(0.6))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(isOn.wrappedValue ? Color.green.opacity(0.85) : Color.white.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
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
            .padding(.top, -32)
            .padding(.bottom, 20)
        }
        .frame(maxWidth: .infinity)
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
