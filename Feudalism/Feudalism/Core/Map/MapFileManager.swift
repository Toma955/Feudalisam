//
//  MapFileManager.swift
//  Feudalism
//
//  Jedan odgovoran modul (OOP): kreira file mape, upisuje u njega sadržaj, nudi učitavanje.
//  Map Editor koristi ovaj manager za save/load; ne radi encode/write sam.
//

import Foundation

/// Kreira file mape, upisuje sadržaj (MapEditorSaveData), učitava sadržaj. Map Editor ga koristi za save/load.
enum MapFileManager {

    // MARK: - Kreiranje i upis filea

    /// Stvori foldere po veličini ako treba, upiši sadržaj u file na dani URL. Vraća (uspjeh, poruka greške za korisnika).
    static func save(data: MapEditorSaveData, to fileURL: URL) -> (success: Bool, errorMessage: String?) {
        let parent = fileURL.deletingLastPathComponent()
        do {
            try FileManager.default.createDirectory(at: parent, withIntermediateDirectories: true)
        } catch {
            return (false, "Nije moguće stvoriti folder: \(error.localizedDescription)")
        }
        let encoded: Data
        do {
            encoded = try JSONEncoder().encode(data)
        } catch {
            return (false, "Pogreška pri pripremi podataka: \(error.localizedDescription)")
        }
        do {
            try encoded.write(to: fileURL)
            return (true, nil)
        } catch {
            return (false, "Pogreška pri pisanju datoteke: \(error.localizedDescription)")
        }
    }

    /// Kreira novu mapu (praznu), upiše je u file u Maps/sidexside/, ažurira katalog. Vraća GameMap ako uspije; inače nil.
    static func createMapFile(name: String, side: Int, slot: MapEditorSlot = .solo) -> GameMap? {
        guard MapScale.isValidMapSide(side) else { return nil }
        let nameTrimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !nameTrimmed.isEmpty else { return nil }

        let rows = MapCreationRules.rows(forPresetSide: side)
        let cols = MapCreationRules.cols(forPresetSide: side)
        let gameMap = GameMap(rows: rows, cols: cols)
        let fileName = MapStorage.fileName(forMapName: nameTrimmed, slotFallback: slot)
        let data = MapEditorSaveData(
            mapName: nameTrimmed,
            rows: rows,
            cols: cols,
            placements: [],
            cells: gameMap.cells,
            createdDate: Date(),
            originOffsetX: 0,
            originOffsetZ: 0
        )

        MapStorage.createSizeFoldersIfNeeded()
        guard let fileURL = MapStorage.fileURL(side: side, fileName: fileName) else { return nil }
        let (saved, _) = save(data: data, to: fileURL)
        guard saved else { return nil }

        if let rel = MapStorage.relativePath(side: side, fileName: fileName) {
            let category = MapSizeCategory.from(rows: rows, cols: cols)
            let entry = MapCatalogEntry(
                path: rel,
                rows: rows,
                cols: cols,
                slot: slot.rawValue,
                displayName: nameTrimmed,
                sizeCategory: category.rawValue,
                suggestedPlayers: slot.defaultSuggestedPlayers,
                tags: slot.defaultTags
            )
            MapCatalog.addOrUpdate(entry: entry)
        }

        return gameMap
    }

    // MARK: - Učitavanje (Map Editor učitava preko ovoga)

    /// Učita sadržaj mape s danog URL-a. Vraća nil ako file ne postoji ili decode ne uspije.
    static func load(from fileURL: URL) -> MapEditorSaveData? {
        guard FileManager.default.fileExists(atPath: fileURL.path),
              let raw = try? Data(contentsOf: fileURL),
              let data = try? JSONDecoder().decode(MapEditorSaveData.self, from: raw) else {
            return nil
        }
        return data
    }
}
