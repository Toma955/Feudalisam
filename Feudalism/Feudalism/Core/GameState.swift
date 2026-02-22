//
//  GameState.swift
//  Feudalism
//
//  Globalno stanje igre – krajevi (realmi), resursi, potezi. Jedan kralj = solo; više = dok zadnji ne ostane.
//

import Foundation
import SwiftUI

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

    /// Mapa mape – grid u 1×1 jedinicama (100×100, 200×200 ili 1000×1000).
    @Published var gameMap: GameMap

    init(mapSize: MapSizePreset = .small) {
        self.gameMap = mapSize.makeGameMap()
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

    /// Postavi trenutno odabrani objekt na (row, col). Vraća true ako je uspjelo.
    func placeSelectedObjectAt(row: Int, col: Int) -> Bool {
        guard let objectId = selectedPlacementObjectId else { return false }
        let obj = ObjectCatalog.shared.object(id: objectId)
        let width = obj?.size.width ?? 1
        let height = obj?.size.height ?? 1
        return gameMap.place(objectId: objectId, width: width, height: height, atRow: row, col: col) != nil
    }

    /// Ukloni placement koji pokriva danu koordinatu (Map Editor – alat za brisanje).
    func removePlacement(at coordinate: MapCoordinate) {
        guard let p = gameMap.placement(at: coordinate) else { return }
        gameMap.removePlacement(id: p.id)
        objectWillChange.send()
    }

    /// Otvori Map Editor – prazna mapa 100×100.
    func openMapEditor() {
        setMapSize(.small)
        selectedPlacementObjectId = nil
        isShowingMainMenu = false
        isMapEditorMode = true
        isLevelReady = false
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

    /// Pokreni novu igru – skriva izbornik, prikazuje karticu. Level se učitava u pozadini; isLevelReady postavlja GameScene.
    func startNewGame() {
        isLevelReady = false
        isShowingMainMenu = false
    }

    /// Dodaj sebe (human lord) i odabrane AI lordove, pa pokreni igru. Solo = samo ti, mapa 100×100.
    func startNewGameWithSetup(humanName: String, humanColorHex: String = "2E86AB", selectedAIProfileIds: [String]) {
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
        setMapSize(.small)
        startNewGame()
    }

    /// Promijeni veličinu mape (nova igra).
    func setMapSize(_ preset: MapSizePreset) {
        gameMap = preset.makeGameMap()
    }
}
