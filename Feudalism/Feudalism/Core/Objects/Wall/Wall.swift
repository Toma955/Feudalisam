//
//  Wall.swift
//  Feudalism
//
//  Objekt Zid (Wall). Datoteke u Core/Objects/Wall/:
//  - Meshy_AI_Stone_Wall_0221071847_texture.obj
//  - Meshy_AI_Stone_Wall_0221071847_texture.mtl (map_Kd Wall_texture.png)
//  - Wall_texture.png
//

import Foundation
import AppKit
import SceneKit

/// Zid – objekt koji se gradi na karti. 3D model u Core/Objects/Wall/.
enum Wall {
    /// Stabilan id tipa (za placement na mapi).
    static let objectId = "object_wall"

    /// Kratica za prikaz na karti / u listi.
    static let displayCode = "W"

    /// Ime 3D modela u bundleu (bez ekstenzije).
    static let modelAssetName = "Meshy_AI_Stone_Wall_0221071847_texture"
    /// Ime teksture – MORA odgovarati .mtl: map_Kd Wall_texture.png (bez ekstenzije).
    static let textureAssetName = "Wall_texture"
    /// Podmapa u bundleu gdje leže .obj, .mtl i .png (gornji Wall folder).
    static let modelSubdirectory = "Core/Objects/Wall"

    /// Jedan GameObject za Zid – za katalog i placement na mapi.
    static var gameObject: GameObject {
        GameObject(
            id: objectId,
            name: "Wall",
            category: .ostali,
            width: 1,
            height: 1,
            displayCode: displayCode,
            modelAssetName: modelAssetName
        )
    }

    /// URL 3D modela (.obj) u bundleu.
    static func modelURL(in bundle: Bundle = .main) -> URL? {
        if let url = bundle.url(forResource: modelAssetName, withExtension: "obj", subdirectory: modelSubdirectory) {
            return url
        }
        return bundle.url(forResource: modelAssetName, withExtension: "obj", subdirectory: "Wall")
            ?? bundle.url(forResource: modelAssetName, withExtension: "obj")
    }

    /// Subdirectory putovi za traženje teksture.
    private static let textureSubdirectories: [String?] = [
        "Core/Objects/Wall",
        "Wall",
        "Feudalism/Core/Objects/Wall",
        "Feudalism/Core/Objects",
        "Feudalism/Core",
        "Feudalism",
        nil,
    ]

    /// Učitaj teksturu iz iste mape kao .obj. .mtl kaže map_Kd Wall_texture.png – mora biti isto ime.
    private static func loadTextureImageNextToOBJ(objURL: URL, bundle: Bundle = .main) -> Any? {
        let dir = objURL.deletingLastPathComponent()
        let names = [textureAssetName, modelAssetName, "texture"]
        for name in names {
            let texURL = dir.appendingPathComponent(name).appendingPathExtension("png")
            guard (try? texURL.checkResourceIsReachable()) == true else { continue }
            if let image = NSImage(contentsOf: texURL) { return image }
        }
        return nil
    }

    /// Učitaj sliku teksture iz bundlea. Prvo probamo Bundle API (radi u buildu), zatim path pored .obj.
    private static func loadTextureImage(bundle: Bundle = .main, objURL: URL? = nil) -> Any? {
        // 1) Bundle API – najpouzdanije u buildu (ne ovisi o pathu .obj na disku)
        let subsToTry = [modelSubdirectory, "Wall", "Core/Objects/Wall", "Feudalism/Core/Objects/Wall", nil] as [String?]
        for sub in subsToTry {
            let url: URL? = sub != nil
                ? bundle.url(forResource: textureAssetName, withExtension: "png", subdirectory: sub)
                : bundle.url(forResource: textureAssetName, withExtension: "png")
            guard let u = url, let img = NSImage(contentsOf: u) else { continue }
            return img
        }
        // 2) Isti folder kao .obj (path u bundleu)
        if let obj = objURL, let img = loadTextureImageNextToOBJ(objURL: obj, bundle: bundle) { return img }
        let names = [textureAssetName, modelAssetName, "texture"]
        let ext = "png"
        for name in names {
            for sub in textureSubdirectories {
                let url = sub != nil
                    ? bundle.url(forResource: name, withExtension: ext, subdirectory: sub)
                    : bundle.url(forResource: name, withExtension: ext)
                guard let url = url, let image = NSImage(contentsOf: url) else { continue }
                return image
            }
        }
        if let base = bundle.resourceURL {
            let pathsToTry = [
                "Core/Objects/Wall/\(textureAssetName).png",
                "Core/Objects/Wall/texture.png",
                "Wall/\(textureAssetName).png",
                "Wall/\(modelAssetName).png",
                "Feudalism/Core/Objects/Wall/\(textureAssetName).png",
                "\(textureAssetName).png",
                "texture.png",
            ]
            for rel in pathsToTry {
                let full = base.appendingPathComponent(rel)
                if (try? full.checkResourceIsReachable()) == true, let image = NSImage(contentsOf: full) {
                    return image
                }
            }
        }
        return nil
    }

    /// Ako true, umjesto teksture stavi magenta. Magenta = model/materijal OK, problem je putanja/ime teksture. Bijelo = materijal se ne primjenjuje na node.
    private static let useTextureTestColor = false  // stavi true privremeno za brzu provjeru

    /// Ponovno primijeni teksturu na čvor (npr. na klon postavljenog zida). Koristi ako zid izgleda bijelo.
    static func reapplyTexture(to node: SCNNode, bundle: Bundle = .main) -> Bool {
        guard let url = modelURL(in: bundle),
              let textureImage = loadTextureImage(bundle: bundle, objURL: url) else { return false }
        let n = applyTextureToNode(node, textureImage: textureImage)
        return n > 0
    }

    /// Stavi teksturu na sve materijale u cijelom stablu čvorova.
    /// Vraća broj materijala na koje je stavljena.
    private static func applyTextureToNode(_ node: SCNNode, textureImage: Any?) -> Int {
        guard textureImage != nil || useTextureTestColor else { return 0 }
        var totalApplied = 0
        func visit(_ n: SCNNode) {
                if let geo = n.geometry, !geo.materials.isEmpty {
                for mat in geo.materials {
                    if useTextureTestColor {
                        mat.diffuse.contents = NSColor.magenta
                        mat.isDoubleSided = true
                        mat.lightingModel = .blinn
                    } else if let textureImage = textureImage {
                        mat.diffuse.contents = textureImage
                        mat.diffuse.wrapS = .repeat
                        mat.diffuse.wrapT = .repeat
                        mat.diffuse.intensity = 1.0
                        mat.ambient.contents = NSColor.white
                        mat.ambient.intensity = 1.0
                        mat.emission.contents = NSColor.black
                        mat.specular.contents = NSColor.darkGray
                        mat.isDoubleSided = true
                        mat.lightingModel = .physicallyBased
                    }
                    totalApplied += 1
                }
            }
            n.childNodes.forEach { visit($0) }
        }
        visit(node)
        return totalApplied
    }

    /// Ispiši u log koliko čvorova ima geometry i koliko ukupno materijala (za dijagnostiku).
    private static func logMaterialCount(in node: SCNNode) {
        var nodesWithGeo = 0
        var totalMats = 0
        func visit(_ n: SCNNode) {
            if let geo = n.geometry, !geo.materials.isEmpty {
                nodesWithGeo += 1
                totalMats += geo.materials.count
            }
            n.childNodes.forEach { visit($0) }
        }
        visit(node)
    }

    static func printTextureDiagnostics(bundle: Bundle = .main) {
        // Dijagnostika teksta – bez ispisa u produkciji
    }

    /// Provjeri jesu li .obj i tekstura u bundleu; ispisuje u datoteku i konzolu. Vrati (success, message) za UI.
    static func checkAndLogTextureStatus(bundle: Bundle = .main) -> (success: Bool, message: String) {
        guard modelURL(in: bundle) != nil else {
            return (false, ".obj nije u bundleu. Dodaj \(modelAssetName).obj u Copy Bundle Resources.")
        }
        let textureImage = loadTextureImage(bundle: bundle, objURL: modelURL(in: bundle))
        if textureImage != nil {
            return (true, "Uspješno učitane.")
        }
        return (false, "\(textureAssetName).png nije u bundleu. Xcode: Add Files → Core/Objects/Wall/Wall_texture.png → Copy Bundle Resources.")
    }

    /// Učitaj 3D model zida kao SCNNode – igra je 3D. Tekstura se učitava iz iste mape kao .obj pa iz bundlea; u konzolu se ispisuje što se dogodilo.
    static func loadSceneKitNode(from bundle: Bundle = .main) -> SCNNode? {
        guard let url = modelURL(in: bundle) else { return nil }
        guard let scene = try? SCNScene(url: url, options: [.checkConsistency: true]) else { return nil }
        let node = SCNNode()
        for child in scene.rootNode.childNodes {
            node.addChildNode(child.clone())
        }
        if let textureImage = loadTextureImage(bundle: bundle, objURL: url) {
            _ = applyTextureToNode(node, textureImage: textureImage)
        }
        return node
    }
}
