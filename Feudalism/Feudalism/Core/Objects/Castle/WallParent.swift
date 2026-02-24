//
//  WallParent.swift
//  Feudalism
//
//  Parent zid: zajednički ugovor za sve tipove zida (veliki zid 10/10, mali zid 6/10, …).
//  Trošak, život i visina definiraju se po tipu. HugeWall = veliki zid, SmallWall = mali zid.
//

import Foundation

/// Ugovor za svaki tip zida: objectId, visina kao X/10, kasnije i trošak/život po tipu.
protocol WallParentProtocol {
    static var objectId: String { get }
    /// Visina zida: 10 = veliki (10/10), 6 = mali (6/10).
    static var wallHeightLevel: Int { get }
    /// Maksimalna visina (nazivnik) – uvijek 10.
    static var wallHeightMax: Int { get }
}

extension WallParentProtocol {
    static var wallHeightMax: Int { 10 }
}

/// Registar svih tipova zida i pomoćne metode. Dodaj nove tipove ovdje (npr. Mali zid).
enum WallParent {
    /// Svi objectId-evi koji su zidovi (veliki, mali, …).
    static var allObjectIds: [String] {
        allWallTypes.map { $0.objectId }
    }

    /// Tipovi zida koji konformiraju WallParentProtocol. Prvi = veliki zid (HugeWall), kasnije mali zid (SmallWall).
    private static let allWallTypes: [WallParentProtocol.Type] = [
        HugeWall.self,
        SmallWall.self,
    ]

    /// Je li dani objectId neki od tipova zida?
    static func isWall(objectId: String) -> Bool {
        allObjectIds.contains(objectId)
    }

    /// Visina zida za objectId (npr. 10 za veliki, 6 za mali). Nil ako nije zid.
    static func wallHeightLevel(for objectId: String) -> Int? {
        allWallTypes.first { $0.objectId == objectId }.map { $0.wallHeightLevel }
    }

    /// Nazivnik visine (uvijek 10).
    static let wallHeightMax = 10
}

// MARK: - Veliki zid (HugeWall) – 10/10.
extension HugeWall: WallParentProtocol {
    static var wallHeightLevel: Int { 10 }
    static var wallHeightMax: Int { 10 }
}

// MARK: - Mali zid – 6/10.
extension SmallWall: WallParentProtocol {
    static var wallHeightLevel: Int { 6 }
    static var wallHeightMax: Int { 10 }
}
