import Foundation

struct VLESSConfig: Equatable {
    var uuid: String
    var address: String
    var port: Int
    var remark: String

    var network: String       // type=  (xhttp, tcp, ws, grpc, ...)
    var security: String      // security=  (reality, tls, none)
    var encryption: String    // encryption= (vless: usually "none")
    var flow: String?         // flow= (e.g. xtls-rprx-vision)

    // TLS / Reality
    var sni: String?          // sni=
    var fingerprint: String?  // fp=  (chrome, firefox, ...)
    var publicKey: String?    // pbk= (reality)
    var shortID: String?      // sid= (reality)
    var spiderX: String?      // spx= (reality)
    var alpn: [String]        // alpn=  (h2,http/1.1)

    // Transport-specific
    var path: String?         // path=
    var host: String?         // host=
    var serviceName: String?  // serviceName=  (grpc)
    var mode: String?         // mode=  (auto, packet-up, stream-up — xhttp)
    var headerType: String?   // headerType=  (tcp)
}

enum VLESSParseError: Error, CustomStringConvertible {
    case notVLESS
    case malformedURL
    case missingUUID
    case missingHost
    case missingPort

    var description: String {
        switch self {
        case .notVLESS:     return "Not a vless:// URL"
        case .malformedURL: return "Malformed VLESS URL"
        case .missingUUID:  return "VLESS URL missing UUID"
        case .missingHost:  return "VLESS URL missing host"
        case .missingPort:  return "VLESS URL missing port"
        }
    }
}

extension VLESSConfig {
    /// Parses a vless://uuid@host:port/?type=...&security=...#remark URL.
    /// Strict-ish: we accept missing query params (defaulted) but require uuid/host/port.
    static func parse(_ raw: String) throws -> VLESSConfig {
        // URLComponents won't parse the userinfo of a non-standard scheme reliably,
        // so we do the front part by hand and let URLComponents handle query + fragment.
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let schemePrefix = "vless://"
        guard trimmed.lowercased().hasPrefix(schemePrefix) else {
            throw VLESSParseError.notVLESS
        }
        let body = String(trimmed.dropFirst(schemePrefix.count))

        // Split off fragment (#remark) ourselves — fragment is allowed to contain
        // percent-encoded UTF-8.
        let fragment: String
        let beforeFragment: String
        if let hashIdx = body.firstIndex(of: "#") {
            fragment = String(body[body.index(after: hashIdx)...])
            beforeFragment = String(body[..<hashIdx])
        } else {
            fragment = ""
            beforeFragment = body
        }

        // Split off query (?...)
        let queryString: String
        let beforeQuery: String
        if let qIdx = beforeFragment.firstIndex(of: "?") {
            queryString = String(beforeFragment[beforeFragment.index(after: qIdx)...])
            beforeQuery = String(beforeFragment[..<qIdx])
        } else {
            queryString = ""
            beforeQuery = beforeFragment
        }

        // beforeQuery now looks like: uuid@host:port  OR  uuid@host:port/
        let userHost = beforeQuery.hasSuffix("/")
            ? String(beforeQuery.dropLast())
            : beforeQuery

        guard let atIdx = userHost.firstIndex(of: "@") else {
            throw VLESSParseError.malformedURL
        }
        let uuid = String(userHost[..<atIdx])
        guard !uuid.isEmpty else { throw VLESSParseError.missingUUID }

        let hostPort = String(userHost[userHost.index(after: atIdx)...])
        // Host may be IPv6 in brackets [::1]:443
        let host: String
        let portStr: String
        if hostPort.hasPrefix("[") {
            guard let rbracket = hostPort.firstIndex(of: "]") else {
                throw VLESSParseError.malformedURL
            }
            host = String(hostPort[hostPort.index(after: hostPort.startIndex)..<rbracket])
            let afterBracket = hostPort.index(after: rbracket)
            guard afterBracket < hostPort.endIndex, hostPort[afterBracket] == ":" else {
                throw VLESSParseError.missingPort
            }
            portStr = String(hostPort[hostPort.index(after: afterBracket)...])
        } else {
            guard let colonIdx = hostPort.lastIndex(of: ":") else {
                throw VLESSParseError.missingPort
            }
            host = String(hostPort[..<colonIdx])
            portStr = String(hostPort[hostPort.index(after: colonIdx)...])
        }
        guard !host.isEmpty else { throw VLESSParseError.missingHost }
        guard let port = Int(portStr), (1...65535).contains(port) else {
            throw VLESSParseError.missingPort
        }

        let query = Self.parseQuery(queryString)
        let remark = Self.percentDecode(fragment)

        return VLESSConfig(
            uuid: uuid,
            address: host,
            port: port,
            remark: remark,
            network: query["type"] ?? "tcp",
            security: query["security"] ?? "none",
            encryption: query["encryption"] ?? "none",
            flow: query["flow"],
            sni: query["sni"],
            fingerprint: query["fp"],
            publicKey: query["pbk"],
            shortID: query["sid"],
            spiderX: query["spx"],
            alpn: (query["alpn"] ?? "")
                .split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty },
            path: query["path"],
            host: query["host"],
            serviceName: query["serviceName"],
            mode: query["mode"],
            headerType: query["headerType"]
        )
    }

    private static func parseQuery(_ s: String) -> [String: String] {
        guard !s.isEmpty else { return [:] }
        var out: [String: String] = [:]
        for pair in s.split(separator: "&") {
            let parts = pair.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)
            let key = percentDecode(String(parts[0]))
            let val = parts.count > 1 ? percentDecode(String(parts[1])) : ""
            if !key.isEmpty { out[key] = val }
        }
        return out
    }

    private static func percentDecode(_ s: String) -> String {
        s.removingPercentEncoding ?? s
    }
}
