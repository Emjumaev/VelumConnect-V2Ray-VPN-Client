import Foundation

/// Local proxy ports the PacketTunnel extension binds to inside the process.
/// tun2socks forwards TUN packets to socksPort.
enum XrayLocalPorts {
    static let socksPort: Int = 10808
    static let httpPort: Int  = 10809
    static let dnsPort: Int   = 10853
}

enum XrayConfigBuilder {
    /// Build a JSON config bytes blob that Xray-core can consume.
    static func buildJSON(for cfg: VLESSConfig) throws -> Data {
        let root = buildRoot(cfg: cfg)
        return try JSONSerialization.data(
            withJSONObject: root,
            options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        )
    }

    static func buildString(for cfg: VLESSConfig) throws -> String {
        let data = try buildJSON(for: cfg)
        return String(decoding: data, as: UTF8.self)
    }

    // MARK: - Top-level

    private static func buildRoot(cfg: VLESSConfig) -> [String: Any] {
        return [
            "log": ["loglevel": "warning"],
            "dns": dns(),
            "inbounds": [socksInbound(), httpInbound()],
            "outbounds": [vlessOutbound(cfg), directOutbound(), blockOutbound()],
            "routing": routing()
        ]
    }

    private static func dns() -> [String: Any] {
        return [
            "servers": ["1.1.1.1", "8.8.8.8"]
        ]
    }

    private static func socksInbound() -> [String: Any] {
        return [
            "tag": "socks-in",
            "listen": "127.0.0.1",
            "port": XrayLocalPorts.socksPort,
            "protocol": "socks",
            "settings": [
                "auth": "noauth",
                "udp": true,
                "userLevel": 0
            ],
            "sniffing": [
                "enabled": true,
                "destOverride": ["http", "tls", "quic"],
                "routeOnly": false
            ]
        ]
    }

    private static func httpInbound() -> [String: Any] {
        return [
            "tag": "http-in",
            "listen": "127.0.0.1",
            "port": XrayLocalPorts.httpPort,
            "protocol": "http",
            "settings": ["userLevel": 0]
        ]
    }

    // MARK: - Outbounds

    private static func vlessOutbound(_ cfg: VLESSConfig) -> [String: Any] {
        var user: [String: Any] = [
            "id": cfg.uuid,
            "encryption": cfg.encryption.isEmpty ? "none" : cfg.encryption,
            "level": 0
        ]
        if let flow = cfg.flow, !flow.isEmpty {
            user["flow"] = flow
        }

        let settings: [String: Any] = [
            "vnext": [[
                "address": cfg.address,
                "port": cfg.port,
                "users": [user]
            ]]
        ]

        return [
            "tag": "proxy",
            "protocol": "vless",
            "settings": settings,
            "streamSettings": streamSettings(cfg)
        ]
    }

    private static func directOutbound() -> [String: Any] {
        return ["tag": "direct", "protocol": "freedom", "settings": [:] as [String: Any]]
    }

    private static func blockOutbound() -> [String: Any] {
        return ["tag": "block", "protocol": "blackhole", "settings": [:] as [String: Any]]
    }

    // MARK: - streamSettings (transport + security)

    private static func streamSettings(_ cfg: VLESSConfig) -> [String: Any] {
        var s: [String: Any] = [
            "network": cfg.network,
            "security": cfg.security
        ]

        switch cfg.security.lowercased() {
        case "reality":
            s["realitySettings"] = realitySettings(cfg)
        case "tls":
            s["tlsSettings"] = tlsSettings(cfg)
        default:
            break
        }

        switch cfg.network.lowercased() {
        case "xhttp", "splithttp":
            s["xhttpSettings"] = xhttpSettings(cfg)
        case "ws":
            s["wsSettings"] = wsSettings(cfg)
        case "grpc":
            s["grpcSettings"] = grpcSettings(cfg)
        case "tcp":
            if let h = cfg.headerType, h != "none" {
                s["tcpSettings"] = ["header": ["type": h]]
            }
        default:
            break
        }

        return s
    }

    private static func realitySettings(_ cfg: VLESSConfig) -> [String: Any] {
        var r: [String: Any] = [
            "show": false,
            "fingerprint": cfg.fingerprint ?? "chrome",
            "serverName": cfg.sni ?? "",
            "publicKey": cfg.publicKey ?? "",
            "shortId": cfg.shortID ?? "",
            "spiderX": cfg.spiderX ?? "/"
        ]
        if !cfg.alpn.isEmpty { r["alpn"] = cfg.alpn }
        return r
    }

    private static func tlsSettings(_ cfg: VLESSConfig) -> [String: Any] {
        var t: [String: Any] = [
            "allowInsecure": false,
            "serverName": cfg.sni ?? cfg.address,
            "fingerprint": cfg.fingerprint ?? "chrome"
        ]
        if !cfg.alpn.isEmpty { t["alpn"] = cfg.alpn }
        return t
    }

    private static func xhttpSettings(_ cfg: VLESSConfig) -> [String: Any] {
        var x: [String: Any] = [
            "path": cfg.path ?? "/",
            "mode": cfg.mode ?? "auto"
        ]
        if let h = cfg.host, !h.isEmpty { x["host"] = h }
        return x
    }

    private static func wsSettings(_ cfg: VLESSConfig) -> [String: Any] {
        var w: [String: Any] = ["path": cfg.path ?? "/"]
        if let h = cfg.host, !h.isEmpty {
            w["headers"] = ["Host": h]
        }
        return w
    }

    private static func grpcSettings(_ cfg: VLESSConfig) -> [String: Any] {
        return [
            "serviceName": cfg.serviceName ?? "",
            "multiMode": false
        ]
    }

    // MARK: - Routing

    private static func routing() -> [String: Any] {
        // Note: we deliberately avoid `geoip:` and `geosite:` rules because
        // those require geoip.dat / geosite.dat to be bundled with the
        // extension. We ship a minimal extension to stay under iOS's 50MB
        // packet-tunnel-provider memory limit, so we hard-code private CIDRs
        // for the direct rule. The NEPacketTunnelNetworkSettings layer also
        // excludes these ranges at the TUN level — this is belt-and-suspenders.
        return [
            "domainStrategy": "AsIs",
            "rules": [
                [
                    "type": "field",
                    "ip": [
                        "10.0.0.0/8",
                        "172.16.0.0/12",
                        "192.168.0.0/16",
                        "127.0.0.0/8",
                        "169.254.0.0/16",
                        "::1/128",
                        "fc00::/7",
                        "fe80::/10"
                    ],
                    "outboundTag": "direct"
                ],
                [
                    "type": "field",
                    "network": "tcp,udp",
                    "outboundTag": "proxy"
                ]
            ]
        ]
    }
}
