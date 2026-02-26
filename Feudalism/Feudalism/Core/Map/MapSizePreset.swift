//
//  MapSizePreset.swift
//  Feudalism
//
//  Preseti veličine mape – mapiraju na MapDimension (Core/Enums/MapDimensions.swift).
//

import Foundation

/// Unaprijed definirane veličine mape za UI. Dimenzije su u MapDimension.
enum MapSizePreset: String, CaseIterable, Identifiable {
    case size200 = "200×200"
    case size400 = "400×400"
    case size600 = "600×600"
    case size800 = "800×800"
    case size1000 = "1000×1000"

    var id: String { rawValue }

    /// Odgovarajuća dimenzija (izvor: Core/Enums/MapDimensions).
    var dimension: MapDimension {
        switch self {
        case .size200: return .size200
        case .size400: return .size400
        case .size600: return .size600
        case .size800: return .size800
        case .size1000: return .size1000
        }
    }

    /// Stranica mape (200–1000).
    var side: Int { dimension.side }

    var rows: Int { MapCreationRules.rows(forPresetSide: side) }
    var cols: Int { MapCreationRules.cols(forPresetSide: side) }

    /// Kreira novu GameMap prema pravilima.
    func makeGameMap() -> GameMap {
        MapCreationRules.makeGameMap(presetSide: side)
    }
}
