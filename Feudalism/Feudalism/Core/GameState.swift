//
//  GameState.swift
//  Feudalism
//
//  Globalno stanje igre – krajevi (realmi), resursi, potezi. Jedan kralj = solo; više = dok zadnji ne ostane.
//

import Foundation
import SwiftUI

/// Ulazni uređaj za upravljanje – u General postavkama; kasnije posebne funkcije za trackpad i miš.
enum InputDevice: String, CaseIterable {
    case trackpad = "trackpad"
    case mouse = "mouse"
    var displayName: String {
        switch self {
        case .trackpad: return "Trackpad"
        case .mouse: return "Miš"
        }
    }
}

/// Jezik sučelja – lokalizacija preko Locales mape (hr, en, de, fr, it, es).
enum AppLanguage: String, CaseIterable, Identifiable {
    case croatian = "hr"
    case english = "en"
    case german = "de"
    case french = "fr"
    case italian = "it"
    case spanish = "es"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .croatian: return "Hrvatski"
        case .english: return "English"
        case .german: return "Deutsch"
        case .french: return "Français"
        case .italian: return "Italiano"
        case .spanish: return "Español"
        }
    }

    /// Lokalni identifikator za učitavanje iz Locales/{rawValue}/.
    var localeIdentifier: String { rawValue }
}

/// Amblem igrača – Postavke → Profil. Kasnije se može proširiti s vlastitim slikama.
enum PlayerEmblem: String, CaseIterable, Identifiable {
    case shield = "shield"
    case crown = "crown"
    case star = "star"
    case flag = "flag"
    case castle = "castle"
    case lion = "lion"

    var id: String { rawValue }

    var sfSymbolName: String {
        switch self {
        case .shield: return "shield.fill"
        case .crown: return "crown.fill"
        case .star: return "star.fill"
        case .flag: return "flag.fill"
        case .castle: return "building.2.fill"
        case .lion: return "pawprint.fill"
        }
    }

    var displayName: String {
        switch self {
        case .shield: return "Štit"
        case .crown: return "Kruna"
        case .star: return "Zvijezda"
        case .flag: return "Zastava"
        case .castle: return "Dvorac"
        case .lion: return "Lav"
        }
    }
}

/// Način igre: jedan kraj = solo; više = natjecateljski (pobijedi onaj koji zadnji ostane).
enum GameMode {
    /// Jedan realm na mapi – solo igra.
    case solo
    /// Više realmova – igra dok ne ostane samo jedan (ili jedna grupa).
    case lastStanding
}

/// Globalno stanje srednjovjekovne strateške igre.
final class GameState: ObservableObject {
    /// true = glavni izbornik (Nova igra / Postavke / Izlaz), false = igra (karta).
    @Published var isShowingMainMenu: Bool = true
    /// true = Map Editor (uređivanje mape), ne igra.
    @Published var isMapEditorMode: Bool = false
    /// false dok se level (mapa, teren) ne učita; tek onda se prikaže igra (bez overlay-a).
    @Published var isLevelReady: Bool = false

    /// Poruka tijekom učitavanja mape (npr. "Učitavanje mape (200×200)…", "Generiranje mape (200×200)…"). Nil kad je level spreman.
    @Published var levelLoadingMessage: String?

    /// Krajevi (kraljevstva) na mapi – jedan ili više. Jedan = solo, više = last standing.
    @Published var realms: [Realm] = []
    /// Grupe (savezi) – realmi s istim groupId dijele pobjedu.
    @Published var realmGroups: [RealmGroup] = []
    /// Realm kojim igrač upravlja (nil u solo ako nema „protivnika”).
    @Published var playerRealmId: String?

    @Published var gold: Int = 100
    @Published var food: Int = 80
    @Published var wood: Int = 0
    @Published var iron: Int = 0
    @Published var stone: Int = 0
    @Published var hay: Int = 0
    @Published var hop: Int = 0

    @Published var selectedRegionId: String?
    @Published var selectedMapCoordinate: MapCoordinate?
    @Published var currentTurn: Int = 1

    /// Postavke kamere na mapi (zoom, nagib, brzina pomicanja) – mijenjaju se u Postavkama.
    @Published var mapCameraSettings: MapCameraSettings = MapCameraSettings()

    /// Odabrani objekt za postavljanje (npr. Wall.objectId); nil = ništa odabrano.
    @Published var selectedPlacementObjectId: String?

    /// Odabrani alat u panelu Alati: "sword", "mace", "report", "shovel", "pen". Nil = mač (zadano). Utječe na kursor i oznaku u panelu.
    @Published var selectedToolsPanelItem: String?

    /// Mapa mape – grid u 1×1 jedinicama (100×100, 200×200 ili 1000×1000).
    @Published var gameMap: GameMap

    /// Ime levela za učitavanje iz .scn (bez ekstenzije). Npr. "Level" ili "Maps/Level". Nil = proceduralni teren.
    @Published var currentLevelName: String?

    /// Povećava se pri svakom place/remove da SwiftUI sigurno ažurira prikaz mape.
    @Published private(set) var placementsVersion: Int = 0

    /// Ako postavljanje objekta ne uspije, ovdje je poruka za alert. Postavi na nil nakon prikaza.
    @Published var placementError: String?

    /// Status učitavanja teksture zida (prikazuje se u Map Editoru). nil = još nije provjereno.
    @Published var wallTextureStatus: String?

    /// Da se animacija resursa 0→100 u solo modu pokrene samo jednom kad se level učita.
    private var hasRunSoloResourceAnimation = false
    private var soloResourceAnimationWorkItem: DispatchWorkItem?

    private static let inputDeviceKey = "Feudalism.inputDevice"
    private static let appLanguageKey = "Feudalism.appLanguage"
    private static let playerProfileNameKey = "Feudalism.playerProfileName"
    private static let playerEmblemIdKey = "Feudalism.playerEmblemId"
    private static let showStartupAnimationKey = "Feudalism.showStartupAnimation"
    private static let showBottomBarLabelsKey = "Feudalism.showBottomBarLabels"
    private static let playPlacementSoundKey = "Feudalism.playPlacementSound"
    private static let playBarTransitionSoundKey = "Feudalism.playBarTransitionSound"
    private static let audioMusicVolumeKey = "Feudalism.audioMusicVolume"
    private static let audioSoundsVolumeKey = "Feudalism.audioSoundsVolume"
    private static let audioSpeechVolumeKey = "Feudalism.audioSpeechVolume"

    /// Trackpad ili miš – u Postavkama → General; kasnije posebne funkcije po uređaju.
    @Published var inputDevice: InputDevice {
        didSet { UserDefaults.standard.set(inputDevice.rawValue, forKey: Self.inputDeviceKey) }
    }

    /// Glasnoća muzike mape (0...1). Postavke → Audio.
    @Published var audioMusicVolume: Double {
        didSet { UserDefaults.standard.set(audioMusicVolume, forKey: Self.audioMusicVolumeKey) }
    }
    /// Glasnoća zvukova (0...1). Postavke → Audio.
    @Published var audioSoundsVolume: Double {
        didSet { UserDefaults.standard.set(audioSoundsVolume, forKey: Self.audioSoundsVolumeKey) }
    }
    /// Glasnoća govora (0...1). Postavke → Audio.
    @Published var audioSpeechVolume: Double {
        didSet { UserDefaults.standard.set(audioSpeechVolume, forKey: Self.audioSpeechVolumeKey) }
    }

    /// Jezik sučelja (hr, en, de, fr). Postavke → General; priprema za lokalizaciju.
    @Published var appLanguage: AppLanguage {
        didSet { UserDefaults.standard.set(appLanguage.rawValue, forKey: Self.appLanguageKey) }
    }

    /// Naziv profila igrača. Postavke → Profil.
    @Published var playerProfileName: String {
        didSet { UserDefaults.standard.set(playerProfileName, forKey: Self.playerProfileNameKey) }
    }

    /// Amblem profila (shield, crown, …). Postavke → Profil.
    @Published var playerEmblemId: String {
        didSet { UserDefaults.standard.set(playerEmblemId, forKey: Self.playerEmblemIdKey) }
    }

    /// true = prikaži početnu animaciju pri pokretanju igre. Postavke → General.
    @Published var showStartupAnimation: Bool {
        didSet { UserDefaults.standard.set(showStartupAnimation, forKey: Self.showStartupAnimationKey) }
    }

    /// true = prikaži nazive ispod ikona u donjem izborniku (solo). Postavke → General.
    @Published var showBottomBarLabels: Bool {
        didSet { UserDefaults.standard.set(showBottomBarLabels, forKey: Self.showBottomBarLabelsKey) }
    }

    /// true = pri reprodukciji zvuka pri postavljanju objekta (place.wav). Postavke → Audio.
    @Published var playPlacementSound: Bool {
        didSet { UserDefaults.standard.set(playPlacementSound, forKey: Self.playPlacementSoundKey) }
    }

    /// true = reproduciraj transition.wav kad se u donjem baru mijenja kategorija (npr. Dvor → Farma). Postavke → Audio.
    @Published var playBarTransitionSound: Bool {
        didSet { UserDefaults.standard.set(playBarTransitionSound, forKey: Self.playBarTransitionSoundKey) }
    }

    init(mapSize: MapSizePreset = .size200) {
        self.gameMap = mapSize.makeGameMap()
        let raw = UserDefaults.standard.string(forKey: Self.inputDeviceKey) ?? InputDevice.trackpad.rawValue
        self.inputDevice = InputDevice(rawValue: raw) ?? .trackpad
        let langRaw = UserDefaults.standard.string(forKey: Self.appLanguageKey) ?? AppLanguage.croatian.rawValue
        self.appLanguage = AppLanguage(rawValue: langRaw) ?? .croatian
        self.playerProfileName = UserDefaults.standard.string(forKey: Self.playerProfileNameKey) ?? ""
        let emblemRaw = UserDefaults.standard.string(forKey: Self.playerEmblemIdKey) ?? PlayerEmblem.shield.rawValue
        self.playerEmblemId = PlayerEmblem(rawValue: emblemRaw)?.rawValue ?? PlayerEmblem.shield.rawValue
        self.showStartupAnimation = UserDefaults.standard.object(forKey: Self.showStartupAnimationKey) as? Bool ?? true
        self.showBottomBarLabels = UserDefaults.standard.object(forKey: Self.showBottomBarLabelsKey) as? Bool ?? true
        self.playPlacementSound = UserDefaults.standard.object(forKey: Self.playPlacementSoundKey) as? Bool ?? true
        self.playBarTransitionSound = UserDefaults.standard.object(forKey: Self.playBarTransitionSoundKey) as? Bool ?? true
        self.audioMusicVolume = UserDefaults.standard.object(forKey: Self.audioMusicVolumeKey) as? Double ?? 0.6
        self.audioSoundsVolume = UserDefaults.standard.object(forKey: Self.audioSoundsVolumeKey) as? Double ?? 0.8
        self.audioSpeechVolume = UserDefaults.standard.object(forKey: Self.audioSpeechVolumeKey) as? Double ?? 0.8
        self.currentLevelName = "Level"  // učitaj Level.scn ako postoji; inače proceduralni teren
    }

    // MARK: - Način igre

    /// Jedan kralj na mapi = solo; više = last standing.
    var gameMode: GameMode {
        realms.isEmpty ? .solo : (realms.count == 1 ? .solo : .lastStanding)
    }

    var isSoloMode: Bool { gameMode == .solo }

    /// Aktivni krajevi (nisu poraženi).
    var activeRealms: [Realm] {
        realms.filter { !$0.isDefeated }
    }

    /// Human lords – igrač kontrolira igru (ovi krajevi).
    var humanLords: [Realm] { realms.filter { $0.lordType == .human } }

    /// Computer lords – AI kontrolira ove krajeve.
    var computerLords: [Realm] { realms.filter { $0.lordType == .computer } }

    /// Frakcija = jedan realm (ako nema grupe) ili grupa. Preostale frakcije = različiti groupId ili nil.
    private var remainingFactionIds: Set<String> {
        let active = activeRealms
        return Set(active.map { $0.groupId ?? $0.id })
    }

    /// Ima li samo jedna frakcija preostala (jedan realm ili jedna grupa)?
    var hasSingleRemainingFaction: Bool {
        remainingFactionIds.count == 1
    }

    /// Pobjednik: jedan preostali realm ili jedna preostala grupa. Nil = igra nije gotova.
    var winningRealmId: String? {
        let active = activeRealms
        guard !active.isEmpty, hasSingleRemainingFaction else { return nil }
        return active.first?.id
    }

    /// Pobjednička grupa (ako je pobjeda saveza). Nil ako je pobjednik pojedinačni realm (nema grupe).
    var winningGroupId: String? {
        let active = activeRealms
        guard active.count > 1, hasSingleRemainingFaction,
              let gid = active.first?.groupId, !gid.isEmpty else { return nil }
        return gid
    }

    /// Je li igra gotova (ima pobjednika)?
    var hasWinner: Bool { winningRealmId != nil }

    /// Označi kraj kao poražen (nema teritorija / kralj pao).
    func defeatRealm(id: String) {
        guard let i = realms.firstIndex(where: { $0.id == id }) else { return }
        realms[i].isDefeated = true
    }

    /// Dodaj kraj na mapu.
    func addRealm(_ realm: Realm) {
        guard !realms.contains(where: { $0.id == realm.id }) else { return }
        realms.append(realm)
        if realm.isPlayerControlled { playerRealmId = realm.id }
    }

    /// Postavi listu kraljevstava (nova igra).
    func setRealms(_ newRealms: [Realm]) {
        realms = newRealms
        playerRealmId = newRealms.first { $0.isPlayerControlled }?.id
    }

    /// Postavi trenutno odabrani objekt na (row, col). Vraća true ako je uspjelo. U igri (ne Map Editor) troši resurse prema BuildCosts.
    func placeSelectedObjectAt(row: Int, col: Int) -> Bool {
        placementError = nil
        guard let objectId = selectedPlacementObjectId else {
            let msg = "Nije odabran objekt za postavljanje. Prvo odaberi Zid (Dvor → Zid)."
            placementError = msg
            return false
        }
        if !isMapEditorMode {
            let cost = BuildCosts.shared.cost(for: objectId)
            if !BuildCosts.shared.canAfford(objectId: objectId, stone: stone, wood: wood, iron: iron) {
                placementError = "Nedovoljno resursa. Potrebno: \(cost.stone) kamen, \(cost.wood) drvo, \(cost.iron) željezo."
                return false
            }
        }
        let obj = ObjectCatalog.shared.object(id: objectId)
        let width = obj?.size.width ?? 1
        let height = obj?.size.height ?? 1
        guard let _ = gameMap.place(objectId: objectId, width: width, height: height, atRow: row, col: col) else {
            let msg = "Ne može se staviti na (\(row), \(col)) – ćelija zauzeta ili izvan mape \(gameMap.rows)×\(gameMap.cols)."
            placementError = msg
            return false
        }
        if !isMapEditorMode {
            let cost = BuildCosts.shared.cost(for: objectId)
            stone -= cost.stone
            wood -= cost.wood
            iron -= cost.iron
        }
        placementsVersion += 1
        objectWillChange.send()
        if playPlacementSound {
            AudioManager.shared.playSound(named: "place", volume: audioSoundsVolume)
        }
        return true
    }

    /// Ukloni placement koji pokriva danu koordinatu (Map Editor – alat za brisanje).
    func removePlacement(at coordinate: MapCoordinate) {
        guard let p = gameMap.placement(at: coordinate) else { return }
        gameMap.removePlacement(id: p.id)
        placementsVersion += 1
        objectWillChange.send()
    }

    /// Otvori Map Editor – prazna mapa prema trenutnoj veličini.
    func openMapEditor() {
        setMapSize(.size200)
        selectedPlacementObjectId = nil
        isShowingMainMenu = false
        isMapEditorMode = true
        isLevelReady = false
        levelLoadingMessage = "Učitavanje mape (\(gameMap.rows)×\(gameMap.cols))…"
    }

    /// Zatvori Map Editor i vrati se na izbornik.
    func closeMapEditor() {
        isMapEditorMode = false
        isShowingMainMenu = true
    }

    /// Spremi trenutnu mapu u Application Support (Map Editor). Vraća true ako je uspjelo.
    func saveEditorMap() -> Bool {
        let data = MapEditorSaveData(rows: gameMap.rows, cols: gameMap.cols, placements: gameMap.placements)
        guard let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
            .appendingPathComponent("Feudalism", isDirectory: true) else { return false }
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let fileURL = dir.appendingPathComponent("map_editor_save.json")
        guard let encoded = try? JSONEncoder().encode(data) else { return false }
        do {
            try encoded.write(to: fileURL)
            return true
        } catch {
            return false
        }
    }

    /// Učitaj mapu iz Application Support (Map Editor). Podržana je samo 100×100. Vraća true ako je uspjelo.
    func loadEditorMap() -> Bool {
        guard let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else { return false }
        let fileURL = dir.appendingPathComponent("Feudalism").appendingPathComponent("map_editor_save.json")
        guard FileManager.default.fileExists(atPath: fileURL.path),
              let raw = try? Data(contentsOf: fileURL),
              let data = try? JSONDecoder().decode(MapEditorSaveData.self, from: raw) else { return false }
        guard data.rows == gameMap.rows, data.cols == gameMap.cols else { return false }
        gameMap.replacePlacements(data.placements)
        objectWillChange.send()
        return true
    }

    /// Map Editor: obriši sve objekte s mape.
    func clearEditorMap() {
        gameMap.replacePlacements([])
        objectWillChange.send()
    }

    /// Prikaži glavni izbornik (nazad iz igre).
    func showMainMenu() {
        isShowingMainMenu = true
    }

    /// Pokreni novu igru – skriva izbornik, prikazuje karticu. Resursi se u solo modu animiraju 0→100 kad se level učita.
    func startNewGame() {
        isLevelReady = false
        levelLoadingMessage = "Učitavanje mape (\(gameMap.rows)×\(gameMap.cols))…"
        isShowingMainMenu = false
        hasRunSoloResourceAnimation = false
        if isSoloMode {
            stone = 0
            wood = 0
            iron = 0
        }
    }

    /// Dodaj sebe (human lord) i odabrane AI lordove, pa pokreni igru. Solo = samo ti; mapSize određuje veličinu mape.
    func startNewGameWithSetup(humanName: String, humanColorHex: String = "2E86AB", selectedAIProfileIds: [String], mapSize: MapSizePreset = .size200) {
        let store = AILordProfileStore.shared
        var newRealms: [Realm] = []
        let human = Realm(
            name: humanName.isEmpty ? "Igrač" : humanName,
            colorHex: humanColorHex,
            lordType: .human
        )
        newRealms.append(human)
        for profileId in selectedAIProfileIds {
            guard let p = store.profile(id: profileId) else { continue }
            let computer = Realm(
                name: p.name,
                colorHex: p.displayColorHex,
                lordType: .computer,
                aiProfileId: p.id
            )
            newRealms.append(computer)
        }
        setRealms(newRealms)
        setMapSize(mapSize)
        startNewGame()
    }

    /// Pozovi kad je level učitan (isLevelReady = true). U solo igri (ne Map Editor) animira kamen, drvo i željezo od 0 do 100 (jednom).
    func runSoloResourceAnimationIfNeeded() {
        guard isSoloMode, !isMapEditorMode, !hasRunSoloResourceAnimation else { return }
        hasRunSoloResourceAnimation = true
        soloResourceAnimationWorkItem?.cancel()
        runSoloResourceAnimationStep(step: 0, steps: 50, interval: 1.5 / 50, stepAmount: 2)
    }

    private func runSoloResourceAnimationStep(step: Int, steps: Int, interval: TimeInterval, stepAmount: Int) {
        let value = min(100, step * stepAmount)
        DispatchQueue.main.async { [weak self] in
            self?.stone = value
            self?.wood = value
            self?.iron = value
        }
        guard step < steps else { return }
        let next = step + 1
        let work = DispatchWorkItem { [weak self] in
            self?.runSoloResourceAnimationStep(step: next, steps: steps, interval: interval, stepAmount: stepAmount)
        }
        soloResourceAnimationWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + interval, execute: work)
    }

    /// Promijeni veličinu mape (nova igra).
    func setMapSize(_ preset: MapSizePreset) {
        gameMap = preset.makeGameMap()
    }
}
