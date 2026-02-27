//
//  GameState.swift
//  Feudalism
//
//  Globalno stanje igre – krajevi (realmi), resursi, potezi. Jedan kralj = solo; više = dok zadnji ne ostane.
//

import Foundation
import SwiftUI
import Combine

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

    @Published var food: Int = 80
    /// Jedini izvor istine za kamen, drvo, željezo – sve davanja/trošenja/prodaja idu preko ovoga.
    let resources: GameResources
    private var resourcesCancellable: AnyCancellable?
    private var mapEditorStateCancellable: AnyCancellable?
    @Published var hay: Int = 0
    @Published var hop: Int = 0

    @Published var selectedRegionId: String?
    @Published var selectedMapCoordinate: MapCoordinate?
    @Published var currentTurn: Int = 1

    /// Postavke kamere na mapi (zoom, nagib, brzina pomicanja) – mijenjaju se u Postavkama.
    @Published var mapCameraSettings: MapCameraSettings = MapCameraSettings()

    /// Odabrani objekt za postavljanje (npr. HugeWall.objectId); nil = ništa odabrano.
    @Published var selectedPlacementObjectId: String?

    /// Odabrani alat u panelu Alati: "sword", "mace", "report", "shovel", "pen". Nil = mač (zadano). Utječe na kursor i oznaku u panelu.
    @Published var selectedToolsPanelItem: String?

    /// Mapa mape – grid u 1×1 jedinicama (100×100, 200×200 ili 1000×1000).
    @Published var gameMap: GameMap

    /// Ime levela za učitavanje iz .scn (bez ekstenzije). Npr. "Level" ili "Maps/Level". Nil = proceduralni teren.
    @Published var currentLevelName: String?
    /// true kad je solo pokrenut s mapom učitanoj iz datoteke (Maps/…); scena gradi teren iz gameMap umjesto Level.scn/SoloLevel.scn.
    @Published var soloMapLoadedFromFile: Bool = false

    /// Povećava se pri svakom place/remove da SwiftUI sigurno ažurira prikaz mape.
    @Published private(set) var placementsVersion: Int = 0

    /// Ako postavljanje objekta ne uspije, ovdje je poruka za alert. Postavi na nil nakon prikaza.
    @Published var placementError: String?

    /// Status učitavanja teksture zida (prikazuje se u Map Editoru). nil = još nije provjereno.
    @Published var wallTextureStatus: String?

    /// Trenutni slot u Map Editoru (postavlja se pri učitavanju; nil kad je Create map).
    @Published var mapEditorCurrentSlot: MapEditorSlot?
    /// Ime trenutne mape (obavezno za spremanje); postavlja se pri učitavanju ili kad korisnik upiše.
    @Published var mapEditorMapName: String = ""
    /// Datum izgradnje mape (postavlja se pri kreiranju; pri učitavanju iz datoteke).
    @Published var mapEditorCreatedDate: Date?
    /// Editor-only stanje (selected, hovered, brushPreview, undo/redo) – generira se pri uključivanju editora, ne spremaju se u datoteku.
    @Published var mapEditorState: MapEditorState?
    /// Povećava se kad se kreira ili učitava mapa – forsira ponovnu izgradnju scene u Map Editoru da se prikaže trenutna mapa.
    @Published private(set) var mapEditorSceneVersion: Int = 0

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
        let res = GameResources()
        self.resources = res
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
        self.resourcesCancellable = res.objectWillChange.sink { [weak self] _ in self?.objectWillChange.send() }
    }

    /// Proslijedi promjene iz mapEditorState (npr. selectedCells) da se SwiftUI i overlay odabira osvježe.
    private func bindMapEditorStateChanges() {
        mapEditorStateCancellable?.cancel()
        mapEditorStateCancellable = mapEditorState?.objectWillChange.sink { [weak self] _ in self?.objectWillChange.send() }
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

    /// Prikaži glavni izbornik (nazad iz igre).
    func showMainMenu() {
        isShowingMainMenu = true
    }

    /// Pokreni novu igru – skriva izbornik, prikazuje karticu. Resursi se u solo modu animiraju 0→100 kad se level učita.
    func startNewGame() {
        isLevelReady = false
        levelLoadingMessage = "Učitavanje mape (\(gameMap.displayDimensionString))…"
        isShowingMainMenu = false
        if isSoloMode {
            resources.resetForNewSoloGame()
        }
    }

    /// Dodaj sebe (human lord) i odabrane AI lordove, pa pokreni igru. Solo = samo ti; mapSize određuje veličinu mape.
    /// Početni resursi: mogu doći iz datoteke (StartingResourcesLoader / starting_resources.json) ili iz UI overridea u SoloSetupView.
    /// initialGold/Wood/Iron/Stone: vrijednosti koje igrač dobiva na početku (pročitane iz filea ili odabrane strelicama).
    /// soloLevelName: ime levela iz bundlea (npr. "Level") ili nil za proceduralnu mapu.
    func startNewGameWithSetup(
        humanName: String,
        humanColorHex: String = "2E86AB",
        selectedAIProfileIds: [String],
        mapSize: MapSizePreset = .size200,
        initialGold: Int = 0,
        initialWood: Int = 0,
        initialIron: Int = 0,
        initialStone: Int = 0,
        initialFood: Int = 0,
        initialHop: Int = 0,
        initialHay: Int = 0,
        soloLevelName: String? = "Level"
    ) {
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
        currentLevelName = soloLevelName
        soloMapLoadedFromFile = false
        if isSoloMode, soloLevelName == nil {
            SceneKitLevelLoader.deleteSoloLevelFiles()
        }
        startNewGame()
        if isSoloMode {
            resources.setStock(stone: max(0, initialStone), wood: max(0, initialWood), iron: max(0, initialIron), gold: max(0, initialGold))
            food = max(0, initialFood)
            hop = max(0, initialHop)
            hay = max(0, initialHay)
        }
    }

    /// Solo: pokreni igru s mapom učitanoj iz kataloškog unosa (datoteka iz Maps/200x200/, …). Teren i placements dolaze iz te datoteke.
    func startSoloWithMapEntry(
        entry: MapCatalogEntry,
        initialGold: Int = 0,
        initialWood: Int = 0,
        initialIron: Int = 0,
        initialStone: Int = 0,
        initialFood: Int = 0,
        initialHop: Int = 0,
        initialHay: Int = 0
    ) {
        setRealms([Realm(name: "Igrač", colorHex: "2E86AB", lordType: .human)])
        guard let root = MapStorage.mapsRoot() else { return }
        let fileURL = root.appendingPathComponent(entry.path)
        guard let data = MapFileManager.load(from: fileURL) else { return }
        applyLoadedMapDataForSolo(data)
        currentLevelName = nil
        soloMapLoadedFromFile = true
        startNewGame()
        resources.setStock(stone: max(0, initialStone), wood: max(0, initialWood), iron: max(0, initialIron), gold: max(0, initialGold))
        food = max(0, initialFood)
        hop = max(0, initialHop)
        hay = max(0, initialHay)
    }

    /// Primijeni učitane podatke na gameMap (solo – bez editor state).
    private func applyLoadedMapDataForSolo(_ data: MapEditorSaveData) {
        let newMap = GameMap(rows: data.rows, cols: data.cols)
        newMap.replacePlacements(data.placements)
        if let cells = data.cells { newMap.replaceCells(cells) }
        if let vh = data.vertexHeights { newMap.replaceVertexHeights(Dictionary(uniqueKeysWithValues: vh.map { ($0.key, CGFloat($0.value)) })) }
        newMap.originOffsetX = CGFloat(data.originOffsetX ?? 0)
        newMap.originOffsetZ = CGFloat(data.originOffsetZ ?? 0)
        gameMap = newMap
    }

    /// Promijeni veličinu mape (nova igra).
    func setMapSize(_ preset: MapSizePreset) {
        gameMap = preset.makeGameMap()
    }
}

// MARK: - Placement
extension GameState {
    /// Postavi trenutno odabrani objekt na (row, col). Vraća true ako je uspjelo. U igri (ne Map Editor) troši resurse prema BuildCosts.
    func placeSelectedObjectAt(row: Int, col: Int, playSound: Bool = true) -> Bool {
        placementError = nil
        placementDebugLog("GameState.placeSelectedObjectAt row=\(row) col=\(col) selected=\(selectedPlacementObjectId ?? "nil")")
        guard let objectId = selectedPlacementObjectId else {
            let msg = "Nije odabran objekt za postavljanje. Prvo odaberi Zid (Dvor → Zid)."
            placementError = msg
            placementDebugLog("FAIL no selected object")
            return false
        }
        if !isMapEditorMode, WallParent.isWall(objectId: objectId), !WallBuildConditions.wallBuildConditionsMet(gameState: self, objectId: objectId, cells: [(row, col)]) {
            placementDebugLog("FAIL wall build conditions not met row=\(row) col=\(col)")
            return false
        }
        if !isMapEditorMode {
            let cost = BuildCosts.shared.cost(for: objectId)
            if !resources.canAfford(objectId: objectId) {
                placementError = "Nedovoljno resursa. Potrebno: \(cost.stone) kamen, \(cost.wood) drvo, \(cost.iron) željezo."
                placementDebugLog("FAIL insufficient resources object=\(objectId) have(s=\(resources.stone),w=\(resources.wood),i=\(resources.iron)) need(s=\(cost.stone),w=\(cost.wood),i=\(cost.iron))")
                return false
            }
        }
        let obj = ObjectCatalog.shared.object(id: objectId)
        let width = obj?.size.width ?? 1
        let height = obj?.size.height ?? 1
        placementDebugLog("object=\(objectId) size=\(width)x\(height)")
        guard let _ = gameMap.place(objectId: objectId, width: width, height: height, atRow: row, col: col) else {
            let msg = "Ne može se staviti na (\(row), \(col)) – ćelija zauzeta ili izvan mape \(gameMap.displayDimensionString)."
            placementError = msg
            placementDebugLog("FAIL map.place returned nil object=\(objectId) row=\(row) col=\(col)")
            return false
        }
        if !isMapEditorMode {
            let cost = BuildCosts.shared.cost(for: objectId)
            resources.subtract(cost)
        }
        placementsVersion += 1
        objectWillChange.send()
        if playSound && playPlacementSound {
            AudioManager.shared.playSound(named: "place", volume: audioSoundsVolume)
        }
        placementDebugLog("SUCCESS object=\(objectId) row=\(row) col=\(col)")
        return true
    }

    /// Ukloni placement koji pokriva danu koordinatu (Map Editor – alat za brisanje).
    func removePlacement(at coordinate: MapCoordinate) {
        guard let p = gameMap.placement(at: coordinate) else { return }
        gameMap.removePlacement(id: p.id)
        placementsVersion += 1
        objectWillChange.send()
    }
}

// MARK: - Map Editor
/// Slot za spremanje/učitavanje mape u Map Editoru (solo, dual, …).
enum MapEditorSlot: String, CaseIterable, Identifiable {
    case solo
    case dual
    case trio
    case quatro
    case five
    case six

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .solo: return "Solo"
        case .dual: return "Dual"
        case .trio: return "Trio"
        case .quatro: return "Quatro"
        case .five: return "5"
        case .six: return "6"
        }
    }

    var fileName: String { "map_editor_\(rawValue).json" }
}

extension GameState {
    /// Kreira mapu na pozadinskom threadu (igra ne zastaje), sprema je u Maps/side×side/ i otvori Map Editor. Na main thread pozove completion(success).
    /// Map Editor se prikazuje samo kad mapa postoji; pričekaj da se sve učita (isLevelReady) prije uređivanja.
    func createMapAndOpenEditor(name: String, side: Int, completion: @escaping (Bool) -> Void) {
        MapGenerator.createAndSaveMapAsync(name: name, side: side, slot: .solo) { [weak self] newMap in
            guard let self = self, let newMap = newMap else { completion(false); return }
            self.gameMap = newMap
            self.mapEditorCurrentSlot = .solo
            self.mapEditorMapName = name.trimmingCharacters(in: .whitespacesAndNewlines)
            self.mapEditorCreatedDate = Date()
            self.mapEditorState = MapEditorState()
            self.bindMapEditorStateChanges()
            self.mapEditorSceneVersion += 1
            self.selectedPlacementObjectId = nil
            self.isShowingMainMenu = false
            self.isMapEditorMode = true
            self.isLevelReady = false
            self.levelLoadingMessage = "Kreiranje i učitavanje mape (\(newMap.displayDimensionString))…"
            self.objectWillChange.send()
            completion(true)
        }
    }

    /// Otvori Map Editor s postojećom mapom zadane veličine (npr. nakon učitavanja). Ne kreira novu datoteku.
    func openMapEditor(withPreset preset: MapSizePreset) {
        setMapSize(preset)
        mapEditorCurrentSlot = .solo
        mapEditorState = MapEditorState()
        bindMapEditorStateChanges()
        selectedPlacementObjectId = nil
        isShowingMainMenu = false
        isMapEditorMode = true
        isLevelReady = false
        levelLoadingMessage = "Učitavanje mape (\(gameMap.displayDimensionString))…"
        _ = saveEditorMap(toSlot: .solo)
    }

    /// Otvori Map Editor nakon učitavanja mape (mapa je već postavljena). Generira editor-only stanje i veže na mapu.
    func openMapEditorAfterLoad() {
        mapEditorState = MapEditorState()
        bindMapEditorStateChanges()
        selectedPlacementObjectId = nil
        isShowingMainMenu = false
        isMapEditorMode = true
        isLevelReady = false
        levelLoadingMessage = "Učitavanje mape (\(gameMap.displayDimensionString))…"
    }

    /// Zatvori Map Editor i vrati se na izbornik. Očisti editor-only stanje.
    func closeMapEditor() {
        mapEditorStateCancellable?.cancel()
        mapEditorStateCancellable = nil
        mapEditorState?.clear()
        mapEditorState = nil
        isMapEditorMode = false
        isShowingMainMenu = true
    }

    /// Spremi trenutnu mapu u slot (Maps/200x200/, …) preko MapFileManager. Sprema samo unutar projekta. Vraća (uspjeh, poruka greške za prikaz).
    func saveEditorMap(toSlot slot: MapEditorSlot? = nil) -> (success: Bool, errorMessage: String?) {
        let targetSlot = slot ?? mapEditorCurrentSlot ?? .solo
        let name = mapEditorMapName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return (false, "Unesite naziv mape.") }
        MapStorage.createSizeFoldersIfNeeded()
        guard MapStorage.isMapsRootInProject() else {
            FeudalismLog.log("Save map: ODBIJENO – mape se moraju spremati u projekt. Trenutni Maps root=\(MapStorage.mapsRootPath()). Postavite Working Directory = $(PROJECT_DIR).")
            return (false, "Mape se moraju spremati unutar projekta. Postavite Xcode → Edit Scheme → Run → Options → Working Directory = $(PROJECT_DIR).")
        }
        let fileName = MapStorage.fileName(forMapName: name, slotFallback: targetSlot)
        let vertexHeightsDouble = gameMap.vertexHeights.isEmpty ? nil : Dictionary(uniqueKeysWithValues: gameMap.vertexHeights.map { ($0.key, Double($0.value)) })
        let data = MapEditorSaveData(mapName: name, rows: gameMap.rows, cols: gameMap.cols, placements: gameMap.placements, cells: gameMap.cells, createdDate: mapEditorCreatedDate ?? Date(), originOffsetX: Double(gameMap.originOffsetX), originOffsetZ: Double(gameMap.originOffsetZ), vertexHeights: vertexHeightsDouble)
        guard let fileURL = MapStorage.fileURL(rows: gameMap.rows, cols: gameMap.cols, fileName: fileName) else {
            let side = gameMap.rows * MapScale.smallCellsPerObjectCubeSide
            return (false, "Nije moguće odrediti putanju za spremanje. Veličina mape \(gameMap.displayDimensionString) možda nije dopuštena (200, 400, 600, 800, 1000). Putanja: \(MapStorage.mapsRootPath())")
        }
        let (saved, saveError) = MapFileManager.save(data: data, to: fileURL)
        FeudalismLog.log("Save map: success=\(saved), error=\(saveError ?? "—"), path=\(fileURL.path), mapsInProject=\(MapStorage.isMapsRootInProject())")
        guard saved else { return (false, saveError ?? "Spremanje nije uspjelo.") }
        if let rel = MapStorage.relativePath(rows: gameMap.rows, cols: gameMap.cols, fileName: fileName) {
            let category = MapSizeCategory.from(rows: gameMap.rows, cols: gameMap.cols)
            let entry = MapCatalogEntry(
                path: rel,
                rows: gameMap.rows,
                cols: gameMap.cols,
                slot: targetSlot.rawValue,
                displayName: name,
                sizeCategory: category.rawValue,
                suggestedPlayers: targetSlot.defaultSuggestedPlayers,
                tags: targetSlot.defaultTags
            )
            MapCatalog.addOrUpdate(entry: entry)
        }
        return (true, nil)
    }

    /// Učitaj mapu iz kataloškog unosa preko MapFileManager. Vraća true ako je uspjelo.
    func loadEditorMap(entry: MapCatalogEntry) -> Bool {
        guard let root = MapStorage.mapsRoot() else { return false }
        let fileURL = root.appendingPathComponent(entry.path)
        guard let data = MapFileManager.load(from: fileURL) else { return false }
        applyLoadedMapData(data)
        mapEditorCurrentSlot = MapEditorSlot(rawValue: entry.slot) ?? .solo
        mapEditorMapName = data.mapName
        mapEditorCreatedDate = data.createdDate
        mapEditorSceneVersion += 1
        objectWillChange.send()
        return true
    }

    /// Učitaj mapu iz danog slota i veličine: prvo iz kataloga (prvi unos za slot i dimenzije), inače legacy datoteka slot.fileName.
    func loadEditorMap(fromSlot slot: MapEditorSlot, rows: Int, cols: Int) -> Bool {
        let fromCatalog = MapCatalog.entries(forSlot: slot).first { $0.rows == rows && $0.cols == cols }
        if let entry = fromCatalog { return loadEditorMap(entry: entry) }
        guard let fileURL = MapStorage.fileURL(rows: rows, cols: cols, fileName: slot.fileName) else { return false }
        guard let data = MapFileManager.load(from: fileURL) else { return false }
        applyLoadedMapData(data)
        mapEditorCurrentSlot = slot
        mapEditorMapName = data.mapName
        mapEditorCreatedDate = data.createdDate
        mapEditorSceneVersion += 1
        objectWillChange.send()
        return true
    }

    /// Primijeni učitane podatke na gameMap (koristi Map Editor nakon load).
    private func applyLoadedMapData(_ data: MapEditorSaveData) {
        let newMap = GameMap(rows: data.rows, cols: data.cols)
        newMap.replacePlacements(data.placements)
        if let cells = data.cells { newMap.replaceCells(cells) }
        if let vh = data.vertexHeights { newMap.replaceVertexHeights(Dictionary(uniqueKeysWithValues: vh.map { ($0.key, CGFloat($0.value)) })) }
        newMap.originOffsetX = CGFloat(data.originOffsetX ?? 0)
        newMap.originOffsetZ = CGFloat(data.originOffsetZ ?? 0)
        gameMap = newMap
    }

    /// Učitaj prvu dostupnu mapu za dani slot (bilo koja veličina iz kataloga). Vraća true ako je uspjelo.
    func loadEditorMap(fromSlot slot: MapEditorSlot) -> Bool {
        guard let first = MapCatalog.entries(forSlot: slot).first else { return false }
        return loadEditorMap(entry: first)
    }

    /// Postoji li barem jedna spremljena mapa za dani slot (bilo koja veličina)?
    func hasEditorMap(inSlot slot: MapEditorSlot) -> Bool {
        MapCatalog.hasAnyMap(forSlot: slot)
    }

    /// Map Editor: obriši datoteku mape i unos iz kataloga. Vraća true ako je unos uklonjen iz kataloga.
    func deleteEditorMap(entry: MapCatalogEntry) -> Bool {
        if let root = MapStorage.mapsRoot() {
            let fileURL = root.appendingPathComponent(entry.path)
            try? FileManager.default.removeItem(at: fileURL)
        }
        MapCatalog.remove(path: entry.path)
        objectWillChange.send()
        return true
    }

    /// Map Editor: preimenuj mapu (nova datoteka, brisanje stare, ažuriranje kataloga). Vraća (uspjeh, poruka greške).
    func renameEditorMap(entry: MapCatalogEntry, newName: String) -> (success: Bool, errorMessage: String?) {
        let name = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return (false, "Unesite naziv mape.") }
        guard let root = MapStorage.mapsRoot() else { return (false, "Mape nisu dostupne.") }
        let fileURL = root.appendingPathComponent(entry.path)
        guard let data = MapFileManager.load(from: fileURL) else { return (false, "Učitavanje mape nije uspjelo.") }
        let slot = MapEditorSlot(rawValue: entry.slot) ?? .solo
        let fileName = MapStorage.fileName(forMapName: name, slotFallback: slot)
        guard let newURL = MapStorage.fileURL(rows: data.rows, cols: data.cols, fileName: fileName) else {
            return (false, "Neispravna veličina mape.")
        }
        let newData = MapEditorSaveData(mapName: name, rows: data.rows, cols: data.cols, placements: data.placements, cells: data.cells, createdDate: data.createdDate, originOffsetX: data.originOffsetX, originOffsetZ: data.originOffsetZ, vertexHeights: data.vertexHeights)
        let (saved, saveError) = MapFileManager.save(data: newData, to: newURL)
        guard saved else { return (false, saveError ?? "Spremanje nije uspjelo.") }
        if let rel = MapStorage.relativePath(rows: data.rows, cols: data.cols, fileName: fileName) {
            let category = MapSizeCategory.from(rows: data.rows, cols: data.cols)
            let newEntry = MapCatalogEntry(path: rel, rows: data.rows, cols: data.cols, slot: entry.slot, displayName: name, sizeCategory: category.rawValue, suggestedPlayers: entry.suggestedPlayers, tags: entry.tags)
            MapCatalog.addOrUpdate(entry: newEntry)
        }
        try? FileManager.default.removeItem(at: fileURL)
        MapCatalog.remove(path: entry.path)
        objectWillChange.send()
        return (true, nil)
    }

    /// Map Editor: obriši sve objekte s mape.
    func clearEditorMap() {
        gameMap.replacePlacements([])
        objectWillChange.send()
    }
}

// MARK: - Terrain elevation (Map Editor – alat Teren)
enum TerrainToolOption: String, CaseIterable {
    case raise5 = "Podigni za 5"
    case raise10 = "Podigni za 10"
    case lower5 = "Spusti za 5"
    case lower10 = "Spusti za 10"
    case flatten = "Izravnaj"
}

/// Četkica terena: samo kockice, 4 veličine (1×1, 3×3, 6×6, 12×12). Stranica = 2*radius+1.
enum TerrainBrushOption: String, CaseIterable {
    case size1   // 1×1 – jedna ćelija
    case size3   // 3×3
    case size6   // 6×6 (zapravo 7×7: radius 3)
    case size12  // 12×12 (zapravo 13×13: radius 6)

    /// Polumjer četkice (stranica = 2*radius+1).
    var radius: Int {
        switch self {
        case .size1: return 0   // 1×1
        case .size3: return 1   // 3×3
        case .size6: return 3   // 7×7 (najbliže 6×6)
        case .size12: return 6  // 13×13 (najbliže 12×12)
        }
    }

    /// Uvijek kvadrat (samo kockice, nema krugova).
    var isSquare: Bool { true }

    /// Oznaka za UI (1×1, 3×3, 6×6, 12×12).
    var displayLabel: String {
        switch self {
        case .size1: return "1×1"
        case .size3: return "3×3"
        case .size6: return "6×6"
        case .size12: return "12×12"
        }
    }
}

extension GameState {
    /// Primijeni alat za teren na ćelije oko (centerRow, centerCol). Kocke 10×10 mjere elevaciju.
    func applyTerrainElevation(centerRow: Int, centerCol: Int, tool: TerrainToolOption, brushOption: TerrainBrushOption) {
        let r = brushOption.radius
        var cellsToUpdate: [(Int, Int)] = []
        for dr in -r...r {
            for dc in -r...r {
                let row = centerRow + dr
                let col = centerCol + dc
                guard gameMap.isValid(MapCoordinate(row: row, col: col)) else { continue }
                if brushOption.isSquare { /* kvadrat – sve ćelije u bounding boxu */ } else {
                    if dr * dr + dc * dc > r * r { continue }
                }
                cellsToUpdate.append((row, col))
            }
        }
        let step = MapScale.worldUnitsPerElevationStep
        let centerHeight = gameMap.height(at: MapCoordinate(row: centerRow, col: centerCol))
        for (row, col) in cellsToUpdate {
            let coord = MapCoordinate(row: row, col: col)
            let current = gameMap.height(at: coord)
            let newHeight: CGFloat
            switch tool {
            case .raise5: newHeight = current + 5 * step   // 5 prostornih kockica (10×10)
            case .raise10: newHeight = current + 10 * step // 10 prostornih kockica
            case .lower5: newHeight = current - 5 * step
            case .lower10: newHeight = current - 10 * step
            case .flatten: newHeight = centerHeight
            }
            gameMap.setHeight(at: coord, newHeight)
        }
        objectWillChange.send()
    }

    /// Primijeni alat za teren samo na označene ćelije (Map Editor – mod „Odabir ćelija”).
    func applyTerrainElevationToSelectedCells(tool: TerrainToolOption) {
        guard let editorState = mapEditorState, !editorState.selectedCells.isEmpty else { return }
        let coords = Array(editorState.selectedCells)
        let centerCoord = coords.first!
        let centerHeight = gameMap.height(at: centerCoord)
        let step = MapScale.worldUnitsPerElevationStep
        for coord in coords {
            guard gameMap.isValid(coord) else { continue }
            let current = gameMap.height(at: coord)
            let newHeight: CGFloat
            switch tool {
            case .raise5: newHeight = current + 5 * step
            case .raise10: newHeight = current + 10 * step
            case .lower5: newHeight = current - 5 * step
            case .lower10: newHeight = current - 10 * step
            case .flatten: newHeight = centerHeight
            }
            gameMap.setHeight(at: coord, newHeight)
        }
        objectWillChange.send()
    }

    /// Postavi visinu svih označenih ćelija na zadanu vrijednost.
    func setHeightForSelectedCells(_ height: CGFloat) {
        guard let editorState = mapEditorState else { return }
        for coord in editorState.selectedCells {
            guard gameMap.isValid(coord) else { continue }
            gameMap.setHeight(at: coord, height)
        }
        objectWillChange.send()
    }

    /// Primijeni alat za teren samo na jedan vrh (točku sjecišta). Map Editor – odabrana kugla.
    func applyVertexElevation(vertexRow: Int, vertexCol: Int, tool: TerrainToolOption) {
        guard gameMap.isValidVertex(vertexRow: vertexRow, vertexCol: vertexCol) else { return }
        let step = MapScale.worldUnitsPerElevationStep
        let current = gameMap.vertexHeightAt(vertexRow: vertexRow, vertexCol: vertexCol)
        let newHeight: CGFloat
        switch tool {
        case .raise5: newHeight = current + 5 * step
        case .raise10: newHeight = current + 10 * step
        case .lower5: newHeight = current - 5 * step
        case .lower10: newHeight = current - 10 * step
        case .flatten: newHeight = current
        }
        gameMap.setVertexHeight(vertexRow: vertexRow, vertexCol: vertexCol, newHeight)
        objectWillChange.send()
    }

    /// Dodaj u odabir sve ćelije u obliku četkice (kockica 1×1, 3×3, 6×6 ili 12×12).
    func addBrushRegionToSelection(centerRow: Int, centerCol: Int, brushOption: TerrainBrushOption) {
        guard let editorState = mapEditorState else { return }
        let r = brushOption.radius
        for dr in -r...r {
            for dc in -r...r {
                let row = centerRow + dr
                let col = centerCol + dc
                guard gameMap.isValid(MapCoordinate(row: row, col: col)) else { continue }
                if !brushOption.isSquare, dr * dr + dc * dc > r * r { continue }
                editorState.selectedCells.insert(MapCoordinate(row: row, col: col))
            }
        }
        editorState.objectWillChange.send()
        objectWillChange.send()
    }
}

// MARK: - Settings (UserDefaults keys)
private extension GameState {
    static let inputDeviceKey = "Feudalism.inputDevice"
    static let appLanguageKey = "Feudalism.appLanguage"
    static let playerProfileNameKey = "Feudalism.playerProfileName"
    static let playerEmblemIdKey = "Feudalism.playerEmblemId"
    static let showStartupAnimationKey = "Feudalism.showStartupAnimation"
    static let showBottomBarLabelsKey = "Feudalism.showBottomBarLabels"
    static let playPlacementSoundKey = "Feudalism.playPlacementSound"
    static let playBarTransitionSoundKey = "Feudalism.playBarTransitionSound"
    static let audioMusicVolumeKey = "Feudalism.audioMusicVolume"
    static let audioSoundsVolumeKey = "Feudalism.audioSoundsVolume"
    static let audioSpeechVolumeKey = "Feudalism.audioSpeechVolume"
}
