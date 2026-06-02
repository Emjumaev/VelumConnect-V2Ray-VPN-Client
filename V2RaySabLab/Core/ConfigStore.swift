import Foundation
import Combine

/// A VLESS configuration the user has saved.
/// We persist the raw URL string (canonical source of truth) plus a few
/// already-parsed fields for cheap display in the list row.
struct SavedConfig: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var url: String

    // Parsed for display only — the engine always re-parses from `url`.
    var network: String
    var security: String
    var address: String
    var port: Int

    /// "VLESS / XHTTP" or "VLESS / WS" — used by the row subtitle.
    var transportLabel: String {
        "VLESS / \(network.uppercased())"
    }
}

/// Persists the user's list of VLESS configs + which one is currently selected.
/// Backed by UserDefaults (small JSON blob; we never store more than a handful).
@MainActor
final class ConfigStore: ObservableObject {

    @Published private(set) var configs: [SavedConfig] = []
    @Published var selectedID: SavedConfig.ID?

    private let configsKey = "v2raysablab.configs"
    private let selectedKey = "v2raysablab.selectedConfigID"

    init() {
        load()
    }

    // MARK: - Derived

    var selected: SavedConfig? {
        guard let id = selectedID else { return configs.first }
        return configs.first(where: { $0.id == id }) ?? configs.first
    }

    // MARK: - Mutations

    /// Parse and append a VLESS URL. Throws if the URL is malformed so the
    /// caller can show the error inline.
    @discardableResult
    func addFromURL(_ raw: String) throws -> SavedConfig {
        let parsed = try VLESSConfig.parse(raw)
        let displayName = parsed.remark.isEmpty
            ? "\(parsed.address):\(parsed.port)"
            : parsed.remark

        let saved = SavedConfig(
            id: UUID(),
            name: displayName,
            url: raw,
            network: parsed.network,
            security: parsed.security,
            address: parsed.address,
            port: parsed.port
        )
        configs.append(saved)
        if selectedID == nil { selectedID = saved.id }
        persist()
        return saved
    }

    func delete(_ id: SavedConfig.ID) {
        configs.removeAll { $0.id == id }
        if selectedID == id { selectedID = configs.first?.id }
        persist()
    }

    func select(_ id: SavedConfig.ID) {
        guard configs.contains(where: { $0.id == id }) else { return }
        selectedID = id
        persist()
    }

    // MARK: - Persistence

    private func persist() {
        let enc = JSONEncoder()
        if let data = try? enc.encode(configs) {
            UserDefaults.standard.set(data, forKey: configsKey)
        }
        if let id = selectedID {
            UserDefaults.standard.set(id.uuidString, forKey: selectedKey)
        } else {
            UserDefaults.standard.removeObject(forKey: selectedKey)
        }
    }

    private func load() {
        let dec = JSONDecoder()
        if let data = UserDefaults.standard.data(forKey: configsKey),
           let arr = try? dec.decode([SavedConfig].self, from: data) {
            configs = arr
        }
        if let str = UserDefaults.standard.string(forKey: selectedKey),
           let id = UUID(uuidString: str) {
            selectedID = id
        }
    }
}
