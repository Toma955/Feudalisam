//
//  Stone.swift
//  Feudalism
//
//  Objekt Kamenolom (Stone). Model u Core/Objects/Industry/Stone/
//  Stone_Obj.obj, Stone_Mtl.mtl, Stone_Png.png
//

import Foundation
import AppKit
import SceneKit

/// Kamenolom (stone) – objekt koji se gradi na karti. Kategorija: industrija (Rudnik).
enum Stone {
    static let objectId = "object_stone"
    static let displayCode = "K"

    static let modelAssetName = "Stone_Obj"
    static let textureAssetName = "Stone_Png"
    static let modelSubdirectory = "Core/Objects/Industry/Stone"

    static var gameObject: GameObject {
        GameObject(
            id: objectId,
            name: "Kamenolom",
            category: .industrija,
            width: 2,
            height: 2,
            displayCode: displayCode,
            modelAssetName: modelAssetName
        )
    }

    static func modelURL(in bundle: Bundle = .main) -> URL? {
        if let url = bundle.url(forResource: modelAssetName, withExtension: "obj", subdirectory: modelSubdirectory) {
            return url
        }
        return bundle.url(forResource: modelAssetName, withExtension: "obj", subdirectory: "Industry/Stone")
            ?? bundle.url(forResource: modelAssetName, withExtension: "obj", subdirectory: "Stone")
            ?? bundle.url(forResource: modelAssetName, withExtension: "obj")
    }

    private static let textureSubdirectories: [String?] = [
        "Core/Objects/Industry/Stone",
        "Industry/Stone",
        "Stone",
        "Feudalism/Core/Objects/Industry/Stone",
        nil,
    ]

    private static func loadTextureImageNextToOBJ(objURL: URL, bundle: Bundle = .main) -> Any? {
        let dir = objURL.deletingLastPathComponent()
        for name in [textureAssetName, modelAssetName, "texture"] {
            let texURL = dir.appendingPathComponent(name).appendingPathExtension("png")
            guard (try? texURL.checkResourceIsReachable()) == true else { continue }
            if let image = NSImage(contentsOf: texURL) { return image }
        }
        return nil
    }

    private static func loadTextureImage(bundle: Bundle = .main, objURL: URL? = nil) -> Any? {
        for sub in [modelSubdirectory, "Industry/Stone", "Stone", nil] as [String?] {
            let url: URL? = sub != nil
                ? bundle.url(forResource: textureAssetName, withExtension: "png", subdirectory: sub)
                : bundle.url(forResource: textureAssetName, withExtension: "png")
            guard let u = url, let img = NSImage(contentsOf: u) else { continue }
            return img
        }
        if let obj = objURL { return loadTextureImageNextToOBJ(objURL: obj, bundle: bundle) }
        for sub in textureSubdirectories {
            let url = sub != nil
                ? bundle.url(forResource: textureAssetName, withExtension: "png", subdirectory: sub)
                : bundle.url(forResource: textureAssetName, withExtension: "png")
            guard let u = url, let img = NSImage(contentsOf: u) else { continue }
            return img
        }
        return nil
    }

    private static func applyTextureToNode(_ node: SCNNode, textureImage: Any?) -> Int {
        var totalApplied = 0
        func visit(_ n: SCNNode) {
            if let geo = n.geometry, !geo.materials.isEmpty {
                for mat in geo.materials {
                    if let textureImage = textureImage {
                        mat.diffuse.contents = textureImage
                        mat.diffuse.wrapS = .repeat
                        mat.diffuse.wrapT = .repeat
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

    static func reapplyTexture(to node: SCNNode, bundle: Bundle = .main) -> Bool {
        guard let url = modelURL(in: bundle),
              let textureImage = loadTextureImage(bundle: bundle, objURL: url) else { return false }
        return applyTextureToNode(node, textureImage: textureImage) > 0
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
