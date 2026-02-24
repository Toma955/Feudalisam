//
//  FlammableCatalog.swift
//  Feudalism
//
//  Katalog: popis objekata koji se mogu zapaliti i koliko vatra oduzima HP (po ticku ili po sekundi).
//

import Foundation

/// Jedna stavka kataloga – objekt se može zapaliti, vatra oduzima N HP po jedinici vremena.
struct FlammableEntry: Equatable {
    /// objectId objekta koji gori (npr. zid, drvena kuća).
    let objectId: String
    /// Koliko HP vatra oduzima po ticku (npr. 1 = 1 HP/tick). Veća vrijednost = brže izgaranje.
    let fireDamagePerTick: Int
}

/// Katalog zapaljivih objekata i oštećenja od vatre.
final class FlammableCatalog {
    static let shared = FlammableCatalog()

    private var entries: [String: FlammableEntry] = [:]

    private init() {
        registerDefaults()
    }

    private func registerDefaults() {
        // Zidovi – mogu gorjeti, vatra oduzima 2 HP/tick
        set(FlammableEntry(objectId: HugeWall.objectId, fireDamagePerTick: 2))
        set(FlammableEntry(objectId: SmallWall.objectId, fireDamagePerTick: 2))
        // Drveni / lakši objekti – brže gore
        set(FlammableEntry(objectId: Farm.objectId, fireDamagePerTick: 3))
        set(FlammableEntry(objectId: Chicken.objectId, fireDamagePerTick: 3))
        set(FlammableEntry(objectId: Corn.objectId, fireDamagePerTick: 3))
        set(FlammableEntry(objectId: Windmill.objectId, fireDamagePerTick: 3))
        set(FlammableEntry(objectId: Bakery.objectId, fireDamagePerTick: 3))
        set(FlammableEntry(objectId: Granary.objectId, fireDamagePerTick: 3))
        set(FlammableEntry(objectId: Food.objectId, fireDamagePerTick: 3))
        // Kuće, tržnica, industrija – srednje
        set(FlammableEntry(objectId: House.objectId, fireDamagePerTick: 2))
        set(FlammableEntry(objectId: Hotel.objectId, fireDamagePerTick: 2))
        set(FlammableEntry(objectId: Market.objectId, fireDamagePerTick: 2))
        set(FlammableEntry(objectId: Well.objectId, fireDamagePerTick: 1))
        set(FlammableEntry(objectId: Industry.objectId, fireDamagePerTick: 2))
        set(FlammableEntry(objectId: Iron.objectId, fireDamagePerTick: 1))
        set(FlammableEntry(objectId: Stone.objectId, fireDamagePerTick: 1))
        // Dvorac – najsporije gori
        set(FlammableEntry(objectId: Castle.objectId, fireDamagePerTick: 1))
        // Stepenice – kamen, sporo
        set(FlammableEntry(objectId: Steps.objectId, fireDamagePerTick: 1))
    }

    func set(_ entry: FlammableEntry) {
        entries[entry.objectId] = entry
    }

    /// Je li objekt zapaljiv?
    func isFlammable(objectId: String) -> Bool {
        entries[objectId] != nil
    }

    /// Koliko HP vatra oduzima po ticku; 0 ako objekt ne gori.
    func fireDamagePerTick(objectId: String) -> Int {
        entries[objectId]?.fireDamagePerTick ?? 0
    }

    /// Svi zapaljivi objectId-evi.
    var flammableObjectIds: [String] {
        Array(entries.keys).sorted()
    }
}
