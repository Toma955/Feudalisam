//
//  CompassCubeView.swift
//  Feudalism
//
//  3D kocka sa stranama svijeta (N/S/E/W) – povlačenjem se rotira kamera po mapi (kao Udemy/Unreal).
//

import SwiftUI
import SceneKit
import AppKit

/// SceneKit prikaz kocke s oznakama strana; rotacija se sinkronizira s bindingom.
private final class CompassCubeScene {
    let scene = SCNScene()
    let boxNode: SCNNode
    private let boxSize: CGFloat = 1.2

    init() {
        let box = SCNBox(width: boxSize, height: boxSize, length: boxSize, chamferRadius: 0.08)
        // SCNBox materijali: [front (+Z), right (+X), back (-Z), left (-X), top (+Y), bottom (-Y)]
        // Stranice svijeta: front = Sjever (N), right = Istok (E), back = Jug (S), left = Zapad (W)
        let n = Self.material(color: NSColor(red: 0.85, green: 0.35, blue: 0.3, alpha: 1))   // N – crvenkasto
        let e = Self.material(color: NSColor(red: 0.35, green: 0.75, blue: 0.4, alpha: 1))  // E – zeleno
        let s = Self.material(color: NSColor(red: 0.3, green: 0.45, blue: 0.9, alpha: 1))    // S – plavo
        let w = Self.material(color: NSColor(red: 0.9, green: 0.65, blue: 0.2, alpha: 1))     // W – narančasto
        let top = Self.material(color: NSColor.white.withAlphaComponent(0.9))
        let bottom = Self.material(color: NSColor(white: 0.25, alpha: 1))
        box.materials = [n, e, s, w, top, bottom]

        boxNode = SCNNode(geometry: box)
        boxNode.name = "compassBox"
        scene.rootNode.addChildNode(boxNode)

        let cameraNode = SCNNode()
        cameraNode.camera = SCNCamera()
        cameraNode.camera?.zNear = 0.01
        cameraNode.camera?.zFar = 100
        cameraNode.camera?.usesOrthographicProjection = true
        cameraNode.camera?.orthographicScale = 1.4
        cameraNode.position = SCNVector3(0, 0, 3.2)
        cameraNode.look(at: SCNVector3(0, 0, 0))
        scene.rootNode.addChildNode(cameraNode)

        let light = SCNNode()
        light.light = SCNLight()
        light.light?.type = .omni
        light.light?.intensity = 800
        light.position = SCNVector3(2, 2, 4)
        scene.rootNode.addChildNode(light)

        let amb = SCNNode()
        amb.light = SCNLight()
        amb.light?.type = .ambient
        amb.light?.intensity = 300
        scene.rootNode.addChildNode(amb)
    }

    private static func material(color: NSColor) -> SCNMaterial {
        let m = SCNMaterial()
        m.diffuse.contents = color
        m.locksAmbientWithDiffuse = true
        return m
    }

    /// Rotacija kocke: mapRotation iz kamere mape. Stranica prema kameri = smjer u koji gledamo na mapi.
    /// Kad mapRotation = 0, kamera gleda prema -Z (jug) → na kocki prema kameri treba biti S (+ π).
    func setRotation(_ radians: CGFloat) {
        boxNode.eulerAngles.y = CGFloat(radians) + .pi
    }
}

/// NSViewRepresentable koji prikazuje 3D kocku; prima rotaciju iz GameState.
private struct CompassCubeSceneView: NSViewRepresentable {
    var rotation: CGFloat

    func makeNSView(context: Context) -> SCNView {
        let view = SCNView()
        view.wantsLayer = true
        view.layer?.contentsScale = NSScreen.main?.backingScaleFactor ?? 2
        view.scene = context.coordinator.compassScene.scene
        view.autoenablesDefaultLighting = false
        view.allowsCameraControl = false
        view.backgroundColor = .clear
        view.antialiasingMode = .none
        view.pointOfView = view.scene?.rootNode.childNodes.first { $0.camera != nil }
        context.coordinator.setRotation(rotation)
        return view
    }

    func updateNSView(_ nsView: SCNView, context: Context) {
        context.coordinator.setRotation(rotation)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    final class Coordinator {
        let compassScene = CompassCubeScene()
        func setRotation(_ r: CGFloat) { compassScene.setRotation(r) }
    }
}

// MARK: - SwiftUI view s povlačenjem

/// 3D kocka: vodoravno = rotacija mape, okomito = pan kamere gore/dolje (kao Udemy/Unreal).
struct CompassCubeView: View {
    @Binding var mapRotation: CGFloat
    @Binding var tiltAngle: CGFloat
    @Binding var panOffset: CGPoint
    @State private var gestureStartRotation: CGFloat?
    @State private var gestureStartPan: CGPoint?
    private let rotationSensitivity: CGFloat = 0.008
    private let panSensitivity: CGFloat = 1.2

    var body: some View {
        ZStack {
            CompassCubeSceneView(rotation: mapRotation)
                .frame(width: 72, height: 72)
                .clipShape(RoundedRectangle(cornerRadius: 10))

            VStack {
                Image(systemName: "triangle.fill")
                    .font(.system(size: 6))
                    .foregroundStyle(.white.opacity(0.9))
                    .shadow(color: .black.opacity(0.6), radius: 1)
                Text("gledanje")
                    .font(.system(size: 8, weight: .medium))
                    .foregroundStyle(.white.opacity(0.85))
                Spacer(minLength: 0)
            }
            .frame(width: 72, height: 72)
            .padding(.top, 2)
            .allowsHitTesting(false)
        }
        .frame(width: 72, height: 72)
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 2)
                .onChanged { value in
                    if gestureStartRotation == nil {
                        gestureStartRotation = mapRotation
                        gestureStartPan = panOffset
                    }
                    guard let startR = gestureStartRotation, let startP = gestureStartPan else { return }
                    let twoPi = 2 * CGFloat.pi
                    mapRotation = (startR + value.translation.width * rotationSensitivity).truncatingRemainder(dividingBy: twoPi)
                    panOffset = CGPoint(x: startP.x, y: startP.y + value.translation.height * panSensitivity)
                }
                .onEnded { _ in
                    gestureStartRotation = nil
                    gestureStartPan = nil
                }
        )
    }
}

#Preview {
    CompassCubeView(
        mapRotation: .constant(0),
        tiltAngle: .constant(20 * .pi / 180),
        panOffset: .constant(.zero)
    )
    .frame(width: 100, height: 100)
    .background(Color.gray.opacity(0.3))
}
