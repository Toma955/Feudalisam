//
//  BuildCosts.swift
//  Feudalism
//
//  Resursi potrebni za izgradnju objekata – kamen, drvo, željezo. Jedan izvor istine za sve objekte.
//

import Foundation

/// Trošak izgradnje jednog objekta (resursi).
struct BuildCost: Equatable {
    var stone: Int
    var wood: Int
    var iron: Int

    static let zero = BuildCost(stone: 0, wood: 0, iron: 0)

    func canAfford(stone: Int, wood: Int, iron: Int) -> Bool {
        stone >= self.stone && wood >= self.wood && iron >= self.iron
    }
}

/// Konfiguracija troškova izgradnje po objectId. Map Editor ne troši resurse.
final class BuildCosts {
    static let shared = BuildCosts()

    private var costs: [String: BuildCost] = [:]

    private init() {
        registerDefaults()
    }

    private func registerDefaults() {
        // Zid: 1 kamen za izgradnju
        set(Wall.objectId, cost: BuildCost(stone: 1, wood: 0, iron: 0))
        // Stepenice: 1 kamen
        set(Steps.objectId, cost: BuildCost(stone: 1, wood: 0, iron: 0))
        // Tržnica: 2 kamena, 1 drvo
        set(Market.objectId, cost: BuildCost(stone: 2, wood: 1, iron: 0))
        // Farma: 1 drvo, 0 kamen/željezo
        set(Farm.objectId, cost: BuildCost(stone: 0, wood: 1, iron: 0))
        // Kokošinjac: 0 kamen, 2 drva
        set(Chicken.objectId, cost: BuildCost(stone: 0, wood: 2, iron: 0))
        // Kukuruz: 0 kamen, 2 drva
        set(Corn.objectId, cost: BuildCost(stone: 0, wood: 2, iron: 0))
        // Kuća: 2 kamena, 2 drva
        set(House.objectId, cost: BuildCost(stone: 2, wood: 2, iron: 0))
        // Zdenac: 2 kamena, 1 drvo
        set(Well.objectId, cost: BuildCost(stone: 2, wood: 1, iron: 0))
        // Hotel: 3 kamena, 2 drva
        set(Hotel.objectId, cost: BuildCost(stone: 3, wood: 2, iron: 0))
        // Industrija: 2 kamena, 1 drvo, 1 željezo
        set(Industry.objectId, cost: BuildCost(stone: 2, wood: 1, iron: 1))
        // Željezara: 2 kamena, 2 drva, 1 željezo
        set(Iron.objectId, cost: BuildCost(stone: 2, wood: 2, iron: 1))
        // Kamenolom: 3 kamena, 1 drvo
        set(Stone.objectId, cost: BuildCost(stone: 3, wood: 1, iron: 0))
        // Dvorac: 10 kamena, 5 drva, 2 željeza
        set(Castle.objectId, cost: BuildCost(stone: 10, wood: 5, iron: 2))
        // Hrana: 0 kamen, 2 drva
        set(Food.objectId, cost: BuildCost(stone: 0, wood: 2, iron: 0))
        // Mlin: 1 kamen, 3 drva
        set(Windmill.objectId, cost: BuildCost(stone: 1, wood: 3, iron: 0))
        // Pekara: 1 kamen, 2 drva
        set(Bakery.objectId, cost: BuildCost(stone: 1, wood: 2, iron: 0))
        // Smočnica: 1 kamen, 2 drva
        set(Granary.objectId, cost: BuildCost(stone: 1, wood: 2, iron: 0))
    }

    /// Postavi trošak za objekt.
    func set(_ objectId: String, cost: BuildCost) {
        costs[objectId] = cost
    }

    /// Trošak za objekt; nil = besplatno (npr. u Map Editoru se ne gleda).
    func cost(for objectId: String) -> BuildCost {
        costs[objectId] ?? .zero
    }

    /// Može li igrač priuštiti izgradnju (solo igra; u Map Editoru uvijek true).
    func canAfford(objectId: String, stone: Int, wood: Int, iron: Int) -> Bool {
        cost(for: objectId).canAfford(stone: stone, wood: wood, iron: iron)
    }
}
