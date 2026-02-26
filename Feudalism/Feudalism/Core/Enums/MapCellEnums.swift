//
//  MapCellEnums.swift
//  Feudalism
//
//  Što ćelija sadrži (Core/Map/MapCell.swift):
//  - id, x/y, textureId (jedna tekstura), objectIds (više objekata: žbunje, stabla, voda)
//  - terrain, height (elevacija; može u minus), resource
//  - walkable, buildable, canAfforest (pošumljavanje), canDigChannels (kupanje kanala) – sve Bool.
//

import Foundation

/// Tip terena na jednom polju mape. Sprema se u datoteku mape; određuje izgled i prohodnost.
enum TerrainType: String, Codable, CaseIterable {
    case grass = "Trava"
    case water = "Voda"
    case forest = "Šuma"
    case mountain = "Planina"

    /// Je li teren prohodan u igri (runtime).
    var defaultWalkable: Bool {
        switch self {
        case .water: return false
        case .grass, .forest, .mountain: return true
        }
    }

    /// Može li se na terenu graditi (runtime).
    var defaultBuildable: Bool {
        switch self {
        case .water: return false
        case .grass, .forest, .mountain: return true
        }
    }
}
