//
//  WallPreviewView.swift
//  Feudalism
//
//  Prikaz 3D modela zida (SceneKit) – da se u igri vidi skinuti model. Samo macOS.
//

import SwiftUI
import SceneKit
import AppKit

/// Prikaz učitane 3D scene zida – za upotrebu u igri (overlay, sheet ili ćelija).
struct WallPreviewView: View {
    var body: some View {
        WallSceneView()
            .frame(minWidth: 200, minHeight: 200)
            .background(Color.black.opacity(0.3))
            .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

private struct WallSceneView: NSViewRepresentable {
    func makeNSView(context: Context) -> SCNView { makeSceneView() }
    func updateNSView(_ nsView: SCNView, context: Context) {}
}

private enum WallPreviewState { static var diagnosticsDone = false }

private func makeSceneView() -> SCNView {
    if !WallPreviewState.diagnosticsDone {
        WallPreviewState.diagnosticsDone = true
        HugeWall.printTextureDiagnostics()
    }
    let view = SCNView()
    view.autoenablesDefaultLighting = true
    view.allowsCameraControl = true
    view.backgroundColor = NSColor(white: 0.15, alpha: 1)
    let scene = SCNScene()
    if let wallNode = HugeWall.loadSceneKitNode() {
        wallNode.position = SCNVector3(0, 0, 0)
        wallNode.scale = SCNVector3(0.5, 0.5, 0.5)
        scene.rootNode.addChildNode(wallNode)
    } else {
        let box = SCNBox(width: 1, height: 0.8, length: 0.3, chamferRadius: 0)
        box.firstMaterial?.diffuse.contents = NSColor.brown
        let fallback = SCNNode(geometry: box)
        scene.rootNode.addChildNode(fallback)
    }
    view.scene = scene
    view.pointOfView?.position = SCNVector3(1.5, 1, 1.5)
    view.pointOfView?.eulerAngles = SCNVector3(-0.3, 0.4, 0)
    return view
}

#Preview {
    WallPreviewView()
        .frame(width: 300, height: 300)
}
