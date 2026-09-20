import Foundation

/// Persistent bottle library. One folder per bottle: `<store>/<name>/bottle.plist` + Wine prefix.
public struct BottleStore {
    public var root: URL
    public var fileManager: FileManager

    public init(root: URL, fileManager: FileManager = .default) {
        self.root = root
        self.fileManager = fileManager
    }

    public enum StoreError: Error, Equatable {
        case alreadyExists(String)
        case notFound(String)
        case corrupt(String)
        case runtimeTooOld(bottle: String, bottleWine: String, currentWine: String)
    }

    private func dir(for name: String) -> URL { root.appendingPathComponent(name, isDirectory: true) }
    private func plist(for name: String) -> URL { dir(for: name).appendingPathComponent("bottle.plist") }
    public func prefix(for name: String) -> URL { dir(for: name).appendingPathComponent("prefix", isDirectory: true) }

    @discardableResult
    public func create(name: String, wineVersion: String,
                       backend: GraphicsBackend = .wined3d) throws -> Bottle {
        guard !fileManager.fileExists(atPath: dir(for: name).path) else {
            throw StoreError.alreadyExists(name)
        }
        try fileManager.createDirectory(at: prefix(for: name), withIntermediateDirectories: true)
        let bottle = Bottle(name: name, url: prefix(for: name),
                            wineVersion: wineVersion, backend: backend)
        try save(bottle)
        return bottle
    }

    public func save(_ bottle: Bottle) throws {
        let data = try PropertyListEncoder().encode(bottle)
        try data.write(to: plist(for: bottle.name), options: .atomic)
    }

    /// Loads a bottle, refusing prefixes stamped by a NEWER Wine (downgrade corruption rule).
    public func open(name: String, currentWineVersion: String) throws -> Bottle {
        let bottle = try load(name: name)
        if bottle.wineVersion.compare(currentWineVersion, options: .numeric) == .orderedDescending {
            throw StoreError.runtimeTooOld(bottle: name, bottleWine: bottle.wineVersion,
                                           currentWine: currentWineVersion)
        }
        return bottle
    }

    private func load(name: String) throws -> Bottle {
        guard fileManager.fileExists(atPath: plist(for: name).path) else {
            throw StoreError.notFound(name)
        }
        let data = try Data(contentsOf: plist(for: name))
        guard let bottle = try? PropertyListDecoder().decode(Bottle.self, from: data) else {
            throw StoreError.corrupt(name)
        }
        return bottle
    }

    public func list() throws -> [String] {
        guard fileManager.fileExists(atPath: root.path) else { return [] }
        return try fileManager.contentsOfDirectory(atPath: root.path).sorted()
    }

    public func delete(name: String) throws {
        guard fileManager.fileExists(atPath: dir(for: name).path) else {
            throw StoreError.notFound(name)
        }
        try fileManager.removeItem(at: dir(for: name))
    }

    public func duplicate(name: String, as newName: String) throws {
        guard fileManager.fileExists(atPath: dir(for: name).path) else {
            throw StoreError.notFound(name)
        }
        guard !fileManager.fileExists(atPath: dir(for: newName).path) else {
            throw StoreError.alreadyExists(newName)
        }
        try fileManager.copyItem(at: dir(for: name), to: dir(for: newName))
        var bottle = try load(name: newName)
        bottle.name = newName
        bottle.url = prefix(for: newName)
        try save(bottle)
    }
}
