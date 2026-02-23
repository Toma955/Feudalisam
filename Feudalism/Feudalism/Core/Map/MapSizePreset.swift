//
//  MapSizePreset.swift
//  Feudalism
//
//  Preseti veličine mape – sve u 1×1 jedinicama (100×100, 200×200, 1000×1000).
//

import Foundation

/// Unaprijed definirane veličine mape. Mapa je uvijek u 1×1 jedinicama.
enum MapSizePreset: String, CaseIterable, Identifiable {
    case size200 = "200×200"
    case size400 = "400×400"
    case size800 = "800×800"
    case size1000 = "1000×1000"

    var id: String { rawValue }

    var rows: Int {
        switch self {
        case .size200: return 200
        case .size400: return 400
        case .size800: return 800
        case .size1000: return 1000
        }
    }

    var cols: Int {
        switch self {
        case .size200: return 200
        case .size400: return 400
        case .size800: return 800
        case .size1000: return 1000
        }
    }

    /// Kreira novu GameMap ove veličine.
    func makeGameMap() -> GameMap {
        GameMap(rows: rows, cols: cols)
    }
}
