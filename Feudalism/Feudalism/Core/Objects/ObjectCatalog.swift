//
//  ObjectCatalog.swift
//  Feudalism
//
//  Katalog svih objekata po kategorijama – jedan izvor istine za Spremišta, Resursi, … Ostali.
//

import Foundation

/// Centralni katalog objekata: po kategorijama (Spremišta, Resursi, Hrana, Farme, Vojska, Religija, Dvorac, Vojnici, Radnici, Ostali).
final class ObjectCatalog {
    static let shared = ObjectCatalog()

    /// Svi objekti grupirani po kategoriji.
    private(set) var objectsByCategory: [ObjectCategory: [GameObject]] = [:]

    private init() {
        reloadDefaults()
    }

    /// Učitaj zadane objekte u sve kategorije. Kasnije može učitati iz datoteke / servera.
    func reloadDefaults() {
        objectsByCategory = Dictionary(uniqueKeysWithValues: ObjectCategory.allCases.map { category in
            (category, ObjectCategory.defaultObjects(for: category))
        })
    }

    /// Objekti za jednu kategoriju.
    func objects(in category: ObjectCategory) -> [GameObject] {
        objectsByCategory[category] ?? []
    }

    /// Dohvati objekt po id-u (npr. za prikaz displayCode na karti).
    func object(id: String) -> GameObject? {
        for category in ObjectCategory.allCases {
            if let obj = objectsByCategory[category]?.first(where: { $0.id == id }) {
                return obj
            }
        }
        return nil
    }

    /// Dodaj novi objekt u kategoriju (npr. iz editora).
    func add(_ object: GameObject) {
        objectsByCategory[object.category, default: []].append(object)
    }

    /// Obriši objekt po id-u.
    func remove(id: String) {
        for category in ObjectCategory.allCases {
            objectsByCategory[category]?.removeAll { $0.id == id }
        }
    }
}
