//
//  MapSizePreset.swift
//  Feudalism
//
//  Preseti veličine mape – sve u 1×1 jedinicama (100×100, 200×200, 1000×1000).
//

import Foundation

/// Unaprijed definirane veličine mape. Mapa je uvijek u 1×1 jedinicama.
enum MapSizePreset: String, CaseIterable, Identifiable {
    case small = "100×100"
    case medium = "200×200"
    case large = "1000×1000"

    var id: String { rawValue }

    var rows: Int {
        switch self {
        case .small: return 100
        case .medium: return 200
        case .large: return 1000
        }
    }

    var cols: Int {
        switch self {
        case .small: return 100
        case .medium: return 200
        case .large: return 1000
        }
    }

    /// Kreira novu GameMap ove veličine.
    func makeGameMap() -> GameMap {
        GameMap(rows: rows, cols: cols)
    }
}
