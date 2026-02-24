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
        ObjectHealthCatalog.register(into: self)
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
