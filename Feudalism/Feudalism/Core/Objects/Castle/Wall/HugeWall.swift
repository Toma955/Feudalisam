//
//  HugeWall.swift
//  Feudalism
//
//  Veliki zid (huge_wall): jedan kvadrat (40×40×400). Koristi ParentWall za 3D i teksture.
//

import Foundation
import AppKit
import SceneKit

private let hugeWallHeight: CGFloat = ParentWall.defaultWallHeight

enum HugeWall: PlaceableSceneKitObject {
    static let objectId = "object_huge_wall"
    static let displayCode = "W"
    static let modelAssetName = "Wall"

    static var gameObject: GameObject {
        GameObject(
            id: objectId,
            name: "Huge wall",
            category: .ostali,
            width: 1,
            height: 1,
            displayCode: displayCode,
            modelAssetName: nil
        )
    }

    static func loadSceneKitNode(from bundle: Bundle = .main) -> SCNNode? {
        ParentWall.loadSceneKitNode(from: bundle, wallHeight: hugeWallHeight)
    }

    static func reapplyTexture(to node: SCNNode, bundle: Bundle = .main) -> Bool {
        ParentWall.reapplyTexture(to: node, bundle: bundle, wallHeight: hugeWallHeight)
    }

    static func printTextureDiagnostics(bundle: Bundle = .main) {}
    static func checkAndLogTextureStatus(bundle: Bundle = .main) -> (success: Bool, message: String) {
        (true, "HugeWall koristi proceduralni model (1×40×40×400).")
    }
}
