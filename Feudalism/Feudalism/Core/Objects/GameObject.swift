//
//  GameObject.swift
//  Feudalism
//
//  Jedan objekt u igri – uvijek pripada jednoj kategoriji (ObjectCategory).
//  Prostorna veličina u jedinicama 1×1 (najmanja); npr. kuća = 4×4.
//

import Foundation

/// Zajednički protokol za sve objekte u igri.
protocol GameObjectProtocol: Identifiable, Equatable {
    var id: String { get }
    var name: String { get }
    var category: ObjectCategory { get }
    var size: SpatialSize { get }
    var displayCode: String { get }
    /// Ime 3D modela u bundleu (bez ekstenzije), npr. "Wall" za Wall.obj / Wall.usdz. Nil = bez 3D modela.
    var modelAssetName: String? { get }
}

/// Konkretni objekt – ima prostornu veličinu (1×1 = najmanja, kuća = 4×4, …).
struct GameObject: GameObjectProtocol {
    let id: String
    let name: String
    let category: ObjectCategory
    let size: SpatialSize
    let displayCode: String
    /// 3D model: ime datoteke bez ekstenzije (npr. "Wall" → Wall.obj ili Wall.usdz u bundleu).
    let modelAssetName: String?

    init(id: String? = nil, name: String, category: ObjectCategory, width: Int = 1, height: Int = 1, displayCode: String? = nil, modelAssetName: String? = nil) {
        self.id = id ?? UUID().uuidString
        self.name = name
        self.category = category
        self.size = SpatialSize(width: width, height: height)
        self.displayCode = displayCode ?? String(name.prefix(1)).uppercased()
        self.modelAssetName = modelAssetName
    }
}

// MARK: - Primjeri po kategorijama – veličine u 1×1 jedinicama (kuća = 4×4 basic)

extension ObjectCategory {

    /// Zadani objekti u ovoj kategoriji. Veličine: 1×1 minimalno, kuća 4×4, veće zgrade veće.
    static func defaultObjects(for category: ObjectCategory) -> [GameObject] {
        switch category {
        case .spremista:
            return [
                GameObject(name: "Skladište", category: .spremista, width: 3, height: 3),
                GameObject(name: "Silos", category: .spremista, width: 2, height: 2)
            ]
        case .resursi:
            return [
                GameObject(name: "Zlato", category: .resursi),
                GameObject(name: "Drvo", category: .resursi),
                GameObject(name: "Kamen", category: .resursi)
            ]
        case .hrana:
            return [
                Food.gameObject,
                Windmill.gameObject,
                Bakery.gameObject,
                Granary.gameObject,
                GameObject(name: "Pšenica", category: .hrana),
                GameObject(name: "Povrće", category: .hrana)
            ]
        case .farme:
            return [
                Farm.gameObject,
                Chicken.gameObject,
                Corn.gameObject,
                GameObject(name: "Farma", category: .farme, width: 4, height: 4),
                GameObject(name: "Polje", category: .farme, width: 2, height: 2)
            ]
        case .vojska:
            return [
                GameObject(name: "Baraka", category: .vojska, width: 4, height: 3),
                GameObject(name: "Zidine", category: .vojska, width: 1, height: 1)
            ]
        case .religija:
            return [
                GameObject(name: "Crkva", category: .religija, width: 5, height: 6),
                GameObject(name: "Samostan", category: .religija, width: 6, height: 5)
            ]
        case .dvorac:
            return [
                Castle.gameObject,
                Steps.gameObject,
                House.gameObject,
                Well.gameObject,
                Hotel.gameObject,
                GameObject(name: "Kula", category: .dvorac, width: 3, height: 3),
                GameObject(name: "Kuća", category: .dvorac, width: 4, height: 4), // basic 4×4
                Market.gameObject
            ]
        case .vojnici:
            return [
                GameObject(name: "Vitez", category: .vojnici),
                GameObject(name: "Pješak", category: .vojnici),
                GameObject(name: "Strijelac", category: .vojnici)
            ]
        case .radnici:
            return [
                GameObject(name: "Seljak", category: .radnici),
                GameObject(name: "Obrtnik", category: .radnici)
            ]
        case .industrija:
            return [
                Industry.gameObject,
                Iron.gameObject,
                Stone.gameObject
            ]
        case .ostali:
            return [
                Wall.gameObject,
                GameObject(name: "Cesta", category: .ostali),
                GameObject(name: "Most", category: .ostali, width: 2, height: 1)
            ]
        }
    }
}
