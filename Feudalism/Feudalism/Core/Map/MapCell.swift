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
struct MapCell: Identifiable, Codable {
    var id: String { coordinate.cellId }
    let coordinate: MapCoordinate
    var terrain: TerrainType

    init(coordinate: MapCoordinate, terrain: TerrainType = .grass) {
        self.coordinate = coordinate
        self.terrain = terrain
    }
}
