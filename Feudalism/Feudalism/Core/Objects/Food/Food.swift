//
//  Food.swift
//  Feudalism
//
//  Objekt Hrana (Food). Folder: Core/Objects/Food/
//  Kasnije: .obj / .usdz model i tekstura u ovom folderu.
//

import Foundation

/// Hrana – objekt koji se gradi na karti. Kategorija: hrana.
enum Food {
    /// Stabilan id tipa (za placement na mapi).
    static let objectId = "object_food"

    /// Kratica za prikaz na karti / u listi.
    static let displayCode = "H"

    /// Ime 3D modela u bundleu (bez ekstenzije). Nil = za sada placeholder na mapi.
    static let modelAssetName: String? = nil

    /// Podmapa u bundleu za budući .obj / teksturu.
    static let modelSubdirectory = "Core/Objects/Food"

    /// Jedan GameObject za Hranu – za katalog i placement na mapi. 2×2 ćelije.
    static var gameObject: GameObject {
        GameObject(
            id: objectId,
            name: "Hrana",
            category: .hrana,
            width: 2,
            height: 2,
            displayCode: displayCode,
            modelAssetName: modelAssetName
        )
    }
}
