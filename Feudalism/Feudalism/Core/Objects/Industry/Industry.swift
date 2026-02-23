//
//  Industry.swift
//  Feudalism
//
//  Objekt Industrija (radionica / pogon). Folder: Core/Objects/Industry/
//  Kasnije: .obj / .usdz model i tekstura u ovom folderu.
//

import Foundation

/// Industrija – objekt koji se gradi na karti. Kategorija: industrija.
enum Industry {
    /// Stabilan id tipa (za placement na mapi).
    static let objectId = "object_industry"

    /// Kratica za prikaz na karti / u listi.
    static let displayCode = "I"

    /// Ime 3D modela u bundleu (bez ekstenzije). Nil = za sada placeholder na mapi.
    static let modelAssetName: String? = nil

    /// Podmapa u bundleu za budući .obj / teksturu.
    static let modelSubdirectory = "Core/Objects/Industry"

    /// Jedan GameObject za Industriju – za katalog i placement na mapi. 3×3 ćelije.
    static var gameObject: GameObject {
        GameObject(
            id: objectId,
            name: "Industrija",
            category: .industrija,
            width: 3,
            height: 3,
            displayCode: displayCode,
            modelAssetName: modelAssetName
        )
    }
}
