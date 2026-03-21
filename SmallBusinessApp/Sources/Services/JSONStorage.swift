import Foundation

final class JSONStorage {
    static let shared = JSONStorage()

    private let fileManager = FileManager.default
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private let baseURL: URL
    private let mediaURL: URL

    private init() {
        let supportDirectory = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        let bundleFolder = supportDirectory.appendingPathComponent(Bundle.main.bundleIdentifier ?? "SmallBusinessApp", isDirectory: true)
        if !fileManager.fileExists(atPath: bundleFolder.path) {
            try? fileManager.createDirectory(at: bundleFolder, withIntermediateDirectories: true)
        }
        baseURL = bundleFolder

        let mediaFolder = bundleFolder.appendingPathComponent("Media", isDirectory: true)
        if !fileManager.fileExists(atPath: mediaFolder.path) {
            try? fileManager.createDirectory(at: mediaFolder, withIntermediateDirectories: true)
        }
        mediaURL = mediaFolder

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        self.encoder = encoder

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder
    }

    func load<T: Decodable>(_ type: T.Type, fileName: String, defaultValue: T) -> T {
        let url = baseURL.appendingPathComponent(fileName)
        guard fileManager.fileExists(atPath: url.path) else {
            return defaultValue
        }

        do {
            let data = try Data(contentsOf: url)
            return try decoder.decode(type, from: data)
        } catch {
            return defaultValue
        }
    }

    func save<T: Encodable>(_ value: T, fileName: String) {
        let url = baseURL.appendingPathComponent(fileName)
        do {
            let data = try encoder.encode(value)
            try data.write(to: url, options: [.atomic])
        } catch {
            assertionFailure("Failed to save \(fileName): \(error.localizedDescription)")
        }
    }

    func remove(fileName: String) {
        let url = baseURL.appendingPathComponent(fileName)
        try? fileManager.removeItem(at: url)
    }

    func loadData(fileName: String) -> Data? {
        let url = mediaURL.appendingPathComponent(fileName)
        guard fileManager.fileExists(atPath: url.path) else {
            return nil
        }

        return try? Data(contentsOf: url)
    }

    func saveData(_ data: Data, fileName: String) throws {
        let url = mediaURL.appendingPathComponent(fileName)
        try data.write(to: url, options: [.atomic])
    }

    func removeData(fileName: String) {
        let url = mediaURL.appendingPathComponent(fileName)
        try? fileManager.removeItem(at: url)
    }
}
