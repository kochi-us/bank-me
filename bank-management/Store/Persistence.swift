//
//  Persistence.swift
//  bank-management
//
//  Created by KOCHI HASHIMOTO on 2025/10/27.
//

import Foundation

enum Persistence {
    static var baseDir: URL = {
        let fm = FileManager.default
        let dir = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(Bundle.main.bundleIdentifier ?? "bank-management", isDirectory: true)
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    static func url(_ name: String) -> URL {
        baseDir.appendingPathComponent(name)
    }

    static func save<T: Encodable>(_ value: T, as name: String) {
        do {
            let data = try JSONEncoder().encode(value)
            try data.write(to: url(name), options: [.atomic])
            print("✅ Saved \(name)")
        } catch {
            print("❌ Save failed (\(name)):", error)
        }
    }

    static func load<T: Decodable>(_ type: T.Type, from name: String, default defaultValue: T) -> T {
        let u = url(name)
        guard let data = try? Data(contentsOf: u) else { return defaultValue }
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            print("⚠️ Load failed (\(name)):", error)
            return defaultValue
        }
    }
}
