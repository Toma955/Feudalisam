//
//  SmallWall.swift
//  Feudalism
//
//  Mali zid: isti oblik kao veliki, manja visina (6/10 = 240). Koristi ParentWall za 3D i teksture.
//

import Foundation
import AppKit
import SceneKit

/// Visina malog zida u jedinicama (6/10 od 400).
private let smallWallHeight: CGFloat = 240

enum SmallWall: PlaceableSceneKitObject {
    static let objectId = "object_wall_small"
    static let displayCode = "S"
    static let modelAssetName: String? = nil

    static var gameObject: GameObject {
        GameObject(
            id: objectId,
            name: "Small wall",
            category: .ostali,
            width: 1,
            height: 1,
            displayCode: displayCode,
            modelAssetName: modelAssetName
        )
    }

    static func loadSceneKitNode(from bundle: Bundle = .main) -> SCNNode? {
        ParentWall.loadSceneKitNode(from: bundle, wallHeight: smallWallHeight)
    }

    static func reapplyTexture(to node: SCNNode, bundle: Bundle = .main) -> Bool {
        ParentWall.reapplyTexture(to: node, bundle: bundle, wallHeight: smallWallHeight)
    }
}
