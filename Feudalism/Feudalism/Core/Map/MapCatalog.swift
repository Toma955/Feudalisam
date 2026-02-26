//
//  MapCatalog.swift
//  Feudalism
//
//  Katalog spremljenih mapa za pretragu: mala/velika mapa, 1v1, 1v6, itd.
//
//  Primjer pretrage:
//    MapCatalog.search(sizeCategory: .small)                    // male mape (200–400)
//    MapCatalog.search(sizeCategory: .large)                    // velike mape (800–1000)
//    MapCatalog.search(suggestedPlayers: "1v6")                 // mape za 1 vs 6
//    MapCatalog.search(tagsContaining: "1v1")                  // duel / 1v1
//    MapCatalog.search(sizeCategory: .small, suggestedPlayers: "6")  // mala za 6 igrača
//

import Foundation

/// Kategorija veličine mape za filtriranje (mala / srednja / velika).
enum MapSizeCategory: String, Codable, CaseIterable, Identifiable {
    case small = "small"
    case medium = "medium"
    case large = "large"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .small: return "Mala"
        case .medium: return "Srednja"
        case .large: return "Velika"
        }
    }

    /// Kategorija po veličini: side 200,400→small, 600→medium, 800,1000→large.
    static func from(rows: Int, cols: Int) -> MapSizeCategory {
        let side: Int
        if rows == cols, MapDimension.allSides.contains(rows) { side = rows }
        else { side = max(rows, cols) * MapScale.smallCellsPerObjectCubeSide }
        if side <= 400 { return .small }
        if side <= 600 { return .medium }
        return .large
    }
}

/// Jedan unos u katalogu – jedna spremljena mapa.
struct MapCatalogEntry: Codable, Identifiable {
    /// Relativna staza, npr. "200x200/map_editor_solo.json".
    var path: String
    var rows: Int
    var cols: Int
    /// Slot (solo, dual, …).
    var slot: String
    /// Prikazno ime, npr. "Solo 200×200".
    var displayName: String
    /// Kategorija veličine za pretragu.
    var sizeCategory: String
    /// Preporučeni broj igrača, npr. "1-2", "2-6", "1-6".
    var suggestedPlayers: String
    /// Opcionalni tagovi za pretragu (npr. "1v1", "1v6", "duel").
    var tags: [String]

    var id: String { path }

    init(path: String, rows: Int, cols: Int, slot: String, displayName: String, sizeCategory: String, suggestedPlayers: String, tags: [String] = []) {
        self.path = path
        self.rows = rows
        self.cols = cols
        self.slot = slot
        self.displayName = displayName
        self.sizeCategory = sizeCategory
        self.suggestedPlayers = suggestedPlayers
        self.tags = tags
    }

    /// Side za folder i sortiranje: 200×200 ćelija → 200 (folder 200x200).
    var side: Int {
        (rows == cols && MapDimension.allSides.contains(rows)) ? rows : (rows * MapScale.smallCellsPerObjectCubeSide)
    }

    /// Odgovara li unos pretrazi (suggestedPlayers, tagovi, displayName).
    func matchesSearch(_ query: String) -> Bool {
        let q = query.lowercased()
        if suggestedPlayers.lowercased().contains(q) { return true }
        if displayName.lowercased().contains(q) { return true }
        if tags.contains(where: { $0.lowercased().contains(q) }) { return true }
        return false
    }
}

/// Cijeli katalog – lista unosa; sprema se u map_catalog.json u Maps/.
struct MapCatalogFile: Codable {
    var maps: [MapCatalogEntry]
    var updatedAt: Date?

    init(maps: [MapCatalogEntry] = [], updatedAt: Date? = nil) {
        self.maps = maps
        self.updatedAt = updatedAt
    }
}

enum MapCatalog {
    private static let catalogFileName = "map_catalog.json"

    static func catalogURL() -> URL? {
        MapStorage.mapsRoot().map { $0.appendingPathComponent(catalogFileName) }
    }

    static func load() -> MapCatalogFile {
        guard let url = catalogURL(),
              FileManager.default.fileExists(atPath: url.path),
              let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode(MapCatalogFile.self, from: data) else {
            return MapCatalogFile()
        }
        return decoded
    }

    static func save(_ catalog: MapCatalogFile) {
        guard let url = catalogURL() else { return }
        var updated = catalog
        updated.updatedAt = Date()
        guard let data = try? JSONEncoder().encode(updated) else { return }
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? data.write(to: url)
    }

    /// Dodaj ili ažuriraj unos (po path); ostale unose zadrži.
    static func addOrUpdate(entry: MapCatalogEntry) {
        var cat = load()
        cat.maps.removeAll { $0.path == entry.path }
        cat.maps.append(entry)
        save(cat)
    }

    /// Ukloni unos iz kataloga po path.
    static func remove(path: String) {
        var cat = load()
        cat.maps.removeAll { $0.path == path }
        save(cat)
    }

    // MARK: - Pretraga

    /// Filtriraj mape: po kategoriji veličine, broju igrača ili tagovima. Rezultat sortiran po dimenziji (200, 400, 600, 800, 1000).
    static func search(
        sizeCategory: MapSizeCategory? = nil,
        suggestedPlayers: String? = nil,
        slot: MapEditorSlot? = nil,
        tagsContaining: String? = nil
    ) -> [MapCatalogEntry] {
        let cat = load()
        return cat.maps
            .filter { entry in
                if let catFilter = sizeCategory, entry.sizeCategory != catFilter.rawValue { return false }
                if let players = suggestedPlayers, !entry.matchesSearch(players) { return false }
                if let s = slot, entry.slot != s.rawValue { return false }
                if let tag = tagsContaining, !entry.matchesSearch(tag) { return false }
                return true
            }
            .sorted { $0.side < $1.side }
    }

    /// Svi unosi za dani slot, sortirani po dimenziji (200x200, 400x400, 600x600, 800x800, 1000x1000).
    static func entries(forSlot slot: MapEditorSlot) -> [MapCatalogEntry] {
        load().maps
            .filter { $0.slot == slot.rawValue }
            .sorted { $0.side < $1.side }
    }

    /// Svi unosi za danu veličinu (side = 200, 400, 600, 800, 1000) – mape iz foldera 200x200/, 400x400/, itd. Sortirano po path.
    static func entries(forSide side: Int) -> [MapCatalogEntry] {
        load().maps
            .filter { $0.side == side }
            .sorted { ($0.displayName, $0.path) < ($1.displayName, $1.path) }
    }

    /// Svi unosi u katalogu, sortirani po veličini pa po nazivu.
    static func allEntries() -> [MapCatalogEntry] {
        load().maps
            .sorted { $0.side < $1.side || ($0.side == $1.side && ($0.displayName, $0.path) < ($1.displayName, $1.path)) }
    }

    /// Ima li barem jedna mapa za dani slot (bilo koja veličina)?
    static func hasAnyMap(forSlot slot: MapEditorSlot) -> Bool {
        !entries(forSlot: slot).isEmpty
    }

    /// Jedan unos po relativnoj stazi.
    static func entry(path: String) -> MapCatalogEntry? {
        load().maps.first { $0.path == path }
    }
}

// MARK: - Predloženi broj igrača i tagovi iz slota
extension MapEditorSlot {
    /// Preporučeni raspon igrača za slot (za katalog).
    var defaultSuggestedPlayers: String {
        switch self {
        case .solo: return "1-2"
        case .dual: return "2"
        case .trio: return "3"
        case .quatro: return "4"
        case .five: return "5"
        case .six: return "6"
        }
    }

    /// Tagovi za pretragu (npr. "1v6").
    var defaultTags: [String] {
        switch self {
        case .solo: return ["solo", "1v1"]
        case .dual: return ["dual", "1v1", "2"]
        case .trio: return ["trio", "3"]
        case .quatro: return ["quatro", "4"]
        case .five: return ["5"]
        case .six: return ["6", "1v6"]
        }
    }
}
