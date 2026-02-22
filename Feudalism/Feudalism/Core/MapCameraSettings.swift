//
//  MapCameraSettings.swift
//  Feudalism
//
//  Postavke kamere na mapi – zoom, nagib, brzina pomicanja. Mijenjaju se u Postavkama.
//

import Foundation
import CoreGraphics

/// Faze zooma: 1 = šuma (2.1), 2 = stablo (14), 3 = tri stabla (29.5), 4 = list (38.0).
enum ZoomPhase: Int, CaseIterable {
    case forest = 1      // 2.1
    case oneTree = 2     // 14
    case threeTrees = 3  // 29.5
    case leaf = 4        // 38.0

    static let zoomValues: [CGFloat] = [2.1, 14.0, 29.5, 38.0]

    var zoomValue: CGFloat {
        ZoomPhase.zoomValues[rawValue - 1]
    }
}

/// Postavke kamere za mapu – početni zoom, nagib (3D), brzina pomicanja (WASD/strelice).
/// Kasnije: u Postavkama korisnik mijenja ove vrijednosti.
struct MapCameraSettings {
    /// Početni zoom (1.0 = cijela mapa vidljiva; > 1 = zumirano).
    var initialZoom: CGFloat = 1.0
    /// Nagib mape u radijanima (strelice gore/dolje). 20° = početno.
    var tiltAngle: CGFloat = 20 * .pi / 180
    /// Raspon nagiba: min i max u radijanima (npr. 5° do 60°).
    static let tiltMin: CGFloat = 5 * .pi / 180
    static let tiltMax: CGFloat = 60 * .pi / 180
    /// Koliko piksela se mapa pomakne po jednom pritisku tipke (WASD / strelice).
    var panSpeed: CGFloat = 28
    /// Minimalni zoom (faza 1 = 2.1).
    var zoomMin: CGFloat { ZoomPhase.zoomValues[0] }
    /// Maksimalni zoom (faza 4 = 38).
    var zoomMax: CGFloat { ZoomPhase.zoomValues[3] }
    /// Faza zooma 1–4 (1 stablo, 2, 3, šuma). Na početku 2.
    var zoomPhase: Int = 2
    /// Smjer za sljedeći klik (ping-pong: 2→3→4→3→2→1→2→…).
    var zoomDirectionUp: Bool = true
    /// Trenutni zoom – izveden iz zoomPhase (2.1, 14, 26, 38).
    var currentZoom: CGFloat = 14.0

    /// Postavi fazu 1–4 i ažurira currentZoom.
    mutating func setZoomPhase(_ phase: Int) {
        let p = min(4, max(1, phase))
        zoomPhase = p
        currentZoom = ZoomPhase.zoomValues[p - 1]
    }

    /// Jedan korak na gumb (ping-pong): 2→3→4→3→2→1→2→…
    mutating func stepZoomPhaseByClick() {
        if zoomDirectionUp {
            if zoomPhase < 4 {
                setZoomPhase(zoomPhase + 1)
            } else {
                setZoomPhase(3)
                zoomDirectionUp = false
            }
        } else {
            if zoomPhase > 1 {
                setZoomPhase(zoomPhase - 1)
            } else {
                setZoomPhase(2)
                zoomDirectionUp = true
            }
        }
    }

    /// Jedan korak scroll / +/- prema većem ili manjem zoomu.
    mutating func stepZoomPhaseByScroll(zoomIn: Bool) {
        if zoomIn {
            setZoomPhase(min(4, zoomPhase + 1))
            if zoomPhase == 4 { zoomDirectionUp = false }
        } else {
            setZoomPhase(max(1, zoomPhase - 1))
            if zoomPhase == 1 { zoomDirectionUp = true }
        }
    }
    /// Rotacija kamere u radijanima (0=N, π/2=E, π=S, 3π/2=W). Na početku π da kompas pokaže S.
    var mapRotation: CGFloat = .pi
    /// Pomak kamere (mapa ostaje na mjestu, kamera se pomiče) – u pikselima.
    var panOffset: CGPoint = .zero
}
