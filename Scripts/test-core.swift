// Standalone smoke test of VLESSConfig + XrayConfigBuilder.
// Build & run from repo root:
//   swiftc -parse-as-library -o /tmp/v2ray-core-test \
//     V2RaySabLab/Core/VLESSConfig.swift \
//     V2RaySabLab/Core/XrayConfigBuilder.swift \
//     Scripts/test-core.swift && /tmp/v2ray-core-test

import Foundation

@main
struct CoreTest {
    static func main() {
        let sample = "vless://ea9e7820-9c62-4d0f-b130-cae04c8e3b8f@93.171.226.75:8443/?type=xhttp&encryption=none&path=%2F&host=&mode=auto&security=reality&pbk=ljHw_oQ_jvMeV7eiSxHmJZYSRgYRcJR2A3YgxzuFEXY&fp=chrome&sni=queue4.vk.com&sid=a41cf173&spx=%2F#vless-xhttp-reality-zxv6iqpn-TAS-2"

        do {
            let cfg = try VLESSConfig.parse(sample)
            precondition(cfg.uuid == "ea9e7820-9c62-4d0f-b130-cae04c8e3b8f", "uuid")
            precondition(cfg.address == "93.171.226.75", "address")
            precondition(cfg.port == 8443, "port")
            precondition(cfg.network == "xhttp", "network")
            precondition(cfg.security == "reality", "security")
            precondition(cfg.encryption == "none", "encryption")
            precondition(cfg.sni == "queue4.vk.com", "sni")
            precondition(cfg.fingerprint == "chrome", "fp")
            precondition(cfg.publicKey == "ljHw_oQ_jvMeV7eiSxHmJZYSRgYRcJR2A3YgxzuFEXY", "pbk")
            precondition(cfg.shortID == "a41cf173", "sid")
            precondition(cfg.spiderX == "/", "spx")
            precondition(cfg.path == "/", "path")
            precondition(cfg.mode == "auto", "mode")
            precondition(cfg.remark == "vless-xhttp-reality-zxv6iqpn-TAS-2", "remark")
            print("OK parser")

            let json = try XrayConfigBuilder.buildString(for: cfg)
            precondition(json.contains("\"protocol\" : \"vless\""), "vless outbound")
            precondition(json.contains("\"network\" : \"xhttp\""), "xhttp transport")
            precondition(json.contains("\"security\" : \"reality\""), "reality security")
            precondition(json.contains("ljHw_oQ_jvMeV7eiSxHmJZYSRgYRcJR2A3YgxzuFEXY"), "pbk in JSON")
            precondition(json.contains("\"port\" : 10808"), "socks port")
            print("OK builder")
            print("---")
            print(json)
        } catch {
            print("FAIL: \(error)")
            exit(1)
        }
    }
}
