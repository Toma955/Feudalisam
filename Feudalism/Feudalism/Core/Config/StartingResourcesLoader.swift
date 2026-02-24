//
//  StartingResourcesLoader.swift
//  Feudalism
//
//  Odvojen mehanizam: čita koliko resursa tko dobiva pri kreiranju igre iz datoteke (starting_resources.json).
//  Pri kreiranju igre GameState ili SoloSetup dobiva informacije odavde; datoteka je izvor istine za početne resurse.
//

import Foundation

/// Jedan set početnih resursa (zlato, drvo, metal, kamen, kruh, hmelj, sijeno) za profil (npr. solo ili realm).
struct StartingResources: Equatable {
    var gold: Int
    var wood: Int
    var iron: Int
    var stone: Int
    var food: Int
    var hop: Int
    var hay: Int

    static let zero = StartingResources(gold: 0, wood: 0, iron: 0, stone: 0, food: 0, hop: 0, hay: 0)
}

/// Učitava starting_resources.json iz bundlea. Profili: "solo", kasnije npr. "realm_1", "default".
enum StartingResourcesLoader {
    private static let fileName = "starting_resources"
    private static let subdirs = ["Config", "Core/Config", "Feudalism/Core/Config"]

    private struct FileShape: Decodable {
        var solo: ResourceEntry?
        struct ResourceEntry: Decodable {
            var gold: Int?
            var wood: Int?
            var iron: Int?
            var stone: Int?
            var food: Int?
            var hop: Int?
            var hay: Int?
        }
    }

    /// Vrati početne resurse za dani profil. Ako datoteka ne postoji ili profil nije pronađen, vraća zero.
    static func startingResources(for profile: String = "solo") -> StartingResources {
        guard let data = loadData() else { return .zero }
        let decoder = JSONDecoder()
        guard let file = try? decoder.decode(FileShape.self, from: data) else { return .zero }
        switch profile {
        case "solo":
            guard let s = file.solo else { return .zero }
            return StartingResources(
                gold: max(0, s.gold ?? 0),
                wood: max(0, s.wood ?? 0),
                iron: max(0, s.iron ?? 0),
                stone: max(0, s.stone ?? 0),
                food: max(0, s.food ?? 0),
                hop: max(0, s.hop ?? 0),
                hay: max(0, s.hay ?? 0)
            )
        default:
            return .zero
        }
    }

    private static func loadData() -> Data? {
        let bundle = Bundle.main
        for sub in subdirs {
            if let url = bundle.url(forResource: fileName, withExtension: "json", subdirectory: sub),
               let data = try? Data(contentsOf: url) {
                return data
            }
        }
        if let url = bundle.url(forResource: fileName, withExtension: "json"), let data = try? Data(contentsOf: url) {
            return data
        }
        return nil
    }
}
