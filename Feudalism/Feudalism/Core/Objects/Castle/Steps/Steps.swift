//
//  Steps.swift
//  Feudalism
//
//  Trokutasti "stepenice" oblik za Dvor → Stepenice (solo).
//

import Foundation
import AppKit
import SceneKit

enum Steps: PlaceableSceneKitObject {
    static let objectId = "object_steps"
    static let displayCode = "S"

    static var gameObject: GameObject {
        GameObject(
            id: objectId,
            name: "Steps",
            category: .dvorac,
            width: 1,
            height: 1,
            displayCode: displayCode,
            modelAssetName: nil
        )
    }

    private static let baseSize: CGFloat = 40
    private static let shapeHeight: CGFloat = 400

    static func loadSceneKitNode(from bundle: Bundle = .main) -> SCNNode? {
        let container = SCNNode()
        container.name = "steps"
        let h = baseSize / 2
        // Baza je 1x1 ćelija presječena dijagonalom kut-kut: A(-,-), B(+,-), C(-,+).
        let a = SCNVector3(-h, 0, -h)
        let b = SCNVector3(h, 0, -h)
        let c = SCNVector3(-h, 0, h)
        let at = SCNVector3(a.x, shapeHeight, a.z)
        let bt = SCNVector3(b.x, shapeHeight, b.z)
        let ct = SCNVector3(c.x, shapeHeight, c.z)

        var vertices: [SCNVector3] = []
        var texcoords: [CGPoint] = []
        var topBottomIndices: [UInt32] = []
        var sideIndices: [UInt32] = []

        let mapTopBottom: (SCNVector3) -> CGPoint = { v in
            CGPoint(x: (CGFloat(v.x) + h) / baseSize, y: (CGFloat(v.z) + h) / baseSize)
        }
        let mapSideX: (SCNVector3) -> CGPoint = { v in
            CGPoint(x: (CGFloat(v.x) + h) / baseSize, y: CGFloat(v.y) / shapeHeight)
        }
        let mapSideZ: (SCNVector3) -> CGPoint = { v in
            CGPoint(x: (CGFloat(v.z) + h) / baseSize, y: CGFloat(v.y) / shapeHeight)
        }
        let mapSideDiag: (SCNVector3) -> CGPoint = { v in
            let bx = CGFloat(b.x), bz = CGFloat(b.z)
            let cx = CGFloat(c.x), cz = CGFloat(c.z)
            let px = CGFloat(v.x), pz = CGFloat(v.z)
            let dx = cx - bx, dz = cz - bz
            let denom = max(0.0001, dx * dx + dz * dz)
            let t = ((px - bx) * dx + (pz - bz) * dz) / denom
            return CGPoint(x: min(1, max(0, t)), y: CGFloat(v.y) / shapeHeight)
        }
        func addTri(_ v0: SCNVector3, _ uv0: CGPoint, _ v1: SCNVector3, _ uv1: CGPoint, _ v2: SCNVector3, _ uv2: CGPoint, topBottom: Bool) {
            let base = UInt32(vertices.count)
            vertices.append(contentsOf: [v0, v1, v2])
            texcoords.append(contentsOf: [uv0, uv1, uv2])
            if topBottom {
                topBottomIndices.append(contentsOf: [base, base + 1, base + 2])
            } else {
                sideIndices.append(contentsOf: [base, base + 1, base + 2])
            }
        }

        // Base + top
        addTri(a, mapTopBottom(a), c, mapTopBottom(c), b, mapTopBottom(b), topBottom: true)
        addTri(at, mapTopBottom(at), bt, mapTopBottom(bt), ct, mapTopBottom(ct), topBottom: true)
        // Vertical side AB
        addTri(a, mapSideX(a), b, mapSideX(b), bt, mapSideX(bt), topBottom: false)
        addTri(a, mapSideX(a), bt, mapSideX(bt), at, mapSideX(at), topBottom: false)
        // Vertical side BC (diagonal in cell)
        addTri(b, mapSideDiag(b), c, mapSideDiag(c), ct, mapSideDiag(ct), topBottom: false)
        addTri(b, mapSideDiag(b), ct, mapSideDiag(ct), bt, mapSideDiag(bt), topBottom: false)
        // Vertical side CA
        addTri(c, mapSideZ(c), a, mapSideZ(a), at, mapSideZ(at), topBottom: false)
        addTri(c, mapSideZ(c), at, mapSideZ(at), ct, mapSideZ(ct), topBottom: false)

        let pos = SCNGeometrySource(vertices: vertices)
        let uv = SCNGeometrySource(textureCoordinates: texcoords)
        let topElem = SCNGeometryElement(indices: topBottomIndices, primitiveType: .triangles)
        let sideElem = SCNGeometryElement(indices: sideIndices, primitiveType: .triangles)
        let prism = SCNGeometry(sources: [pos, uv], elements: [topElem, sideElem])
        let prismNode = SCNNode(geometry: prism)
        prismNode.name = "steps_prism"
        container.addChildNode(prismNode)

        _ = reapplyTexture(to: container, bundle: bundle)
        return container
    }

    static func reapplyTexture(to node: SCNNode, bundle: Bundle = .main) -> Bool {
        // Reuse wall material setup for consistent look.
        Wall.reapplyTexture(to: node, bundle: bundle)
    }
}
