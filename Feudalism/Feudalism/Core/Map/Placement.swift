//
//  Placement.swift
//  Feudalism
//
//  Jedan postavljeni objekt na mapi – referenca na template (GameObject) + pozicija + veličina.
//  Objekt veličine 4×4 zauzima 16 ćelija (4 reda × 4 stupca) od točke (row, col).
//

import Foundation

/// Jedan postavljeni objekt na mapi: gornji-lijevi ugao (row, col) + veličina (width × height).
struct Placement: Identifiable, Codable, Sendable {
    /// Jedinstveni id instance (npr. za brisanje).
    let id: String
    /// Id objekta iz kataloga (GameObject.id).
    let objectId: String
    /// Red gornjeg-lijevog kuta (u 1×1 jedinicama).
    let row: Int
    /// Stupac gornjeg-lijevog kuta (u 1×1 jedinicama).
    let col: Int
    /// Širina u jedinicama (npr. 4 za kuću).
    let width: Int
    /// Visina u jedinicama (npr. 4 za kuću).
    let height: Int

    init(id: String? = nil, objectId: String, row: Int, col: Int, width: Int, height: Int) {
        self.id = id ?? UUID().uuidString
        self.objectId = objectId
        self.row = row
        self.col = col
        self.width = max(1, width)
        self.height = max(1, height)
    }

    /// Sve koordinate koje ovaj placement pokriva: [row..row+height) × [col..col+width).
    func coveredCoordinates() -> [MapCoordinate] {
        (row..<(row + height)).flatMap { r in
            (col..<(col + width)).map { c in MapCoordinate(row: r, col: c) }
        }
    }

    /// Sadrži li ovaj placement danu koordinatu?
    func contains(_ coordinate: MapCoordinate) -> Bool {
        coordinate.row >= row && coordinate.row < row + height &&
        coordinate.col >= col && coordinate.col < col + width
    }
}
