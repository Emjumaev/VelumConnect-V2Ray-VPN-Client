import Foundation
import NetworkExtension
import Combine
import os.log

/// Single source of truth for VPN state in the main app.
/// Wraps NETunnelProviderManager so the UI just observes `state` and `elapsed`.
@MainActor
final class TunnelManager: ObservableObject {

    enum State {
        case disconnected
        case connecting
        case connected
        case disconnecting
        case invalid          // entitlement / profile not installed yet
        case error(String)
    }

    @Published private(set) var state: State = .disconnected
    @Published private(set) var elapsed: TimeInterval = 0

    // The bundle id of your PacketTunnel extension target.
    // Must exactly match the PRODUCT_BUNDLE_IDENTIFIER of the extension.
    static let tunnelBundleID = "com.sabgames.V2RayVPNSabGames.PacketTunnel"

    private var manager: NETunnelProviderManager?
    private var statusObserver: NSObjectProtocol?
    private var connectedAt: Date?
    private var timer: Timer?
    private let log = OSLog(subsystem: "com.sabgames.V2RayVPNSabGames", category: "TunnelManager")
    #if targetEnvironment(simulator)
    private let isSimulator = true
    #else
    private let isSimulator = false
    #endif

    init() {
        Task { await load() }
        statusObserver = NotificationCenter.default.addObserver(
            forName: .NEVPNStatusDidChange,
            object: nil,
            queue: .main
        ) { [weak self] note in
            guard let conn = note.object as? NEVPNConnection else { return }
            let status = conn.status
            Task { @MainActor [weak self] in self?.handleStatus(status) }
        }
    }

    deinit {
        if let obs = statusObserver {
            NotificationCenter.default.removeObserver(obs)
        }
    }

    // MARK: - Public actions

    func toggle(vlessURL: String) async {
        switch state {
        case .connected, .connecting:
            await disconnect()
        default:
            await connect(vlessURL: vlessURL)
        }
    }

    func connect(vlessURL: String) async {
        if isSimulator {
            state = .error("Simulator can't run a PacketTunnel. Test on a real device.")
            os_log("connect aborted: running on simulator", log: log, type: .error)
            return
        }
        do {
            os_log("connect: parsing VLESS", log: log, type: .info)
            let cfg = try VLESSConfig.parse(vlessURL)
            let json = try XrayConfigBuilder.buildString(for: cfg)
            os_log("connect: installing profile", log: log, type: .info)
            try await install(remark: cfg.remark, configJSON: json)
            os_log("connect: calling startVPNTunnel", log: log, type: .info)
            try manager?.connection.startVPNTunnel()
        } catch {
            os_log("connect failed: %{public}@", log: log, type: .error, String(describing: error))
            state = .error(String(describing: error))
        }
    }

    func disconnect() async {
        manager?.connection.stopVPNTunnel()
    }

    // MARK: - Internal

    private func load() async {
        do {
            let all = try await NETunnelProviderManager.loadAllFromPreferences()
            manager = all.first
            if let m = manager {
                handleStatus(m.connection.status)
            } else {
                state = .disconnected
            }
        } catch {
            state = .error("load: \(error.localizedDescription)")
        }
    }

    private func install(remark: String, configJSON: String) async throws {
        let m = manager ?? NETunnelProviderManager()

        let proto = NETunnelProviderProtocol()
        proto.providerBundleIdentifier = Self.tunnelBundleID
        proto.serverAddress = "Xray"  // shown in iOS Settings → VPN
        proto.providerConfiguration = ["xrayConfig": configJSON]
        proto.disconnectOnSleep = false

        m.localizedDescription = "V2RaySabLab — \(remark)"
        m.protocolConfiguration = proto
        m.isEnabled = true

        try await m.saveToPreferences()
        try await m.loadFromPreferences()
        self.manager = m
    }

    private func handleStatus(_ status: NEVPNStatus) {
        os_log("status changed: %{public}d", log: log, type: .info, status.rawValue)
        switch status {
        case .invalid:
            state = .invalid
            stopTimer()
        case .disconnected:
            let wasConnecting: Bool
            if case .connecting = state { wasConnecting = true } else { wasConnecting = false }
            state = .disconnected
            stopTimer()
            if wasConnecting {
                // System killed the extension during startup. Ask iOS why
                // (iOS 16+ API; async, posts back to .error if we get a reason).
                fetchLastDisconnectReason()
            }
        case .connecting:
            state = .connecting
        case .connected:
            if connectedAt == nil { connectedAt = Date() }
            state = .connected
            startTimer()
        case .reasserting:
            state = .connecting
        case .disconnecting:
            state = .disconnecting
        @unknown default:
            state = .disconnected
        }
    }

    private func fetchLastDisconnectReason() {
        guard #available(iOS 16.0, *), let conn = manager?.connection else { return }
        conn.fetchLastDisconnectError { [weak self] error in
            guard let error else { return }
            Task { @MainActor [weak self] in
                self?.state = .error("disconnected: \(error.localizedDescription)")
                if let log = self?.log {
                    os_log("lastDisconnectError: %{public}@", log: log, type: .error, error.localizedDescription)
                }
            }
        }
    }

    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, let start = self.connectedAt else { return }
                self.elapsed = Date().timeIntervalSince(start)
            }
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
        connectedAt = nil
        elapsed = 0
    }
}
