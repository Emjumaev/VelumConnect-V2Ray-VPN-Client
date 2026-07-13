import SwiftUI

/// App Store Guideline 5.4 requires the full data-collection disclosure to be
/// shown in-app and accepted before the user can reach any functionality.
/// Bump `currentVersion` if the disclosure text ever changes materially —
/// the UserDefaults key is version-suffixed, so users are re-prompted.
enum PrivacyDisclosure {
    static let currentVersion = 1
    static var acceptedKey: String { "v2raysablab.hasAcceptedDataDisclosure_v\(currentVersion)" }
}

/// Root of the app: gates everything behind the data disclosure.
/// `ConnectView` (and with it TunnelManager / ConfigStore / the VPN UI)
/// is not even instantiated until the user has accepted.
struct RootView: View {
    @AppStorage(PrivacyDisclosure.acceptedKey) private var hasAccepted = false
    @StateObject private var lang = LanguageStore()

    var body: some View {
        if hasAccepted {
            ConnectView()
        } else {
            PrivacyDisclosureView(onAgree: { hasAccepted = true })
                .environmentObject(lang)
        }
    }
}

/// The disclosure itself. Two modes:
///   - `onAgree != nil` — first-launch gate with the "I Agree and Continue"
///     button and a language switcher (new installs default to Russian).
///   - `onAgree == nil` — read-only, re-opened from the main screen's menu.
struct PrivacyDisclosureView: View {
    var onAgree: (() -> Void)?
    @EnvironmentObject var lang: LanguageStore

    private var isGate: Bool { onAgree != nil }

    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()

            VStack(spacing: 0) {
                if isGate {
                    HStack {
                        Spacer()
                        languageMenu
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                }

                ScrollView {
                    VStack(spacing: 24) {
                        header
                        VStack(spacing: 12) {
                            bullet("eye.slash", .privacyNoLogging)
                            bullet("internaldrive", .privacyLocalConfigs)
                            bullet("network", .privacyRoutingOnly)
                            bullet("hand.raised", .privacyNoThirdParty)
                        }
                    }
                    .frame(maxWidth: 640)
                    .frame(maxWidth: .infinity)
                    .padding(16)
                }

                if isGate {
                    agreeButton
                        .frame(maxWidth: 640)
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 16)
                }
            }
        }
    }

    private var header: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle().fill(Color.primary.opacity(0.08)).frame(width: 72, height: 72)
                Image(systemName: "lock.shield")
                    .font(.system(size: 32, weight: .regular))
                    .foregroundStyle(Color(red: 0.18, green: 0.45, blue: 1.0))
            }
            Text(L10n.t(.privacyTitle, lang.language))
                .font(.title2.weight(.semibold))
                .foregroundStyle(.primary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 16)
    }

    private func bullet(_ icon: String, _ key: L10n.Key) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.body)
                .foregroundStyle(Color(red: 0.18, green: 0.45, blue: 1.0))
                .frame(width: 28, alignment: .center)
                .padding(.top, 2)
            Text(L10n.t(key, lang.language))
                .font(.subheadline)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(16)
        .background(Color.primary.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private var agreeButton: some View {
        Button {
            onAgree?()
        } label: {
            Text(L10n.t(.privacyAgreeContinue, lang.language))
                .font(.headline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Capsule().fill(Color(red: 0.18, green: 0.45, blue: 1.0)))
        }
        .buttonStyle(.plain)
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
}

#Preview("Gate") {
    PrivacyDisclosureView(onAgree: {})
        .environmentObject(LanguageStore())
}

#Preview("Read-only") {
    PrivacyDisclosureView()
        .environmentObject(LanguageStore())
}
