import NetworkExtension
import Foundation
import os.log

// Imports for the two XCFrameworks you'll add to this target:
//
//   XrayKit:        gomobile-built wrapper around xtls/xray-core
//                   Exported funcs:  Xraykit.XraykitStart(_:), .XraykitStop(), .XraykitVersion()
//   Tun2SocksKit:   any tun2socks port; the canonical iOS one (eycorsican/leaf / hev-socks5-tunnel)
//                   exposes a `Socks5Tunnel.run(withConfig:)` style API.
//
// We import them defensively so the file at least *parses* before the
// frameworks are linked in. Once you add them in Xcode, delete the stub
// conditional and uncomment the real imports.
#if canImport(XrayKit)
import XrayKit
#endif
#if canImport(Tun2SocksKit)
import Tun2SocksKit
#endif

final class PacketTunnelProvider: NEPacketTunnelProvider {

    private let log = OSLog(subsystem: "com.sabgames.V2RayVPNSabGames.PacketTunnel", category: "tunnel")

    override init() {
        super.init()
        // NSLog goes to syslog and always shows in Console.app without privacy
        // redaction — confirms the extension binary actually loaded.
        NSLog("[V2RaySabLab.PacketTunnel] init OK — extension loaded")
    }

    // MARK: - Lifecycle

    override func startTunnel(
        options: [String: NSObject]?,
        completionHandler: @escaping (Error?) -> Void
    ) {
        NSLog("[V2RaySabLab.PacketTunnel] startTunnel called")
        os_log("startTunnel", log: log, type: .info)

        // 1. Pull the Xray JSON config we stashed in providerConfiguration.
        guard
            let proto = self.protocolConfiguration as? NETunnelProviderProtocol,
            let provCfg = proto.providerConfiguration,
            let xrayJSON = provCfg["xrayConfig"] as? String
        else {
            NSLog("[V2RaySabLab.PacketTunnel] ERROR: missing xrayConfig in providerConfiguration")
            completionHandler(NSError(
                domain: "PacketTunnel",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Missing xrayConfig in providerConfiguration"]
            ))
            return
        }
        NSLog("[V2RaySabLab.PacketTunnel] got xrayConfig, %d bytes", xrayJSON.utf8.count)

        // 2. Configure the TUN device. 198.18.0.0/15 is reserved for benchmark
        //    use — clients use it as a "fake" tunnel subnet because it never
        //    collides with real LAN ranges.
        let settings = NEPacketTunnelNetworkSettings(tunnelRemoteAddress: "198.18.0.1")

        let ipv4 = NEIPv4Settings(addresses: ["198.18.0.1"], subnetMasks: ["255.255.0.0"])
        ipv4.includedRoutes = [NEIPv4Route.default()]
        ipv4.excludedRoutes = [
            // Don't route private LAN through the tunnel
            NEIPv4Route(destinationAddress: "10.0.0.0",    subnetMask: "255.0.0.0"),
            NEIPv4Route(destinationAddress: "172.16.0.0",  subnetMask: "255.240.0.0"),
            NEIPv4Route(destinationAddress: "192.168.0.0", subnetMask: "255.255.0.0"),
        ]
        settings.ipv4Settings = ipv4

        let dns = NEDNSSettings(servers: ["1.1.1.1", "8.8.8.8"])
        dns.matchDomains = [""]
        settings.dnsSettings = dns

        settings.mtu = 1500

        // 3. Apply network settings, then start engine + tun2socks.
        NSLog("[V2RaySabLab.PacketTunnel] applying network settings")
        setTunnelNetworkSettings(settings) { [weak self] error in
            guard let self else { return }
            if let error = error {
                NSLog("[V2RaySabLab.PacketTunnel] setTunnelNetworkSettings FAILED: %@", error.localizedDescription)
                completionHandler(error)
                return
            }
            NSLog("[V2RaySabLab.PacketTunnel] network settings applied OK")

            do {
                NSLog("[V2RaySabLab.PacketTunnel] starting Xray")
                try self.startXray(jsonConfig: xrayJSON)
                NSLog("[V2RaySabLab.PacketTunnel] Xray started, starting tun2socks")
                try self.startTun2Socks()
                NSLog("[V2RaySabLab.PacketTunnel] tunnel UP")
                completionHandler(nil)
            } catch {
                NSLog("[V2RaySabLab.PacketTunnel] tunnel start FAILED: %@", String(describing: error))
                self.stopXray()
                completionHandler(error)
            }
        }
    }

    override func stopTunnel(with reason: NEProviderStopReason, completionHandler: @escaping () -> Void) {
        os_log("stopTunnel reason=%{public}d", log: log, type: .info, reason.rawValue)
        stopTun2Socks()
        stopXray()
        completionHandler()
    }

    // MARK: - Xray

    private func startXray(jsonConfig: String) throws {
        #if canImport(XrayKit)
        var err: NSError?
        // gomobile-bound functions throw via an out NSError parameter.
        // The actual symbol name depends on gomobile's prefix rules — adjust
        // after the framework is built (often `XraykitStart`).
        XraykitStart(jsonConfig.data(using: .utf8), &err)
        if let err { throw err }
        #else
        throw NSError(
            domain: "PacketTunnel",
            code: 2,
            userInfo: [NSLocalizedDescriptionKey: "XrayKit.xcframework not linked — run Scripts/build-xraykit.sh"]
        )
        #endif
    }

    private func stopXray() {
        #if canImport(XrayKit)
        var err: NSError?
        XraykitStop(&err)
        #endif
    }

    // MARK: - tun2socks

    private func startTun2Socks() throws {
        #if canImport(Tun2SocksKit)
        // hev-socks5-tunnel YAML pointing at our SOCKS server.
        // misc.task-stack-size must be ≥ 81920 or the engine refuses to start.
        let yaml = """
        tunnel:
          mtu: 1500
          ipv4: 198.18.0.1
          ipv6: 'fc00::1'
          name: utun
        socks5:
          address: 127.0.0.1
          port: \(XrayLocalPorts.socksPort)
          udp: udp
        misc:
          task-stack-size: 81920
          log-level: warn
        """
        Socks5Tunnel.run(withConfig: .string(content: yaml)) { rc in
            // rc != 0 means the engine exited with an error. We can't surface
            // it back through startTunnel's completionHandler from here because
            // run() is asynchronous; log and let iOS tear us down on disconnect.
            os_log("tun2socks exited rc=%{public}d", log: OSLog(subsystem: "com.sabgames.V2RayVPNSabGames.PacketTunnel", category: "tun2socks"), type: .error, rc)
        }
        #else
        throw NSError(
            domain: "PacketTunnel",
            code: 4,
            userInfo: [NSLocalizedDescriptionKey: "Tun2SocksKit.xcframework not linked"]
        )
        #endif
    }

    private func stopTun2Socks() {
        #if canImport(Tun2SocksKit)
        Socks5Tunnel.quit()
        #endif
    }
}

// XrayLocalPorts is defined in the main app's XrayConfigBuilder.swift.
// Add a copy here when you create the PacketTunnel target so the extension
// doesn't depend on app-target code.
fileprivate enum XrayLocalPorts {
    static let socksPort: Int = 10808
}
