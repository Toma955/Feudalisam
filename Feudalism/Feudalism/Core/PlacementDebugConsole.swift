//
//  PlacementDebugConsole.swift
//  Feudalism
//
//  In-app konzola za placement debug (Solo mode).
//

import Foundation
import AppKit
import Combine

@MainActor
final class PlacementDebugConsole: ObservableObject {
    static let shared = PlacementDebugConsole()
    /// Kad false (zadano), placementDebugLog i mapEditorConsoleLog ne ispisuju ništa – konzola ostaje prazna. Nonisolated da ga placementDebugLog može čitati s bilo koje niti.
    nonisolated(unsafe) static var verbose: Bool = false

    @Published private(set) var lines: [String] = []
    private let maxLines = 600
    private let dateFormatter: DateFormatter

    private init() {
        let df = DateFormatter()
        df.dateFormat = "HH:mm:ss.SSS"
        dateFormatter = df
    }

    func append(_ message: String) {
        let ts = dateFormatter.string(from: Date())
        lines.append("[\(ts)] \(message)")
        if lines.count > maxLines {
            lines.removeFirst(lines.count - maxLines)
        }
    }

    func clear() {
        lines.removeAll(keepingCapacity: true)
    }

    func allText() -> String {
        lines.joined(separator: "\n")
    }

    func copyAllToPasteboard() {
        let text = allText()
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }
}

/// Jedna točka za placement debug poruke: ide i u Xcode konzolu i u in-app konzolu. Kad PlacementDebugConsole.verbose == false, ne ispisuje ništa.
func placementDebugLog(_ message: String) {
    guard PlacementDebugConsole.verbose else { return }
    let line = "[PlacementDebug] \(message)"
    print(line)
    Task { @MainActor in
        PlacementDebugConsole.shared.append(line)
    }
}

/// Poruke iz Map Editora (pan, hit test itd.): ispis u Xcode i u in-app konzolu. Kad PlacementDebugConsole.verbose == false, ne ispisuje ništa.
func mapEditorConsoleLog(_ message: String) {
    guard PlacementDebugConsole.verbose else { return }
    NSLog("%@", message)
    Task { @MainActor in
        PlacementDebugConsole.shared.append(message)
    }
}
