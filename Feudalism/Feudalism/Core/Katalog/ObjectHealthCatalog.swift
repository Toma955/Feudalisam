//
//  ObjectHealthCatalog.swift
//  Feudalism
//
//  Katalog: opis koliko tko ima health (HP) – levels × hpPerLevel po objectId.
//  ObjectHealth.shared učitava podatke odavde.
//

import Foundation

/// Katalog zdravlja (HP) po objectId. ObjectHealth.shared poziva register() pri inicijalizaciji.
enum ObjectHealthCatalog {
    static func register(into objectHealth: ObjectHealth) {
        // Zidovi
        objectHealth.set(HugeWall.objectId, config: ObjectHealthConfig(levels: 10, hpPerLevel: 10))
        objectHealth.set(SmallWall.objectId, config: ObjectHealthConfig(levels: 6, hpPerLevel: 6))
        // Dvor, tržnica, kuće
        objectHealth.set(Market.objectId, config: ObjectHealthConfig(levels: 5, hpPerLevel: 10))
        objectHealth.set(Castle.objectId, config: ObjectHealthConfig(levels: 15, hpPerLevel: 10))
        objectHealth.set(Well.objectId, config: ObjectHealthConfig(levels: 4, hpPerLevel: 8))
        objectHealth.set(House.objectId, config: ObjectHealthConfig(levels: 6, hpPerLevel: 10))
        objectHealth.set(Hotel.objectId, config: ObjectHealthConfig(levels: 5, hpPerLevel: 10))
        // Farme
        objectHealth.set(Farm.objectId, config: ObjectHealthConfig(levels: 5, hpPerLevel: 8))
        objectHealth.set(Chicken.objectId, config: ObjectHealthConfig(levels: 4, hpPerLevel: 8))
        objectHealth.set(Corn.objectId, config: ObjectHealthConfig(levels: 4, hpPerLevel: 8))
        // Hrana
        objectHealth.set(Food.objectId, config: ObjectHealthConfig(levels: 4, hpPerLevel: 8))
        objectHealth.set(Windmill.objectId, config: ObjectHealthConfig(levels: 5, hpPerLevel: 10))
        objectHealth.set(Bakery.objectId, config: ObjectHealthConfig(levels: 4, hpPerLevel: 8))
        objectHealth.set(Granary.objectId, config: ObjectHealthConfig(levels: 4, hpPerLevel: 8))
        // Industrija
        objectHealth.set(Industry.objectId, config: ObjectHealthConfig(levels: 6, hpPerLevel: 10))
        objectHealth.set(Iron.objectId, config: ObjectHealthConfig(levels: 5, hpPerLevel: 10))
        objectHealth.set(Stone.objectId, config: ObjectHealthConfig(levels: 5, hpPerLevel: 10))
    }
}
