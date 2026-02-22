//
//  GameMap.swift
//  Feudalism
//
//  Mapa mape – cijela karta u 1×1 jedinicama (npr. 100×100, 200×200, 1000×1000).
//  Svaka ćelija = 1×1; objekti (npr. kuća 4×4) su Placement-i koji zauzimaju više ćelija.
//

import Foundation

/// Cijela mapa igre – grid 1×1 ćelija + lista postavljenih objekata (Placement).
final class GameMap: ObservableObject {
    /// Broj redaka (visina u 1×1 jedinicama).
    let rows: Int
    /// Broj stupaca (širina u 1×1 jedinicama).
    let cols: Int

    /// Ćelije: key = MapCoordinate.cellId, value = MapCell (samo teren).
    @Published private(set) var cells: [String: MapCell] = [:]
    /// Postavljeni objekti – svaki zauzima width×height ćelija od (row, col).
    @Published private(set) var placements: [Placement] = []

    init(rows: Int, cols: Int) {
        self.rows = rows
        self.cols = cols
        self.cells = Self.makeGrid(rows: rows, cols: cols)
    }

    private static func makeGrid(rows: Int, cols: Int) -> [String: MapCell] {
        var result: [String: MapCell] = [:]
        for r in 0..<rows {
            for c in 0..<cols {
                let coord = MapCoordinate(row: r, col: c)
                result[coord.cellId] = MapCell(coordinate: coord)
            }
        }
        return result
    }

    /// Ćelija na koordinati (ako postoji).
    func cell(at coordinate: MapCoordinate) -> MapCell? {
        cells[coordinate.cellId]
    }

    /// Ćelija na (row, col).
    func cell(row: Int, col: Int) -> MapCell? {
        cell(at: MapCoordinate(row: row, col: col))
    }

    /// Je li koordinata unutar mape?
    func isValid(_ coordinate: MapCoordinate) -> Bool {
        coordinate.row >= 0 && coordinate.row < rows && coordinate.col >= 0 && coordinate.col < cols
    }

    /// Postavi teren na ćeliji.
    func setTerrain(at coordinate: MapCoordinate, _ terrain: TerrainType) {
        guard isValid(coordinate), var cell = cells[coordinate.cellId] else { return }
        cell.terrain = terrain
        cells[coordinate.cellId] = cell
    }

    // MARK: - Placement (objekti koji zauzimaju 1×1 do N×M ćelija)

    /// Placement koji pokriva danu koordinatu (ili nil ako je prazno).
    func placement(at coordinate: MapCoordinate) -> Placement? {
        placements.first { $0.contains(coordinate) }
    }

    /// Može li se na (row, col) postaviti objekt veličine width×height? (unutar mape + nema preklapanja.)
    func canPlace(width: Int, height: Int, atRow row: Int, col: Int) -> Bool {
        let w = max(1, width)
        let h = max(1, height)
        guard row >= 0, col >= 0, row + h <= rows, col + w <= cols else { return false }
        for r in row..<(row + h) {
            for c in col..<(col + w) {
                let coord = MapCoordinate(row: r, col: c)
                if placement(at: coord) != nil { return false }
            }
        }
        return true
    }

    /// Postavi objekt (objectId iz kataloga) veličine width×height na (row, col). Vraća placement ili nil ako nije moguće.
    @discardableResult
    func place(objectId: String, width: Int, height: Int, atRow row: Int, col: Int) -> Placement? {
        guard canPlace(width: width, height: height, atRow: row, col: col) else { return nil }
        let p = Placement(objectId: objectId, row: row, col: col, width: width, height: height)
        objectWillChange.send()
        placements.append(p)
        return p
    }

    /// Ukloni placement po id.
    func removePlacement(id: String) {
        placements.removeAll { $0.id == id }
        objectWillChange.send()
    }

    /// Zamijeni sve placements (npr. pri učitavanju mape u Map Editoru).
    func replacePlacements(_ newPlacements: [Placement]) {
        placements = newPlacements
        objectWillChange.send()
    }

    /// Sve koordinate (redoslijed po redovima).
    func allCoordinates() -> [MapCoordinate] {
        (0..<rows).flatMap { r in (0..<cols).map { c in MapCoordinate(row: r, col: c) } }
    }
}

// MARK: - Map Editor – spremanje / učitavanje mape
struct MapEditorSaveData: Codable {
    let rows: Int
    let cols: Int
    let placements: [Placement]
}
