//
//  Castle.swift
//  Feudalism
//
//  Objekt Dvorac (Castle). Folder: Core/Objects/Castle/
//  Kasnije: .obj / .usdz model i tekstura u ovom folderu.
//

import Foundation

/// Dvorac – objekt koji se gradi na karti. Kategorija: dvorac.
enum Castle {
    /// Stabilan id tipa (za placement na mapi).
    static let objectId = "object_castle"

    /// Kratica za prikaz na karti / u listi.
    static let displayCode = "C"

    /// Ime 3D modela u bundleu (bez ekstenzije). Nil = za sada placeholder na mapi.
    static let modelAssetName: String? = nil

    /// Podmapa u bundleu za budući .obj / teksturu.
    static let modelSubdirectory = "Core/Objects/Castle"

    /// Jedan GameObject za Dvorac – za katalog i placement na mapi. 8×8 ćelija.
    static var gameObject: GameObject {
        GameObject(
            id: objectId,
            name: "Dvorac",
            category: .dvorac,
            width: 8,
            height: 8,
            displayCode: displayCode,
            modelAssetName: modelAssetName
        )
    }
}
