//
//  Wall.swift
//  Feudalism
//
//  Pravi zid: jedan veliki kvadrat (40x40x400).
//

import Foundation
import AppKit
import SceneKit

enum Wall: PlaceableSceneKitObject {
    static let objectId = "object_wall"
    static let displayCode = "W"
    static let modelAssetName = "Wall"

    static var gameObject: GameObject {
        GameObject(
            id: objectId,
            name: "Wall",
            category: .ostali,
            width: 1,
            height: 1,
            displayCode: displayCode,
            modelAssetName: nil
        )
    }

    private static let cubeSize: CGFloat = 40
    private static let wallHeight: CGFloat = 400
    private static let wallColor = NSColor(red: 0.45, green: 0.32, blue: 0.22, alpha: 1)
    /// Koliko puta se tekstura ponovi po širini i visini zida.
    private static let tileU: CGFloat = 1
    private static let tileV: CGFloat = wallHeight / cubeSize
    private static let topTileU: CGFloat = 1
    private static let topTileV: CGFloat = 1
    private struct WallTextureSet {
        let baseColor: NSImage?
        let normalGL: NSImage?
        let roughness: NSImage?
        let ambientOcclusion: NSImage?
        let displacement: NSImage?
    }
    private struct TopTextureSet {
        let baseColor: NSImage?
        let normalGL: NSImage?
        let roughness: NSImage?
        let ambientOcclusion: NSImage?
        let displacement: NSImage?
    }

    private static func applyTiling(_ prop: SCNMaterialProperty, u: CGFloat, v: CGFloat) {
        prop.wrapS = .repeat
        prop.wrapT = .repeat
        prop.contentsTransform = SCNMatrix4MakeScale(u, v, 1)
    }

    static func reapplyTexture(to node: SCNNode, bundle: Bundle = .main) -> Bool {
        let side = makeWallMaterial(bundle: bundle)
        let top = makeTopWallMaterial(bundle: bundle)
        applyWallMaterialRecursive(node, sideMaterial: side, topMaterial: top)
        return true
    }

    private static func textureURL(bundle: Bundle, name: String, subdirs: [String?]) -> URL? {
        for sub in subdirs {
            if let url = bundle.url(forResource: name, withExtension: "png", subdirectory: sub) {
                return url
            }
            if let url = bundle.url(forResource: name, withExtension: "jpg", subdirectory: sub) {
                return url
            }
        }
        return nil
    }

    private static func loadWallTextureSet(bundle: Bundle = .main) -> WallTextureSet {
        let subdirs: [String?] = [
            "Core/Objects/Textures/wall",
            "Objects/Textures/wall",
            "Textures/wall",
            "Core/Objects/Textures/Wall",
            "Objects/Textures/Wall",
            "Textures/Wall",
            nil,
        ]
        let baseCandidates = ["wall_base_color", "wall_texture", "wall", "Wall_texture"]
        let normalCandidates = ["wall_normal_gl", "wall_normal", "wall_normal_dx"]
        let roughCandidates = ["wall_roughness"]
        let aoCandidates = ["wall_ambient_occlusion", "wall_ao"]
        let dispCandidates = ["wall_displacement", "wall_height"]

        let load = { (candidates: [String]) -> NSImage? in
            for name in candidates {
                if let url = textureURL(bundle: bundle, name: name, subdirs: subdirs),
                   let image = NSImage(contentsOf: url) {
                    return image
                }
            }
            return nil
        }

        let set = WallTextureSet(
            baseColor: load(baseCandidates),
            normalGL: load(normalCandidates),
            roughness: load(roughCandidates),
            ambientOcclusion: load(aoCandidates),
            displacement: load(dispCandidates)
        )
        if set.baseColor == nil {
            placementDebugLog("Wall texture missing: expected base color in Core/Objects/Textures/wall (wall_base_color.png)")
        } else {
            placementDebugLog("Wall texture set loaded (base + optional normal/roughness/ao/displacement)")
        }
        return set
    }

    private static func loadTopTextureSet(bundle: Bundle = .main) -> TopTextureSet {
        let subdirs: [String?] = [
            "Core/Objects/Textures/top_wall",
            "Objects/Textures/top_wall",
            "Textures/top_wall",
            "Core/Objects/Textures/Top_Wall",
            "Objects/Textures/Top_Wall",
            "Textures/Top_Wall",
            nil,
        ]
        let baseCandidates = ["top_wall_base_color", "top_wall_texture", "top_wall", "Bricks100_1K-JPG_Color"]
        let normalCandidates = ["top_wall_normal_gl", "top_wall_normal", "top_wall_normal_dx", "Bricks100_1K-JPG_NormalGL"]
        let roughCandidates = ["top_wall_roughness", "Bricks100_1K-JPG_Roughness"]
        let aoCandidates = ["top_wall_ambient_occlusion", "top_wall_ao", "Bricks100_1K-JPG_AmbientOcclusion"]
        let dispCandidates = ["top_wall_displacement", "top_wall_height", "Bricks100_1K-JPG_Displacement"]

        let load = { (candidates: [String]) -> NSImage? in
            for name in candidates {
                if let url = textureURL(bundle: bundle, name: name, subdirs: subdirs),
                   let image = NSImage(contentsOf: url) {
                    return image
                }
            }
            return nil
        }

        let set = TopTextureSet(
            baseColor: load(baseCandidates),
            normalGL: load(normalCandidates),
            roughness: load(roughCandidates),
            ambientOcclusion: load(aoCandidates),
            displacement: load(dispCandidates)
        )
        if set.baseColor == nil {
            placementDebugLog("Top wall texture missing: expected base color in Core/Objects/Textures/top_wall (top_wall_base_color.png/jpg)")
        } else {
            placementDebugLog("Top wall texture set loaded (base + optional normal/roughness/ao/displacement)")
        }
        return set
    }

    private static func makeWallMaterial(bundle: Bundle = .main) -> SCNMaterial {
        let textures = loadWallTextureSet(bundle: bundle)
        let mat = SCNMaterial()
        mat.diffuse.contents = textures.baseColor ?? wallColor
        applyTiling(mat.diffuse, u: tileU, v: tileV)
        mat.ambient.contents = NSColor.white
        mat.specular.contents = NSColor.darkGray
        mat.isDoubleSided = true
        mat.lightingModel = .physicallyBased
        if let n = textures.normalGL {
            mat.normal.contents = n
            mat.normal.intensity = 1.0
            applyTiling(mat.normal, u: tileU, v: tileV)
        }
        if let r = textures.roughness {
            mat.roughness.contents = r
            applyTiling(mat.roughness, u: tileU, v: tileV)
        }
        if let ao = textures.ambientOcclusion {
            mat.ambientOcclusion.contents = ao
            applyTiling(mat.ambientOcclusion, u: tileU, v: tileV)
        }
        if let d = textures.displacement {
            mat.displacement.contents = d
            applyTiling(mat.displacement, u: tileU, v: tileV)
        }
        return mat
    }

    private static func makeTopWallMaterial(bundle: Bundle = .main) -> SCNMaterial {
        let textures = loadTopTextureSet(bundle: bundle)
        let mat = SCNMaterial()
        mat.diffuse.contents = textures.baseColor ?? wallColor
        applyTiling(mat.diffuse, u: topTileU, v: topTileV)
        mat.ambient.contents = NSColor.white
        mat.specular.contents = NSColor.darkGray
        mat.isDoubleSided = true
        mat.lightingModel = .physicallyBased
        if let n = textures.normalGL {
            mat.normal.contents = n
            mat.normal.intensity = 1.0
            applyTiling(mat.normal, u: topTileU, v: topTileV)
        }
        if let r = textures.roughness {
            mat.roughness.contents = r
            applyTiling(mat.roughness, u: topTileU, v: topTileV)
        }
        if let ao = textures.ambientOcclusion {
            mat.ambientOcclusion.contents = ao
            applyTiling(mat.ambientOcclusion, u: topTileU, v: topTileV)
        }
        if let d = textures.displacement {
            mat.displacement.contents = d
            applyTiling(mat.displacement, u: topTileU, v: topTileV)
        }
        return mat
    }

    private static func applyWallMaterialRecursive(_ node: SCNNode, sideMaterial: SCNMaterial, topMaterial: SCNMaterial) {
        if let geo = node.geometry {
            if let box = geo as? SCNBox {
                let side = sideMaterial.copy() as? SCNMaterial ?? sideMaterial
                let top = topMaterial.copy() as? SCNMaterial ?? topMaterial
                // SCNBox materials order: front, right, back, left, top, bottom
                box.materials = [side, side, side, side, top, side]
            } else if node.name == "steps_prism", geo.elements.count >= 2 {
                let top = topMaterial.copy() as? SCNMaterial ?? topMaterial
                let side = sideMaterial.copy() as? SCNMaterial ?? sideMaterial
                // Steps geometry elements order: [top/bottom, sides]
                geo.materials = [top, side]
            } else if geo.materials.isEmpty {
                geo.materials = [sideMaterial.copy() as? SCNMaterial ?? sideMaterial]
            } else {
                geo.materials = geo.materials.map { _ in
                    sideMaterial.copy() as? SCNMaterial ?? sideMaterial
                }
            }
        }
        node.childNodes.forEach { applyWallMaterialRecursive($0, sideMaterial: sideMaterial, topMaterial: topMaterial) }
    }

    static func loadSceneKitNode(from bundle: Bundle = .main) -> SCNNode? {
        let container = SCNNode()
        container.name = "wall"
        let box = SCNBox(width: cubeSize, height: wallHeight, length: cubeSize, chamferRadius: 0)
        let side = makeWallMaterial(bundle: bundle)
        let top = makeTopWallMaterial(bundle: bundle)
        box.materials = [side, side, side, side, top, side]
        let cubeNode = SCNNode(geometry: box)
        cubeNode.position = SCNVector3(0, wallHeight / 2, 0)
        container.addChildNode(cubeNode)

        let (mn, mx) = container.boundingBox
        let sourceHeight = CGFloat(mx.y - mn.y)
        placementDebugLog("Wall.loadSceneKitNode cubeCount=1 cubeSize=\(String(format: "%.3f", cubeSize)) wallHeight=\(String(format: "%.3f", wallHeight)) sourceHeight=\(String(format: "%.3f", sourceHeight))")
        return container
    }

    // Ostavljen API kompatibilan poziv iz postojeće aplikacije.
    static func printTextureDiagnostics(bundle: Bundle = .main) {}
    static func checkAndLogTextureStatus(bundle: Bundle = .main) -> (success: Bool, message: String) {
        (true, "Wall koristi proceduralni model (1x40x40x400).")
    }
}
