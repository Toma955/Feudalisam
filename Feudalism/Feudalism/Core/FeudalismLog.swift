//
//  FeudalismLog.swift
//  Feudalism
//
//  Ispis na sve načine: os_log (Xcode + Console.app), stdout, stderr, datoteka.
//

import Foundation
import os.log

enum FeudalismLog {
    private static let prefix = "[Feudalism] "
    private static let osLog = OSLog(subsystem: Bundle.main.bundleIdentifier ?? "Feudalism", category: "App")

    /// Datoteka u Application Support – otvori: open ~/Library/Application\ Support/Feudalism/feudalism_log.txt
    static var logFileURL: URL? {
        guard let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else { return nil }
        let feudalism = dir.appendingPathComponent("Feudalism", isDirectory: true)
        try? FileManager.default.createDirectory(at: feudalism, withIntermediateDirectories: true)
        return feudalism.appendingPathComponent("feudalism_log.txt")
    }

    /// Ispiši poruku na sve načine da se sigurno vidi u Xcode konzoli.
    static func log(_ message: String) {
        let line = "\(prefix)\(message)"

        // 1) os_log – najčešće se vidi u Xcode Debug Area (View → Debug Area → Activate Console, filter "All Output")
        os_log("%{public}@", log: osLog, type: .default, line)

        // 2) stdout + flush (print ide na stdout, ali ga flushamo)
        fputs(line + "\n", stdout)
        fflush(stdout)

        // 3) stderr + flush
        fputs(line + "\n", stderr)
        fflush(stderr)

        // 4) datoteka – ako ništa od gore ne vidiš, otvori log datoteku
        if let url = logFileURL {
            let data = (line + "\n").data(using: .utf8) ?? Data()
            if FileManager.default.fileExists(atPath: url.path) {
                if let h = try? FileHandle(forWritingTo: url) {
                    h.seekToEndOfFile()
                    h.write(data)
                    try? h.close()
                }
            } else {
                try? data.write(to: url)
            }
        }
    }
}
