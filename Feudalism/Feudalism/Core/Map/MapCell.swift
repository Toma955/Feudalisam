//
//  MapCell.swift
//  Feudalism
//
//  Jedna ćelija mape = 1×1 prostorna jedinica. Samo teren; zauzetost se računa iz Placement-a.
//

import Foundation

/// Tip terena (opcionalno – za kasnije različite boje / resurse).
enum TerrainType: String, Codable, CaseIterable {
    case grass = "Trava"
    case water = "Voda"
    case forest = "Šuma"
    case mountain = "Planina"
}

/// Jedna ćelija mape (1×1). Samo teren; koji objekt je na njoj određuje GameMap iz placements.
/// `height` = elevacija (jedinice visine) za teren – 10×10 mreža mjeri elevaciju.
struct MapCell: Identifiable, Codable {
    var id: String { coordinate.cellId }
    let coordinate: MapCoordinate
    var terrain: TerrainType
    /// Elevacija ćelije (0 = ravnina; za podizanje/spuštanje terena).
    var height: CGFloat = 0

    init(coordinate: MapCoordinate, terrain: TerrainType = .grass, height: CGFloat = 0) {
        self.coordinate = coordinate
        self.terrain = terrain
        self.height = height
    }

    enum CodingKeys: String, CodingKey {
        case coordinate, terrain, height
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        coordinate = try c.decode(MapCoordinate.self, forKey: .coordinate)
        terrain = try c.decode(TerrainType.self, forKey: .terrain)
        let h = try c.decodeIfPresent(Double.self, forKey: .height) ?? 0
        height = CGFloat(h)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(coordinate, forKey: .coordinate)
        try c.encode(terrain, forKey: .terrain)
        try c.encode(Double(height), forKey: .height)
    }
}
