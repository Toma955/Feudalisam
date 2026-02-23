//
//  Farm.swift
//  Feudalism
//
//  Objekt Farma. Folder: Core/Objects/Farm/
//  Kasnije: .obj / .usdz model i tekstura u ovom folderu.
//

import Foundation

/// Farma – objekt koji se gradi na karti. Kategorija: farme.
enum Farm {
    /// Stabilan id tipa (za placement na mapi).
    static let objectId = "object_farm"

    /// Kratica za prikaz na karti / u listi.
    static let displayCode = "F"

    /// Ime 3D modela u bundleu (bez ekstenzije). Nil = za sada placeholder na mapi.
    static let modelAssetName: String? = nil

    /// Podmapa u bundleu za budući .obj / teksturu.
    static let modelSubdirectory = "Core/Objects/Farm"

    /// Jedan GameObject za Farmu – za katalog i placement na mapi. 4×4 ćelije.
    static var gameObject: GameObject {
        GameObject(
            id: objectId,
            name: "Farma",
            category: .farme,
            width: 4,
            height: 4,
            displayCode: displayCode,
            modelAssetName: modelAssetName
        )
    }
}
