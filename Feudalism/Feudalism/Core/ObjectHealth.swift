//
//  ObjectHealth.swift
//  Feudalism
//
//  Život (HP) objekata – broj levela × HP po levelu. Jedan izvor istine za sve objekte.
//

import Foundation

/// Konfiguracija zdravlja objekta: npr. 10 levela × 10 HP = 100 max HP.
struct ObjectHealthConfig: Equatable {
    /// Broj "levela" (npr. 10).
    var levels: Int
    /// HP po levelu (npr. 10).
    var hpPerLevel: Int

    var maxHealth: Int { levels * hpPerLevel }
}

/// Konfiguracija zdravlja po objectId.
final class ObjectHealth {
    static let shared = ObjectHealth()

    private var configs: [String: ObjectHealthConfig] = [:]

    private init() {
        registerDefaults()
    }

    private func registerDefaults() {
        // Zid: 10 levela × 10 HP = 100 max HP
        set(HugeWall.objectId, config: ObjectHealthConfig(levels: 10, hpPerLevel: 10))
        // Mali zid: 6 levela × 6 HP = 36 max HP (6/10)
        set(SmallWall.objectId, config: ObjectHealthConfig(levels: 6, hpPerLevel: 6))
        // Tržnica: 5×10 = 50 HP
        set(Market.objectId, config: ObjectHealthConfig(levels: 5, hpPerLevel: 10))
        // Farma: 5×8 = 40 HP
        set(Farm.objectId, config: ObjectHealthConfig(levels: 5, hpPerLevel: 8))
        // Kokošinjac: 4×8 = 32 HP
        set(Chicken.objectId, config: ObjectHealthConfig(levels: 4, hpPerLevel: 8))
        // Kukuruz: 4×8 = 32 HP
        set(Corn.objectId, config: ObjectHealthConfig(levels: 4, hpPerLevel: 8))
        // Kuća: 6×10 = 60 HP
        set(House.objectId, config: ObjectHealthConfig(levels: 6, hpPerLevel: 10))
        // Zdenac: 4×8 = 32 HP
        set(Well.objectId, config: ObjectHealthConfig(levels: 4, hpPerLevel: 8))
        // Hotel: 5×10 = 50 HP
        set(Hotel.objectId, config: ObjectHealthConfig(levels: 5, hpPerLevel: 10))
        // Industrija: 6×10 = 60 HP
        set(Industry.objectId, config: ObjectHealthConfig(levels: 6, hpPerLevel: 10))
        // Željezara: 5×10 = 50 HP
        set(Iron.objectId, config: ObjectHealthConfig(levels: 5, hpPerLevel: 10))
        // Kamenolom: 5×10 = 50 HP
        set(Stone.objectId, config: ObjectHealthConfig(levels: 5, hpPerLevel: 10))
        // Dvorac: 15×10 = 150 HP
        set(Castle.objectId, config: ObjectHealthConfig(levels: 15, hpPerLevel: 10))
        // Hrana: 4×8 = 32 HP
        set(Food.objectId, config: ObjectHealthConfig(levels: 4, hpPerLevel: 8))
        // Mlin: 5×10 = 50 HP
        set(Windmill.objectId, config: ObjectHealthConfig(levels: 5, hpPerLevel: 10))
        // Pekara: 4×8 = 32 HP
        set(Bakery.objectId, config: ObjectHealthConfig(levels: 4, hpPerLevel: 8))
        // Smočnica: 4×8 = 32 HP
        set(Granary.objectId, config: ObjectHealthConfig(levels: 4, hpPerLevel: 8))
    }

    /// Postavi konfiguraciju zdravlja za objekt.
    func set(_ objectId: String, config: ObjectHealthConfig) {
        configs[objectId] = config
    }

    /// Konfiguracija za objekt; nil = nema definirano (npr. 0 ili fallback 100).
    func config(for objectId: String) -> ObjectHealthConfig? {
        configs[objectId]
    }

    /// Maksimalni život za objekt. Ako nije definiran, vraća 100.
    func maxHealth(for objectId: String) -> Int {
        config(for: objectId)?.maxHealth ?? 100
    }
}
