//
//  Iron.swift
//  Feudalism
//
//  Objekt Željezara (Iron). Model u Core/Objects/Industry/Iron/
//  Iron_Obj.obj, Iron_Mtl.mtl, Iron_Png.png
//

import Foundation
import AppKit
import SceneKit

/// Željezara (iron) – objekt koji se gradi na karti. Kategorija: industrija (Rudnik).
enum Iron {
    static let objectId = "object_iron"
    static let displayCode = "Ž"

    static let modelAssetName = "Iron_Obj"
    static let textureAssetName = "Iron_Png"
    static let modelSubdirectory = "Core/Objects/Industry/Iron"

    static var gameObject: GameObject {
        GameObject(
            id: objectId,
            name: "Željezara",
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
        return bundle.url(forResource: modelAssetName, withExtension: "obj", subdirectory: "Industry/Iron")
            ?? bundle.url(forResource: modelAssetName, withExtension: "obj", subdirectory: "Iron")
            ?? bundle.url(forResource: modelAssetName, withExtension: "obj")
    }

    private static let textureSubdirectories: [String?] = [
        "Core/Objects/Industry/Iron",
        "Industry/Iron",
        "Iron",
        "Feudalism/Core/Objects/Industry/Iron",
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
        for sub in [modelSubdirectory, "Industry/Iron", "Iron", nil] as [String?] {
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
