import SwiftUI

struct ConnectView: View {
    @StateObject private var tunnel = TunnelManager()

    // v1: hardcoded test config. Replace with picker later.
    private let testVLESS = "vless://ea9e7820-9c62-4d0f-b130-cae04c8e3b8f@93.171.226.75:8443/?type=xhttp&encryption=none&path=%2F&host=&mode=auto&security=reality&pbk=ljHw_oQ_jvMeV7eiSxHmJZYSRgYRcJR2A3YgxzuFEXY&fp=chrome&sni=queue4.vk.com&sid=a41cf173&spx=%2F#vless-xhttp-reality-zxv6iqpn-TAS-2"

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 24) {
                Spacer()

                Text("Connection time")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.7))

                Text(formatTime(tunnel.elapsed))
                    .font(.system(size: 36, weight: .regular, design: .monospaced))
                    .foregroundStyle(.white)

                Button {
                    Task { await tunnel.toggle(vlessURL: testVLESS) }
                } label: {
                    ZStack {
                        Circle()
                            .fill(Color.white.opacity(0.08))
                            .frame(width: 130, height: 130)
                        Circle()
                            .fill(buttonColor)
                            .frame(width: 100, height: 100)
                        Image(systemName: "power")
                            .font(.system(size: 42, weight: .regular))
                            .foregroundStyle(.black)
                    }
                }
                .buttonStyle(.plain)

                Capsule()
                    .fill(Color.white.opacity(0.08))
                    .frame(height: 36)
                    .overlay(
                        HStack(spacing: 6) {
                            Text(statusLabel)
                                .font(.subheadline)
                                .foregroundStyle(.white)
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(buttonColor)
                        }
                        .padding(.horizontal, 16)
                    )
                    .fixedSize(horizontal: true, vertical: false)

                Spacer()

                VStack(alignment: .leading, spacing: 0) {
                    HStack {
                        Text("Configurations")
                            .font(.headline)
                            .foregroundStyle(.white)
                        Spacer()
                        Image(systemName: "chevron.down")
                            .foregroundStyle(.white.opacity(0.6))
                    }
                    .padding(16)
                    .background(Color.white.opacity(0.04))

                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("vless-xhttp-reality-zxv6iqpn-TAS-2")
                                .font(.subheadline)
                                .foregroundStyle(.white)
                                .lineLimit(1)
                            Text("VLESS / XHTTP")
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.7))
                        }
                        Spacer()
                    }
                    .padding(16)
                    .background(buttonColor)
                }
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .padding(.horizontal, 16)

                Spacer().frame(height: 80)
            }
        }
    }

    private var buttonColor: Color {
        switch tunnel.state {
        case .connected:    return .green
        case .connecting, .disconnecting: return .orange
        case .error:        return .red
        default:            return Color(red: 0.35, green: 0.6, blue: 1.0)
        }
    }

    private var statusLabel: String {
        switch tunnel.state {
        case .disconnected:  return "Disconnected"
        case .connecting:    return "Connecting…"
        case .connected:     return "Connected"
        case .disconnecting: return "Disconnecting…"
        case .invalid:       return "Install profile"
        case .error(let m):  return "Error: \(m)"
        }
    }

    private func formatTime(_ t: TimeInterval) -> String {
        let s = Int(t)
        return String(format: "%02d:%02d:%02d", s / 3600, (s / 60) % 60, s % 60)
    }
}

#Preview {
    ConnectView()
}
