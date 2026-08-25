# Velum Connect (V2RaySabLab)

An iOS VPN client built on [Xray-core](https://github.com/XTLS/Xray-core), supporting the VLESS protocol with REALITY, TLS, and multiple transports (XHTTP, TCP, WebSocket, gRPC).

[**Download on the App Store**](https://apps.apple.com/app/velum-connect/id6775802605)

## How it works

The app is a native Swift (SwiftUI/UIKit) client that runs Xray-core inside a Network Extension:

1. **XrayKit** — a thin Go wrapper around Xray-core (`XrayKit/xraykit.go`), compiled into an `XCFramework` with `gomobile bind`. It exposes a minimal Swift-callable API: `Start(configJSON)`, `Stop()`, `Version()`. A slim distro registration (`distro_slim.go`) includes only the protocols/transports the app uses, keeping the binary within the `NEPacketTunnelProvider` 50 MB memory limit.
2. **PacketTunnel** — an `NEPacketTunnelProvider` app extension that receives the Xray JSON config from the main app, starts Xray-core (which binds local SOCKS/HTTP proxies on `127.0.0.1:10808/10809`), and forwards TUN packets to the SOCKS port via tun2socks.
3. **Main app** — parses `vless://` URLs (typed, pasted, or scanned via QR code), builds the Xray config JSON, and manages the tunnel through `NETunnelProviderManager`.

## Features

- VLESS with REALITY, TLS, or no security; `xtls-rprx-vision` flow support
- Transports: XHTTP, TCP, WebSocket, gRPC
- Import configs via `vless://` URL or QR code scanning
- Localized UI: English, Русский, O‘zbek
- Privacy disclosure and consent screen (App Store Guideline 5.4)

## Project structure

| Path | Purpose |
|---|---|
| `V2RaySabLab/` | Main app target — UI, config parsing, tunnel management |
| `V2RaySabLab/Core/` | `VLESSConfig` (URL parser), `XrayConfigBuilder`, `TunnelManager`, `ConfigStore`, `Localization` |
| `V2RaySabLab/UI/` | `ConnectView`, `AddConfigView`, `QRScannerView`, `PrivacyDisclosureView` |
| `PacketTunnel/` | Network Extension (`NEPacketTunnelProvider`) that runs Xray-core + tun2socks |
| `XrayKit/` | Go source for the gomobile Xray-core wrapper |
| `Frameworks/` | Prebuilt `XrayKit.xcframework` |
| `Scripts/` | `build-xraykit.sh` — rebuilds the XCFramework from Go source |

## Building

### Prerequisites

- Xcode with an Apple Developer account (Network Extension entitlement required)
- To rebuild XrayKit: Go and gomobile

```sh
brew install go
go install golang.org/x/mobile/cmd/gomobile@latest
go install golang.org/x/mobile/cmd/gobind@latest
export PATH="$PATH:$(go env GOPATH)/bin"
gomobile init
```

### Steps

1. (Optional) Rebuild the Xray-core framework:
   ```sh
   ./Scripts/build-xraykit.sh
   ```
   Output lands in `Frameworks/XrayKit.xcframework`.
2. Open `V2RaySabLab.xcodeproj` in Xcode.
3. Select your development team for both the app and PacketTunnel targets (both need Network Extension entitlements and a shared App Group).
4. Build and run on a physical device — Network Extensions do not work in the iOS Simulator.

## App Store

Velum Connect is available on the App Store:
https://apps.apple.com/app/velum-connect/id6775802605
