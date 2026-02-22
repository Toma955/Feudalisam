//
//  MapCoordinate.swift
//  Feudalism
//
//  Koordinata na mapi – red i stupac (grid).
//

import Foundation

/// Pozicija jedne ćelije na mapi (red, stupac).
struct MapCoordinate: Hashable, Codable, Sendable {
    let row: Int
    let col: Int

    init(row: Int, col: Int) {
        self.row = row
        self.col = col
    }

    /// Jedinstveni string id (npr. "12_7").
    var cellId: String { "\(row)_\(col)" }

    /// Susjedi (4 smjera: gore, dolje, lijevo, desno). Kasnije + dijagonale ako treba.
    func neighbors() -> [MapCoordinate] {
        [
            MapCoordinate(row: row - 1, col: col),
            MapCoordinate(row: row + 1, col: col),
            MapCoordinate(row: row, col: col - 1),
            MapCoordinate(row: row, col: col + 1)
        ]
    }
}
