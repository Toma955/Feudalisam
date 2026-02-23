//
//  House.swift
//  Feudalism
//
//  Objekt Kuća. Folder: Core/Objects/House/
//  Kasnije: .obj / .usdz model i tekstura u ovom folderu.
//

import Foundation

/// Kuća – objekt koji se gradi na karti. Kategorija: dvorac.
enum House {
    /// Stabilan id tipa (za placement na mapi).
    static let objectId = "object_house"

    /// Kratica za prikaz na karti / u listi.
    static let displayCode = "H"

    /// Ime 3D modela u bundleu (bez ekstenzije). Nil = za sada placeholder na mapi.
    static let modelAssetName: String? = nil

    /// Podmapa u bundleu za budući .obj / teksturu.
    static let modelSubdirectory = "Core/Objects/House"

    /// Jedan GameObject za Kuću – za katalog i placement na mapi. 4×4 ćelije.
    static var gameObject: GameObject {
        GameObject(
            id: objectId,
            name: "Kuća",
            category: .dvorac,
            width: 4,
            height: 4,
            displayCode: displayCode,
            modelAssetName: modelAssetName
        )
    }
}
