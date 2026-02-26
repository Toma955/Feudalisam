//
//  FeudalismLog.swift
//  Feudalism
//
//  Logovi: os_log, stdout, stderr, datoteka. Datoteka u Core/Logs/ unutar projekta (ako je dostupno), inače Application Support.
//

import Foundation
import os.log

enum FeudalismLog {
    private static let prefix = "[Feudalism] "
    private static let osLog = OSLog(subsystem: Bundle.main.bundleIdentifier ?? "Feudalism", category: "App")
    private static let logFileName = "feudalism_log.txt"
    private static let logsSubdir = "Logs"

    /// Root za log datoteku: prvo Core/Logs unutar projekta, pa Application Support/Feudalism/Logs.
    private static func logsDirectory() -> URL? {
        let fm = FileManager.default
        var candidates: [URL] = []
        if let projectDir = ProcessInfo.processInfo.environment["PROJECT_DIR"], !projectDir.isEmpty, !projectDir.contains("$(") {
            candidates.append(URL(fileURLWithPath: projectDir).appendingPathComponent("Feudalism", isDirectory: true).appendingPathComponent("Core", isDirectory: true).appendingPathComponent(logsSubdir, isDirectory: true))
            candidates.append(URL(fileURLWithPath: projectDir).appendingPathComponent("Core", isDirectory: true).appendingPathComponent(logsSubdir, isDirectory: true))
        }
        let cwd = fm.currentDirectoryPath
        if !cwd.isEmpty, cwd != "/" {
            candidates.append(URL(fileURLWithPath: cwd).appendingPathComponent("Feudalism", isDirectory: true).appendingPathComponent("Core", isDirectory: true).appendingPathComponent(logsSubdir, isDirectory: true))
            candidates.append(URL(fileURLWithPath: cwd).appendingPathComponent("Core", isDirectory: true).appendingPathComponent(logsSubdir, isDirectory: true))
        }
        for url in candidates {
            do {
                try fm.createDirectory(at: url, withIntermediateDirectories: true)
                return url
            } catch { continue }
        }
        guard let appSupport = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else { return nil }
        let fallback = appSupport.appendingPathComponent("Feudalism", isDirectory: true).appendingPathComponent(logsSubdir, isDirectory: true)
        try? fm.createDirectory(at: fallback, withIntermediateDirectories: true)
        return fallback
    }

    /// URL log datoteke (Core/Logs/feudalism_log.txt u projektu ako je dostupno).
    static var logFileURL: URL? {
        logsDirectory().map { $0.appendingPathComponent(logFileName) }
    }

    private static var didPrintLogPath = false

    /// Ispiši poruku na sve načine da se sigurno vidi u Xcode konzoli. Prvi put ispiše putanju log datoteke u konzolu.
    static func log(_ message: String) {
        let line = "\(prefix)\(message)"

        // 1) os_log – Xcode Debug Area (View → Debug Area → Activate Console)
        os_log("%{public}@", log: osLog, type: .default, line)

        // 2) stdout + flush
        fputs(line + "\n", stdout)
        fflush(stdout)

        // 3) stderr + flush
        fputs(line + "\n", stderr)
        fflush(stderr)

        // 4) datoteka + prvi put ispiši putanju u konzolu
        if let url = logFileURL {
            if !didPrintLogPath {
                didPrintLogPath = true
                fputs("\n>>> FEUDALISM LOG FILE: \(url.path) <<<\n", stdout)
                fflush(stdout)
            }
            let data = (line + "\n").data(using: .utf8) ?? Data()
            let parent = url.deletingLastPathComponent()
            do {
                try FileManager.default.createDirectory(at: parent, withIntermediateDirectories: true)
            } catch {
                fputs("[Feudalism] Ne mogu stvoriti Logs folder: \(parent.path) – \(error.localizedDescription)\n", stderr)
                fflush(stderr)
            }
            if FileManager.default.fileExists(atPath: url.path) {
                if let h = try? FileHandle(forWritingTo: url) {
                    h.seekToEndOfFile()
                    h.write(data)
                    try? h.close()
                } else {
                    fputs("[Feudalism] Ne mogu otvoriti log datoteku za pisanje: \(url.path)\n", stderr)
                    fflush(stderr)
                }
            } else {
                do {
                    try data.write(to: url)
                } catch {
                    fputs("[Feudalism] Ne mogu pisati log: \(url.path) – \(error.localizedDescription)\n", stderr)
                    fflush(stderr)
                }
            }
        } else {
            fputs("[Feudalism] Log file URL je nil – nijedan Logs folder nije dostupan za pisanje.\n", stderr)
            fflush(stderr)
        }
    }
}
