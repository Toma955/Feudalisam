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
        BuildingResourcesCatalog.register(into: self)
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
