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

/// Jedna točka za placement debug poruke: ide i u Xcode konzolu i u in-app konzolu.
func placementDebugLog(_ message: String) {
    let line = "[PlacementDebug] \(message)"
    print(line)
    Task { @MainActor in
        PlacementDebugConsole.shared.append(line)
    }
}
