//
//  MapSizePreset.swift
//  Feudalism
//
//  Preseti veličine mape – nasljeđuju MapCreationRules. Klik na 200 → 200×200, 400 → 400×400.
//

import Foundation

/// Unaprijed definirane veličine mape. Kreacija nasljeđuje MapCreationRules (zlatno pravilo).
enum MapSizePreset: String, CaseIterable, Identifiable {
    case size200 = "200×200"
    case size400 = "400×400"
    case size800 = "800×800"
    case size1000 = "1000×1000"

    var id: String { rawValue }

    /// Stranica mape (200, 400, 800, 1000) – iz pravila.
    var side: Int {
        switch self {
        case .size200: return 200
        case .size400: return 400
        case .size800: return 800
        case .size1000: return 1000
        }
    }

    var rows: Int { MapCreationRules.rows(forPresetSide: side) }
    var cols: Int { MapCreationRules.cols(forPresetSide: side) }

    /// Kreira novu GameMap prema pravilima (200 → 200×200, 400 → 400×400).
    func makeGameMap() -> GameMap {
        MapCreationRules.makeGameMap(presetSide: side)
    }
}
