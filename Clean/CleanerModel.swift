import Foundation
import Combine

nonisolated enum Kind: Hashable, Sendable {
    case app
    case cache
    case data
}

nonisolated struct AppItem: Identifiable, Sendable {
    let id: String
    let name: String
    let url: URL
    let appSize: Int64
    let cacheURLs: [URL]
    let cacheSize: Int64
    let dataURLs: [URL]
    let dataSize: Int64

    var total: Int64 { appSize + cacheSize + dataSize }

    func size(_ kind: Kind) -> Int64 {
        switch kind {
        case .app: return appSize
        case .cache: return cacheSize
        case .data: return dataSize
        }
    }

    func urls(_ kind: Kind) -> [URL] {
        switch kind {
        case .app: return [url]
        case .cache: return cacheURLs
        case .data: return dataURLs
        }
    }
}

nonisolated struct Refresh: Sendable {
    let id: String
    let item: AppItem?
}

nonisolated enum AppScanner {
    /// Every app installed in /Applications and ~/Applications.
    static func appURLs() -> [URL] {
        let fm = FileManager.default
        let folders = [
            URL(fileURLWithPath: "/Applications"),
            fm.homeDirectoryForCurrentUser.appendingPathComponent("Applications")
        ]
        var result = [URL]()
        for folder in folders {
            let items = (try? fm.contentsOfDirectory(
                at: folder,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            )) ?? []
            result += items.filter { $0.pathExtension == "app" }
        }
        return result
    }

    /// Allocated size of a file or of every file inside a folder.
    static func folderSize(_ url: URL) -> Int64 {
        let fm = FileManager.default
        var isDir: ObjCBool = false
        guard fm.fileExists(atPath: url.path, isDirectory: &isDir) else { return 0 }

        let keys: [URLResourceKey] = [.totalFileAllocatedSizeKey, .isRegularFileKey]

        if !isDir.boolValue {
            let values = try? url.resourceValues(forKeys: Set(keys))
            return Int64(values?.totalFileAllocatedSize ?? 0)
        }

        guard let enumerator = fm.enumerator(
            at: url,
            includingPropertiesForKeys: keys,
            options: [],
            errorHandler: { _, _ in true }
        ) else { return 0 }

        var total: Int64 = 0
        while let file = enumerator.nextObject() as? URL {
            guard let values = try? file.resourceValues(forKeys: Set(keys)),
                  values.isRegularFile == true else { continue }
            total += Int64(values.totalFileAllocatedSize ?? 0)
        }
        return total
    }

    /// Drops duplicates and paths that no longer exist.
    static func existing(_ urls: [URL]) -> [URL] {
        var seen = Set<String>()
        var result = [URL]()
        for url in urls {
            let key = url.path.lowercased()
            if seen.contains(key) { continue }
            if FileManager.default.fileExists(atPath: url.path) {
                seen.insert(key)
                result.append(url)
            }
        }
        return result
    }

    /// Reads an .app bundle and everything it left behind in ~/Library.
    static func makeItem(_ url: URL) -> AppItem? {
        guard let bundle = Bundle(url: url), let id = bundle.bundleIdentifier else { return nil }
        if id.hasPrefix("com.apple.") { return nil }

        var names = [url.deletingPathExtension().lastPathComponent]
        if let display = bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String,
           !display.isEmpty,
           !names.contains(display) {
            names.append(display)
        }
        if let short = bundle.object(forInfoDictionaryKey: "CFBundleName") as? String,
           !short.isEmpty,
           !names.contains(short) {
            names.append(short)
        }

        let keys = names + [id]
        let library = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library")

        func path(_ part: String) -> URL {
            library.appendingPathComponent(part)
        }

        var cache = [URL]()
        for key in keys {
            cache.append(path("Caches/" + key))
            cache.append(path("Logs/" + key))
        }
        cache.append(path("HTTPStorages/" + id))
        cache.append(path("Caches/" + id))

        var data = [URL]()
        for key in keys {
            data.append(path("Application Support/" + key))
        }
        data.append(path("Containers/" + id))
        data.append(path("Preferences/" + id + ".plist"))
        data.append(path("Saved Application State/" + id + ".savedState"))
        data.append(path("WebKit/" + id))

        let groupFolder = library.appendingPathComponent("Group Containers").path
        let groups = (try? FileManager.default.contentsOfDirectory(atPath: groupFolder)) ?? []
        for group in groups where group.contains(id) {
            data.append(path("Group Containers/" + group))
        }

        let cacheList = existing(cache)
        let dataList = existing(data)

        return AppItem(
            id: url.path,
            name: names[0],
            url: url,
            appSize: folderSize(url),
            cacheURLs: cacheList,
            cacheSize: cacheList.reduce(Int64(0)) { $0 + folderSize($1) },
            dataURLs: dataList,
            dataSize: dataList.reduce(Int64(0)) { $0 + folderSize($1) }
        )
    }
}

@MainActor
final class CleanerModel: ObservableObject {
    @Published var items = [AppItem]()
    @Published var selection = [String: Set<Kind>]()
    @Published var search = ""
    @Published var scanning = false
    @Published var deleting = false
    @Published var failed = 0

    var visible: [AppItem] {
        search.isEmpty ? items : items.filter { $0.name.localizedCaseInsensitiveContains(search) }
    }

    var selectedCount: Int {
        selection.values.reduce(0) { $0 + $1.count }
    }

    var selectedSize: Int64 {
        items.reduce(Int64(0)) { total, item in
            let kinds = selection[item.id] ?? []
            return total + kinds.reduce(Int64(0)) { $0 + item.size($1) }
        }
    }

    func isOn(_ id: String, _ kind: Kind) -> Bool {
        selection[id]?.contains(kind) ?? false
    }

    func toggle(_ id: String, _ kind: Kind) {
        var set = selection[id] ?? []
        if set.contains(kind) {
            set.remove(kind)
        } else {
            set.insert(kind)
        }
        selection[id] = set.isEmpty ? nil : set
    }

    func scan() {
        if scanning { return }
        scanning = true
        failed = 0
        items = []
        selection = [:]

        Task {
            let urls = await Task.detached { AppScanner.appURLs() }.value
            await withTaskGroup(of: AppItem?.self) { group in
                for url in urls {
                    group.addTask { AppScanner.makeItem(url) }
                }
                for await result in group {
                    if let item = result {
                        self.items.append(item)
                        self.items.sort { $0.total > $1.total }
                    }
                }
            }
            self.scanning = false
        }
    }

    func deleteSelected() {
        let chosen = selection
        let snapshot = items.filter { chosen[$0.id] != nil }
        guard !snapshot.isEmpty else { return }

        deleting = true
        failed = 0

        Task {
            let result = await Task.detached { () -> ([Refresh], Int) in
                var out = [Refresh]()
                var errors = 0
                for item in snapshot {
                    let kinds = chosen[item.id] ?? []
                    for kind in kinds {
                        for url in item.urls(kind) {
                            do {
                                try FileManager.default.trashItem(at: url, resultingItemURL: nil)
                            } catch {
                                errors += 1
                            }
                        }
                    }
                    out.append(Refresh(id: item.id, item: AppScanner.makeItem(item.url)))
                }
                return (out, errors)
            }.value

            for refresh in result.0 {
                if let index = self.items.firstIndex(where: { $0.id == refresh.id }) {
                    if let item = refresh.item {
                        self.items[index] = item
                    } else {
                        self.items.remove(at: index)
                    }
                }
            }
            self.items.sort { $0.total > $1.total }
            self.selection = [:]
            self.failed = result.1
            self.deleting = false
        }
    }
}
