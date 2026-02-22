//
//  MapCameraSettings.swift
//  Feudalism
//
//  Postavke kamere na mapi – zoom, nagib, brzina pomicanja. Mijenjaju se u Postavkama.
//

import Foundation
import CoreGraphics

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
    /// Minimalni zoom – kad zumiraš maksimalno van, cijela mapa stane na ekran.
    var zoomMin: CGFloat = 0.01
    /// Maksimalni zoom – praktički bez gornje granice.
    var zoomMax: CGFloat = 50
    /// Korak zoomiranja (npr. scroll ili +/-).
    var zoomStep: CGFloat = 0.15
    /// Trenutni zoom (slider i tipke +/- ga mijenjaju). 1.0 = cijela mapa.
    var currentZoom: CGFloat = 1.0
    /// Rotacija mape u radijanima (0 = sjever gore; pozitivno = u smjeru kazaljke).
    var mapRotation: CGFloat = 0
    /// Pomak kamere (mapa ostaje na mjestu, kamera se pomiče) – u pikselima.
    var panOffset: CGPoint = .zero
}
