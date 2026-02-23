//
//  LocalizedStrings.swift
//  Feudalism
//
//  Učitava stringove iz Locales/{jezik}.json (npr. Locales/hr.json). Jedna datoteka po jeziku – bez duplikata imena.
//

import Foundation

enum LocalizedStrings {
    private static var cache: [String: [String: String]] = [:]
    private static let queue = DispatchQueue(label: "Feudalism.LocalizedStrings", attributes: .concurrent)

    /// Vraća lokalizirani string za ključ i jezik. Fallback: prvo hrvatski, pa engleski, pa ključ.
    static func string(for key: String, language: AppLanguage) -> String {
        let dict = loadStrings(for: language)
        if let value = dict[key], !value.isEmpty { return value }
        if language != .croatian {
            let hrDict = loadStrings(for: .croatian)
            if let value = hrDict[key], !value.isEmpty { return value }
        }
        if language != .english {
            let enDict = loadStrings(for: .english)
            if let value = enDict[key], !value.isEmpty { return value }
        }
        return key
    }

    private static func loadStrings(for language: AppLanguage) -> [String: String] {
        var result: [String: String]?
        queue.sync {
            let langKey = language.rawValue
            if let cached = cache[langKey] {
                result = cached
                return
            }
            let candidates: [(resource: String, subdirectory: String?)] = [
                (langKey, "Locales"),
                (langKey, "Feudalism/Locales"),
                (langKey, nil)
            ]
            var url: URL?
            for (resource, subdir) in candidates {
                url = Bundle.main.url(forResource: resource, withExtension: "json", subdirectory: subdir)
                if url != nil { break }
            }
            guard let resolvedURL = url,
                  let data = try? Data(contentsOf: resolvedURL),
                  let dict = try? JSONDecoder().decode([String: String].self, from: data) else {
                result = [:]
                cache[langKey] = [:]
                return
            }
            cache[langKey] = dict
            result = dict
        }
        return result ?? [:]
    }

    /// Za SwiftUI: osvježi cache ako je datoteka promijenjena (npr. nakon uređivanja u editoru).
    static func clearCache() {
        queue.async(flags: .barrier) { cache.removeAll() }
    }
}
