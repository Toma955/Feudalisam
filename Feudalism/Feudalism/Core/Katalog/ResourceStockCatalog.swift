//
//  ResourceStockCatalog.swift
//  Feudalism
//
//  Katalog: popis svih resursa (kamen, drvo, željezo) i model stanja – koliko čega imamo.
//

import Foundation

/// Tip resursa u igri (Building_resources).
enum ResourceType: String, CaseIterable, Codable {
    case stone = "stone"
    case wood = "wood"
    case iron = "iron"

    var displayNameKey: String {
        switch self {
        case .stone: return "resource_stone"
        case .wood: return "resource_wood"
        case .iron: return "resource_iron"
        }
    }
}

/// Stanje zaliha – koliko imamo od svakog resursa (jedan izvor za UI i gameplay).
struct ResourceStock: Equatable {
    var stone: Int
    var wood: Int
    var iron: Int

    static let zero = ResourceStock(stone: 0, wood: 0, iron: 0)

    subscript(_ type: ResourceType) -> Int {
        get {
            switch type {
            case .stone: return stone
            case .wood: return wood
            case .iron: return iron
            }
        }
        set {
            switch type {
            case .stone: stone = newValue
            case .wood: wood = newValue
            case .iron: iron = newValue
            }
        }
    }

    /// Možemo li priuštiti zadani trošak?
    func canAfford(cost: BuildCost) -> Bool {
        stone >= cost.stone && wood >= cost.wood && iron >= cost.iron
    }

    /// Oduzmi trošak od zaliha (pozivati samo ako canAfford).
    mutating func subtract(_ cost: BuildCost) {
        stone -= cost.stone
        wood -= cost.wood
        iron -= cost.iron
    }
}
