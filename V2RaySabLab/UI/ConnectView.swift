import SwiftUI

struct ConnectView: View {
    @StateObject private var tunnel = TunnelManager()
    @StateObject private var store = ConfigStore()
    @StateObject private var lang = LanguageStore()

    @State private var addMode: AddConfigView.Mode?

    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()

            VStack(spacing: 0) {
                topBar
                    .padding(.horizontal, 16)
                    .padding(.top, 8)

                // Status block — natural height.
                VStack(spacing: 16) {
                    Text(L10n.t(.connectionTime, lang.language))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Text(formatTime(tunnel.elapsed))
                        .font(.system(size: 36, weight: .regular, design: .monospaced))
                        .foregroundStyle(.primary)

                    Button {
                        Task { await togglePower() }
                    } label: {
                        ZStack {
                            Circle().fill(Color.primary.opacity(0.08)).frame(width: 130, height: 130)
                            Circle().fill(buttonColor).frame(width: 100, height: 100)
                            Image(systemName: "power")
                                .font(.system(size: 42, weight: .regular))
                                .foregroundStyle(.white)
                        }
                    }
                    .buttonStyle(.plain)
                    .disabled(store.selected == nil)

                    HStack(spacing: 6) {
                        Text(statusLabel)
                            .font(.subheadline)
                            .foregroundStyle(.primary)
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.primary)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(Color.primary.opacity(0.08)))
                }
                .padding(.top, 16)
                .layoutPriority(1) // keep status block at its natural size

                Spacer(minLength: 16)

                // Configurations panel — takes the remaining space, scrolls internally.
                configsSection
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
        }
        .sheet(item: $addMode) { mode in
            AddConfigView(mode: mode, store: store)
                .environmentObject(lang)
        }
    }

    // MARK: - Top bar (language switcher + plus menu)

    private var topBar: some View {
        HStack {
            languageMenu
            Spacer()
            addMenu
        }
    }

    private var languageMenu: some View {
        Menu {
            Picker(L10n.t(.language, lang.language), selection: $lang.language) {
                ForEach(AppLanguage.allCases) { l in
                    Text("\(l.flag)  \(l.displayName)").tag(l)
                }
            }
        } label: {
            ZStack {
                Circle().fill(Color.primary.opacity(0.12)).frame(width: 36, height: 36)
                Text(lang.language.flag)
                    .font(.system(size: 18))
            }
        }
    }

    private var addMenu: some View {
        Menu {
            Button {
                addMode = .scanQR
            } label: {
                Label(L10n.t(.scanQR, lang.language), systemImage: "qrcode.viewfinder")
            }
            Button {
                addMode = .enterLink
            } label: {
                Label(L10n.t(.enterLink, lang.language), systemImage: "keyboard")
            }
            Button {
                addMode = .clipboard
            } label: {
                Label(L10n.t(.importClipboard, lang.language), systemImage: "doc.on.clipboard")
            }
        } label: {
            ZStack {
                Circle().fill(Color.primary.opacity(0.12)).frame(width: 36, height: 36)
                Image(systemName: "plus")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.primary)
            }
        }
    }

    // MARK: - Configs list

    private var configsSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(L10n.t(.configurations, lang.language))
                    .font(.headline)
                    .foregroundStyle(.primary)
                Spacer()
                Image(systemName: "chevron.down")
                    .foregroundStyle(.secondary)
            }
            .padding(16)
            .background(Color.primary.opacity(0.04))

            if store.configs.isEmpty {
                Text(L10n.t(.emptyConfigs, lang.language))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
            } else {
                List {
                    ForEach(store.configs) { cfg in
                        row(for: cfg)
                            .contentShape(Rectangle())
                            .onTapGesture { store.select(cfg.id) }
                            .listRowInsets(EdgeInsets())
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    store.delete(cfg.id)
                                } label: {
                                    Label(L10n.t(.delete, lang.language), systemImage: "trash")
                                }
                            }
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .scrollIndicators(.hidden)
                .environment(\.defaultMinListRowHeight, 0)
            }
        }
        .background(Color.primary.opacity(0.02))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func row(for cfg: SavedConfig) -> some View {
        let isSelected = store.selected?.id == cfg.id
        return HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(cfg.name)
                    .font(.subheadline)
                    .foregroundStyle(isSelected ? .white : .primary)
                    .lineLimit(1)
                Text(cfg.transportLabel)
                    .font(.caption)
                    .foregroundStyle(isSelected ? .white.opacity(0.85) : .secondary)
            }
            Spacer()
            Menu {
                Button(role: .destructive) {
                    store.delete(cfg.id)
                } label: {
                    Label(L10n.t(.delete, lang.language), systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .foregroundStyle(isSelected ? .white.opacity(0.85) : .secondary)
            }
        }
        .padding(16)
        .background(isSelected ? Color(red: 0.18, green: 0.45, blue: 1.0) : Color.primary.opacity(0.04))
    }

    // MARK: - Power button helpers

    private func togglePower() async {
        guard let cfg = store.selected else { return }
        await tunnel.toggle(vlessURL: cfg.url)
    }

    private var buttonColor: Color {
        switch tunnel.state {
        case .connected:    return .green
        case .connecting, .disconnecting: return .orange
        case .error:        return .red
        default:            return store.selected == nil
            ? Color(white: 0.4)
            : Color(red: 0.35, green: 0.6, blue: 1.0)
        }
    }

    private var statusLabel: String {
        switch tunnel.state {
        case .disconnected:  return L10n.t(.statusDisconnected, lang.language)
        case .connecting:    return L10n.t(.statusConnecting, lang.language)
        case .connected:     return L10n.t(.statusConnected, lang.language)
        case .disconnecting: return L10n.t(.statusDisconnecting, lang.language)
        case .invalid:       return L10n.t(.statusInstallProfile, lang.language)
        case .error(let m):  return "\(L10n.t(.statusErrorPrefix, lang.language)): \(m)"
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
