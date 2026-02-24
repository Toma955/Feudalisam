//
//  Windmill.swift
//  Feudalism
//
//  Objekt Mlin (Windmill). Datoteke u Core/Objects/Food/Windmill/:
//  - Windmill.obj, Windmill.mtl, Windmill_texture.png
//

import Foundation
import AppKit
import SceneKit

/// Mlin (vjetrenjača) – objekt koji se gradi na karti. 3D model u Core/Objects/Food/Windmill/.
enum Windmill: PlaceableSceneKitObject {
    /// Stabilan id tipa (za placement na mapi).
    static let objectId = "object_windmill"

    /// Kratica za prikaz na karti / u listi (V = vjetrenjača).
    static let displayCode = "V"

    /// Ime 3D modela u bundleu (bez ekstenzije).
    static let modelAssetName = "Windmill"
    /// Ime teksture – MORA odgovarati .mtl: map_Kd Windmill_texture.png (bez ekstenzije).
    static let textureAssetName = "Windmill_texture"
    /// Podmapa u bundleu gdje leže .obj, .mtl i .png.
    static let modelSubdirectory = "Core/Objects/Food/Windmill"

    /// Jedan GameObject za Mlin – za katalog i placement na mapi. 3×3 ćelije.
    static var gameObject: GameObject {
        GameObject(
            id: objectId,
            name: "Mlin",
            category: .hrana,
            width: 3,
            height: 3,
            displayCode: displayCode,
            modelAssetName: modelAssetName
        )
    }

    /// URL 3D modela (.obj) u bundleu.
    static func modelURL(in bundle: Bundle = .main) -> URL? {
        let namesToTry = [modelAssetName, "Windmill"]
        for name in namesToTry {
            if let url = bundle.url(forResource: name, withExtension: "obj", subdirectory: modelSubdirectory) { return url }
            if let url = bundle.url(forResource: name, withExtension: "obj", subdirectory: "Food/Windmill") { return url }
            if let url = bundle.url(forResource: name, withExtension: "obj", subdirectory: "Windmill") { return url }
            if let url = bundle.url(forResource: name, withExtension: "obj") { return url }
        }
        // Fallback: direktna putanja u app bundleu (Copy phase stavlja u Core/Objects/Food/Windmill i Windmill)
        if let base = bundle.resourceURL {
            for name in namesToTry {
                for rel in ["Core/Objects/Food/Windmill/\(name).obj", "Food/Windmill/\(name).obj", "Windmill/\(name).obj", "\(name).obj"] {
                    let full = base.appendingPathComponent(rel)
                    if (try? full.checkResourceIsReachable()) == true { return full }
                }
            }
        }
        return nil
    }

    private static let textureSubdirectories: [String?] = [
        "Core/Objects/Food/Windmill",
        "Food/Windmill",
        "Windmill",
        "Feudalism/Core/Objects/Food/Windmill",
        "Feudalism/Core/Objects/Food",
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
        let subsToTry = [modelSubdirectory, "Food/Windmill", "Windmill", "Core/Objects/Food/Windmill", "Feudalism/Core/Objects/Food/Windmill", nil] as [String?]
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
                "Core/Objects/Food/Windmill/\(textureAssetName).png",
                "Core/Objects/Food/Windmill/texture.png",
                "Food/Windmill/\(textureAssetName).png",
                "Windmill/\(textureAssetName).png",
                "Feudalism/Core/Objects/Food/Windmill/\(textureAssetName).png",
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
