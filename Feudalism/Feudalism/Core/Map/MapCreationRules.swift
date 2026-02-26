//
//  MapCreationRules.swift
//  Feudalism
//
//  Pravila kreacije mape. Preset side = broj ćelija za gradnju po strani (200 → 200×200 ćelija).
//  Svaka ćelija = 40×40 world jedinica (MapScale.worldUnitsPerMapCell), ne 10×10.
//

import Foundation

/// Pravila kreacije mape – jedan izvor istine. Mape se grade od minimalnih jedinica 10×10.
enum MapCreationRules {
    // MARK: - Minimalna prostorna veličina
    /// Najmanja dozvoljena prostorna veličina za bilo koji element mape (npr. 1×2).
    static let minimumSpatialSize = SpatialSize(width: 1, height: 2)

    // MARK: - Glavna mapa (preseti) – side = broj ćelija za gradnju po strani (200 → 200×200)
    /// Dopuštene veličine glavne mape (kockasta: side×side ćelija).
    static var mainMapPresets: [(label: String, side: Int)] {
        MapDimension.allSides.map { ("\($0)×\($0)", $0) }
    }

    /// Broj redaka ćelija za gradnju za zadani preset. side 200 → 200.
    static func rows(forPresetSide side: Int) -> Int {
        side
    }

    /// Broj stupaca ćelija za gradnju za zadani preset. side 200 → 200.
    static func cols(forPresetSide side: Int) -> Int {
        side
    }

    /// Kreira GameMap prema preset stranici. 200 → 200×200 ćelija za gradnju.
    static func makeGameMap(presetSide side: Int) -> GameMap {
        GameMap(rows: rows(forPresetSide: side), cols: cols(forPresetSide: side))
    }

    // MARK: - Podzemna mapa
    /// Veličina podzemne mape u „kockama zida” – mapa ispod glavne. 1 kocka = veličina zida (jedna prostorna jedinica 40×40 u world).
    /// Podzemna mapa je 10 kockaka (u jedinicama zida).
    static let undergroundMapSizeInWallCubes: Int = 10

    /// Broj ćelija (1×1) za podzemnu mapu po strani: 10×10 (jedna kocka zida = 1 ćelija).
    static var undergroundMapSideInCells: Int { undergroundMapSizeInWallCubes }

    /// Kreira GameMap za podzemnu mapu (ispod glavne) – 10×10 ćelija (10 kockaka veličine zida).
    static func makeUndergroundGameMap() -> GameMap {
        let side = undergroundMapSideInCells
        return GameMap(rows: side, cols: side)
    }
}
