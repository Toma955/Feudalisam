//
//  GameMap.swift
//  Feudalism
//
//  Mapa igre: grid ćelija za gradnju (40×40 svaka). Minimalna prostorna jedinica je 10×10;
//  side u minimalnim jedinicama = rows * 4 kad je mapa kvadratna (npr. 50×50 ćelija → 200×200).
//

import Foundation
import CoreGraphics

/// Cijela mapa igre – grid ćelija za gradnju (40×40) + lista postavljenih objekata (Placement).
final class GameMap: ObservableObject {
    /// Broj redaka (ćelija za gradnju 40×40).
    let rows: Int
    /// Broj stupaca (ćelija za gradnju 40×40).
    let cols: Int

    /// Pomak ishodišta X (0.0 točka) u world jedinicama – za fino podešavanje lokacije mape.
    var originOffsetX: CGFloat = 0
    /// Pomak ishodišta Z (0.0 točka) u world jedinicama – za fino podešavanje lokacije mape.
    var originOffsetZ: CGFloat = 0

    /// Side za prikaz i folder: za preset (200,400,…) vraća rows, inače rows*4 (legacy).
    var sideInSmallUnits: Int? {
        guard rows == cols else { return nil }
        return MapDimension.allSides.contains(rows) ? rows : (rows * MapScale.smallCellsPerObjectCubeSide)
    }

    /// Korisnički prikaz dimenzije: "200×200" (side). Kad je mapa prazna (0×0), vraća "—×—".
    var displayDimensionString: String {
        guard rows > 0, cols > 0 else { return "—×—" }
        if let side = sideInSmallUnits { return "\(side)×\(side)" }
        return "\(rows)×\(cols)"
    }

    /// Ćelije: key = MapCoordinate.cellId, value = MapCell (samo teren).
    @Published private(set) var cells: [String: MapCell] = [:]
    /// Postavljeni objekti – svaki zauzima width×height ćelija od (row, col).
    @Published private(set) var placements: [Placement] = []

    init(rows: Int, cols: Int) {
        self.rows = rows
        self.cols = cols
        self.cells = Self.makeGrid(rows: rows, cols: cols)
        self.vertexHeights = Self.makeInitialVertexHeights(rows: rows, cols: cols)
    }

    /// Inicijalizator s unaprijed pripremljenim podacima (za kreiranje na pozadinskom threadu – glavna nit ne blokira).
    init(rows: Int, cols: Int, cells: [String: MapCell], vertexHeights: [String: CGFloat]) {
        self.rows = rows
        self.cols = cols
        self.cells = cells
        self.vertexHeights = vertexHeights
    }

    /// Svaka ćelija ima 4 točke (vrha); ne može se kreirati ćelija bez tih točaka. Inicijalizira sve vrhove mreže s elevacijom 0.
    /// Poziva se na pozadinskom threadu pri kreiranju mape.
    static func makeInitialVertexHeights(rows: Int, cols: Int) -> [String: CGFloat] {
        var h: [String: CGFloat] = [:]
        for r in 0...rows {
            for c in 0...cols {
                h["\(r)_\(c)"] = 0
            }
        }
        return h
    }

    /// Pri generiranju mape sve ćelije su G (zemlja / ground), prohodnost normalno.
    /// Poziva se na pozadinskom threadu pri kreiranju mape.
    static func makeGrid(rows: Int, cols: Int) -> [String: MapCell] {
        var result: [String: MapCell] = [:]
        for r in 0..<rows {
            for c in 0..<cols {
                let coord = MapCoordinate(row: r, col: c)
                result[coord.cellId] = MapCell(coordinate: coord, povrsina: .zemlja, prohodnost: .normalno)
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

    /// Postavi teren na ćeliji (runtime). Walkable i buildable se postavljaju prema terrain.
    func setTerrain(at coordinate: MapCoordinate, _ terrain: TerrainType) {
        guard isValid(coordinate), var cell = cells[coordinate.cellId] else { return }
        cell.terrain = terrain
        cell.walkable = terrain.defaultWalkable
        cell.buildable = terrain.defaultBuildable
        cells[coordinate.cellId] = cell
        objectWillChange.send()
    }

    /// Postavi walkable na ćeliji (runtime; npr. u editoru).
    func setWalkable(at coordinate: MapCoordinate, _ value: Bool) {
        guard isValid(coordinate), var cell = cells[coordinate.cellId] else { return }
        cell.walkable = value
        cells[coordinate.cellId] = cell
        objectWillChange.send()
    }

    /// Postavi elevaciju na ćeliji (Map Editor – alat za teren).
    func setHeight(at coordinate: MapCoordinate, _ value: CGFloat) {
        guard isValid(coordinate), var cell = cells[coordinate.cellId] else { return }
        cell.height = value
        cells[coordinate.cellId] = cell
        objectWillChange.send()
    }

    /// Vrati elevaciju na ćeliji (0 ako ne postoji).
    func height(at coordinate: MapCoordinate) -> CGFloat {
        cell(at: coordinate)?.height ?? 0
    }

    // MARK: - Vertex visine (sjecišta mreže – jedna točka = jedan vrh)
    /// Visine na vrhovima mreže (key "row_col", row in 0...rows, col in 0...cols). Kad prazno, teren koristi visine ćelija.
    @Published private(set) var vertexHeights: [String: CGFloat] = [:]

    /// Je li (vertexRow, vertexCol) valjana točka sjecišta? vertexRow in 0...rows, vertexCol in 0...cols.
    func isValidVertex(vertexRow: Int, vertexCol: Int) -> Bool {
        vertexRow >= 0 && vertexRow <= rows && vertexCol >= 0 && vertexCol <= cols
    }

    /// Visina na vrhu (sjecištu) – ako je spremljena u vertexHeights, inače prosjek ćelija koje dijele taj kut.
    func vertexHeightAt(vertexRow: Int, vertexCol: Int) -> CGFloat {
        let key = "\(vertexRow)_\(vertexCol)"
        if let h = vertexHeights[key] { return h }
        var sum: CGFloat = 0
        var n = 0
        for dr in 0...1 {
            for dc in 0...1 {
                let r = vertexRow - 1 + dr
                let c = vertexCol - 1 + dc
                if r >= 0, r < rows, c >= 0, c < cols {
                    sum += height(at: MapCoordinate(row: r, col: c))
                    n += 1
                }
            }
        }
        return n > 0 ? sum / CGFloat(n) : 0
    }

    /// Postavi visinu samo na tom vrhu (sjecištu). Map Editor – alat za točku.
    func setVertexHeight(vertexRow: Int, vertexCol: Int, _ value: CGFloat) {
        guard isValidVertex(vertexRow: vertexRow, vertexCol: vertexCol) else { return }
        vertexHeights["\(vertexRow)_\(vertexCol)"] = value
        objectWillChange.send()
    }

    /// Zamijeni sve vertex visine (npr. pri učitavanju mape).
    func replaceVertexHeights(_ newHeights: [String: CGFloat]) {
        vertexHeights = newHeights
        objectWillChange.send()
    }

    /// Zamijeni sve ćelije (npr. pri učitavanju mape u Map Editoru).
    func replaceCells(_ newCells: [String: MapCell]) {
        cells = newCells
        objectWillChange.send()
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
// Fizička datoteka mora sadržavati:
// - mapName, dimensions (rows, cols)
// - originOffsetX, originOffsetZ (0.0 točka + fino podešavanje lokacije)
// - Runtime (u igri) po tileu: id (izveden iz row,col), row/col, height/elevation, terrainType, walkable
// - placements (objekti na mapi)
// Editor-only (selected, hovered, brushPreview, tempHeightDelta, paintMask, debugFlags, undo/redo) se NE spremaju
//   – generiraju se pri uključivanju editor moda i vežu na mapu.

struct MapEditorSaveData: Codable {
    enum CodingKeys: String, CodingKey { case mapName, rows, cols, placements, cells, createdDate, originOffsetX, originOffsetZ, vertexHeights }
    /// Ime mape (obavezno pri spremanju).
    let mapName: String
    let rows: Int
    let cols: Int
    let placements: [Placement]
    /// Runtime podaci po ćeliji: id = coordinate.cellId, coordinate (row,col), height, terrain, walkable.
    let cells: [String: MapCell]?
    /// Datum izgradnje/kreiranja mape (postavlja se pri prvom spremanju).
    let createdDate: Date?
    /// Pomak ishodišta X (0.0 točka) – za fino podešavanje lokacije. Nil = 0 (stare mape).
    let originOffsetX: Double?
    /// Pomak ishodišta Z (0.0 točka) – za fino podešavanje lokacije. Nil = 0 (stare mape).
    let originOffsetZ: Double?
    /// Visine na vrhovima mreže (sjecišta) – key "row_col". Nil = prazno (teren iz ćelija).
    let vertexHeights: [String: Double]?

    init(mapName: String, rows: Int, cols: Int, placements: [Placement], cells: [String: MapCell]? = nil, createdDate: Date? = nil, originOffsetX: Double? = 0, originOffsetZ: Double? = 0, vertexHeights: [String: Double]? = nil) {
        self.mapName = mapName
        self.rows = rows
        self.cols = cols
        self.placements = placements
        self.cells = cells
        self.createdDate = createdDate
        self.originOffsetX = originOffsetX
        self.originOffsetZ = originOffsetZ
        self.vertexHeights = vertexHeights
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        mapName = try c.decodeIfPresent(String.self, forKey: .mapName) ?? ""
        rows = try c.decode(Int.self, forKey: .rows)
        cols = try c.decode(Int.self, forKey: .cols)
        placements = try c.decode([Placement].self, forKey: .placements)
        cells = try c.decodeIfPresent([String: MapCell].self, forKey: .cells)
        createdDate = try c.decodeIfPresent(Date.self, forKey: .createdDate)
        originOffsetX = try c.decodeIfPresent(Double.self, forKey: .originOffsetX)
        originOffsetZ = try c.decodeIfPresent(Double.self, forKey: .originOffsetZ)
        vertexHeights = try c.decodeIfPresent([String: Double].self, forKey: .vertexHeights)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(mapName, forKey: .mapName)
        try c.encode(rows, forKey: .rows)
        try c.encode(cols, forKey: .cols)
        try c.encode(placements, forKey: .placements)
        try c.encodeIfPresent(cells, forKey: .cells)
        try c.encodeIfPresent(createdDate, forKey: .createdDate)
        try c.encodeIfPresent(originOffsetX, forKey: .originOffsetX)
        try c.encodeIfPresent(originOffsetZ, forKey: .originOffsetZ)
        try c.encodeIfPresent(vertexHeights, forKey: .vertexHeights)
    }
}
