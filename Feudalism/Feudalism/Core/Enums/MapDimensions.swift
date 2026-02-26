//
//  MapDimensions.swift
//  Feudalism
//
//  Jedan izvor istine za dimenzije mape. Sve mape su kockaste.
//  side = broj ćelija za gradnju po strani: 200×200, 400×400, … 1000×1000 (folder 200x200, 400x400, …).
//

import Foundation

/// Dopuštene dimenzije mape (kockasta: side×side ćelija za gradnju). Folder 200x200 = 200×200 ćelija.
enum MapDimension: Int, CaseIterable, Identifiable {
    case size200 = 200
    case size400 = 400
    case size600 = 600
    case size800 = 800
    case size1000 = 1000

    var id: Int { rawValue }

    /// Stranica mape (broj ćelija po strani), npr. 200. Isti broj za folder 200x200.
    var side: Int { rawValue }

    /// Ime foldera za tu veličinu, npr. "200x200".
    var folderName: String { "\(side)x\(side)" }

    /// Broj ćelija za gradnju po strani. 200 → 200.
    var placementCellsPerSide: Int { side }

    /// Svi dopušteni side vrijednosti (za validaciju i liste).
    static var allSides: [Int] { allCases.map(\.side) }

    /// Je li zadani side valjana dimenzija (broj minimalnih jedinica po strani).
    static func isValid(_ side: Int) -> Bool {
        side > 0 && side <= 10000 && allSides.contains(side)
    }

    /// Vraća enum za zadani broj ćelija (rows == cols) ako je valjana dimenzija (200, 400, …).
    static func from(rows: Int, cols: Int) -> MapDimension? {
        guard rows == cols else { return nil }
        return MapDimension(rawValue: rows)
    }

    /// Vraća enum za zadani side (broj minimalnih jedinica po strani).
    static func from(side: Int) -> MapDimension? {
        MapDimension(rawValue: side)
    }
}
