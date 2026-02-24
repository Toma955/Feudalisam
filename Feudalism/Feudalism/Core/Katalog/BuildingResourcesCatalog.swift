//
//  BuildingResourcesCatalog.swift
//  Feudalism
//
//  Katalog: popis resursa potrebnih za izgradnju svakog objekta (kamen, drvo, željezo).
//  Jedan izvor istine – BuildCosts.shared učitava podatke odavde.
//

import Foundation

/// Trošak izgradnje (resursi) – zrcali BuildCost radi kataloga.
struct BuildingResourcesEntry: Equatable {
    var stone: Int
    var wood: Int
    var iron: Int

    static let zero = BuildingResourcesEntry(stone: 0, wood: 0, iron: 0)
}

/// Katalog resursa potrebnih za izgradnju (Building_resources).
enum BuildingResourcesCatalog {
    /// Svi troškovi po objectId. BuildCosts.shared poziva register() pri inicijalizaciji.
    static func register(into buildCosts: BuildCosts) {
        // Zidovi
        buildCosts.set(HugeWall.objectId, cost: BuildCost(stone: 0, wood: 0, iron: 0))
        buildCosts.set(SmallWall.objectId, cost: BuildCost(stone: 0, wood: 1, iron: 0))
        buildCosts.set(Steps.objectId, cost: BuildCost(stone: 1, wood: 0, iron: 0))
        // Dvor, tržnica, kuće
        buildCosts.set(Market.objectId, cost: BuildCost(stone: 2, wood: 1, iron: 0))
        buildCosts.set(Castle.objectId, cost: BuildCost(stone: 10, wood: 5, iron: 2))
        buildCosts.set(Well.objectId, cost: BuildCost(stone: 2, wood: 1, iron: 0))
        buildCosts.set(House.objectId, cost: BuildCost(stone: 2, wood: 2, iron: 0))
        buildCosts.set(Hotel.objectId, cost: BuildCost(stone: 3, wood: 2, iron: 0))
        // Farme
        buildCosts.set(Farm.objectId, cost: BuildCost(stone: 0, wood: 1, iron: 0))
        buildCosts.set(Chicken.objectId, cost: BuildCost(stone: 0, wood: 2, iron: 0))
        buildCosts.set(Corn.objectId, cost: BuildCost(stone: 0, wood: 2, iron: 0))
        // Hrana
        buildCosts.set(Food.objectId, cost: BuildCost(stone: 0, wood: 2, iron: 0))
        buildCosts.set(Windmill.objectId, cost: BuildCost(stone: 1, wood: 3, iron: 0))
        buildCosts.set(Bakery.objectId, cost: BuildCost(stone: 1, wood: 2, iron: 0))
        buildCosts.set(Granary.objectId, cost: BuildCost(stone: 1, wood: 2, iron: 0))
        // Industrija
        buildCosts.set(Industry.objectId, cost: BuildCost(stone: 2, wood: 1, iron: 1))
        buildCosts.set(Iron.objectId, cost: BuildCost(stone: 2, wood: 2, iron: 1))
        buildCosts.set(Stone.objectId, cost: BuildCost(stone: 3, wood: 1, iron: 0))
    }
}
