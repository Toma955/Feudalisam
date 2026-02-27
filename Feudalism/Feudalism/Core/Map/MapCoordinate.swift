//
//  MapCoordinate.swift
//  Feudalism
//
//  Koordinata na mapi – red i stupac (grid). Pojedinačna točka (vrh) ćelije.
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

// MARK: - Pojedinačna točka (vrh) ćelije

/// Jedna točka (vrh) kocke/ćelije – ima vlastitu koordinatu u gridu (Double za točan položaj kuta).
/// Ćelija ima generalnu koordinatu (row, col) i 4 točke: kutevi kvadrata.
struct MapCellPoint: Hashable, Codable, Sendable {
    /// Red u gridu (Double – npr. 0, 1 za kuteve ćelije).
    let row: Double
    /// Stupac u gridu (Double).
    let col: Double
    /// Indeks točke unutar ćelije (0 = gornji lijevi, 1 = gornji desni, 2 = donji lijevi, 3 = donji desni).
    let index: Int

    init(row: Double, col: Double, index: Int = 0) {
        self.row = row
        self.col = col
        self.index = index
    }

    /// Jedinstveni id točke (npr. "12.0_7.0_0").
    var pointId: String { "\(row)_\(col)_\(index)" }
}
