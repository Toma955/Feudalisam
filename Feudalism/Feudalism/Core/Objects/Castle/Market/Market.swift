//
//  Market.swift
//  Feudalism
//
//  Objekt Tržnica (Market). Datoteke u Core/Objects/Castle/Market/:
//  - Market.obj, Market.mtl, Market_texture.png
//

import Foundation
import AppKit
import SceneKit

/// Tržnica – objekt koji se gradi na karti. 3D model u Core/Objects/Castle/Market/.
enum Market: PlaceableSceneKitObject {
    /// Stabilan id tipa (za placement na mapi).
    static let objectId = "object_market"

    /// Kratica za prikaz na karti / u listi.
    static let displayCode = "M"

    /// Ime 3D modela u bundleu (bez ekstenzije).
    static let modelAssetName = "Market"
    /// Ime teksture – MORA odgovarati .mtl: map_Kd Market_texture.png (bez ekstenzije).
    static let textureAssetName = "Market_texture"
    /// Podmapa u bundleu gdje leže .obj, .mtl i .png.
    static let modelSubdirectory = "Core/Objects/Castle/Market"

    /// Jedan GameObject za Tržnicu – za katalog i placement na mapi. Veličina 3×3 ćelije.
    static var gameObject: GameObject {
        GameObject(
            id: objectId,
            name: "Market",
            category: .dvorac,
            width: 3,
            height: 3,
            displayCode: displayCode,
            modelAssetName: modelAssetName
        )
    }

    /// URL 3D modela (.obj) u bundleu.
    static func modelURL(in bundle: Bundle = .main) -> URL? {
        if let url = bundle.url(forResource: modelAssetName, withExtension: "obj", subdirectory: modelSubdirectory) {
            return url
        }
        return bundle.url(forResource: modelAssetName, withExtension: "obj", subdirectory: "Castle/Market")
            ?? bundle.url(forResource: modelAssetName, withExtension: "obj", subdirectory: "Market")
            ?? bundle.url(forResource: modelAssetName, withExtension: "obj")
    }

    /// Subdirectory putovi za traženje teksture.
    private static let textureSubdirectories: [String?] = [
        "Core/Objects/Castle/Market",
        "Castle/Market",
        "Market",
        "Feudalism/Core/Objects/Castle/Market",
        "Feudalism/Core/Objects/Market",
        "Feudalism/Core",
        "Feudalism",
        nil,
    ]

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

    private static func loadTextureImage(bundle: Bundle = .main, objURL: URL? = nil) -> Any? {
        let subsToTry = [modelSubdirectory, "Castle/Market", "Market", "Core/Objects/Castle/Market", "Feudalism/Core/Objects/Castle/Market", nil] as [String?]
        for sub in subsToTry {
            let url: URL? = sub != nil
                ? bundle.url(forResource: textureAssetName, withExtension: "png", subdirectory: sub)
                : bundle.url(forResource: textureAssetName, withExtension: "png")
            guard let u = url, let img = NSImage(contentsOf: u) else { continue }
            return img
        }
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
                "Core/Objects/Castle/Market/\(textureAssetName).png",
                "Core/Objects/Castle/Market/texture.png",
                "Castle/Market/\(textureAssetName).png",
                "Market/\(textureAssetName).png",
                "Feudalism/Core/Objects/Castle/Market/\(textureAssetName).png",
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

    private static let useTextureTestColor = false

    static func reapplyTexture(to node: SCNNode, bundle: Bundle = .main) -> Bool {
        guard let url = modelURL(in: bundle),
              let textureImage = loadTextureImage(bundle: bundle, objURL: url) else { return false }
        let n = applyTextureToNode(node, textureImage: textureImage)
        return n > 0
    }

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
