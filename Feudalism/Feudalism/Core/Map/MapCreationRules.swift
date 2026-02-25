//
//  MapCreationRules.swift
//  Feudalism
//
//  Zlatno pravilo za sve mape: roditeljska datoteka s pravilima koja se nasljeđuje pri kreaciji.
//  - Prostorna veličina: najmanje 1×2.
//  - Klik na 200 → automatski 200×200, klik na 400 → 400×400.
//  - Podzemna mapa: veličina 10 kockaka (veličina zida).
//

import Foundation

/// Pravila kreacije mape – jedan izvor istine za sve mape. Sva kreacija mape nasljeđuje ova pravila.
enum MapCreationRules {
    // MARK: - Minimalna prostorna veličina
    /// Najmanja dozvoljena prostorna veličina za bilo koji element mape (npr. 1×2).
    static let minimumSpatialSize = SpatialSize(width: 1, height: 2)

    // MARK: - Glavna mapa (preseti)
    /// Dopuštene veličine glavne mape: klik na 200 → 200×200, 400 → 400×400 itd.
    /// Svaki preset automatski kreira mapu rows×cols = side×side.
    static let mainMapPresets: [(label: String, side: Int)] = [
        ("200×200", 200),
        ("400×400", 400),
        ("800×800", 800),
        ("1000×1000", 1000),
    ]

    /// Vraća broj redaka za zadani preset (side×side).
    static func rows(forPresetSide side: Int) -> Int { side }

    /// Vraća broj stupaca za zadani preset (side×side).
    static func cols(forPresetSide side: Int) -> Int { side }

    /// Kreira GameMap prema preset stranici (200 → 200×200, 400 → 400×400).
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
