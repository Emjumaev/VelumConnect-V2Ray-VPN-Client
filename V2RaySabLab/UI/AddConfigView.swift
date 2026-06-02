import SwiftUI
import UIKit

/// Sheet for adding a new VLESS config via one of three input methods.
struct AddConfigView: View {
    enum Mode: Identifiable {
        case enterLink
        case scanQR
        case clipboard

        var id: Int {
            switch self {
            case .enterLink: return 0
            case .scanQR: return 1
            case .clipboard: return 2
            }
        }

        func title(_ lang: AppLanguage) -> String {
            switch self {
            case .enterLink: return L10n.t(.enterLink, lang)
            case .scanQR: return L10n.t(.scanQR, lang)
            case .clipboard: return L10n.t(.importClipboard, lang)
            }
        }
    }

    let mode: Mode
    @ObservedObject var store: ConfigStore
    @EnvironmentObject var lang: LanguageStore
    @Environment(\.dismiss) private var dismiss

    @State private var text: String = ""
    @State private var errorMessage: String?
    @State private var didTryClipboard = false

    var body: some View {
        NavigationStack {
            content
                .navigationTitle(mode.title(lang.language))
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(L10n.t(.cancel, lang.language)) { dismiss() }
                    }
                    if mode == .enterLink {
                        ToolbarItem(placement: .confirmationAction) {
                            Button(L10n.t(.add, lang.language)) { tryAdd(text) }
                                .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        }
                    }
                }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch mode {
        case .enterLink:
            manualEntry
        case .scanQR:
            QRScannerView(deniedMessage: L10n.t(.cameraDenied, lang.language)) { code in
                tryAdd(code)
            }
            .ignoresSafeArea()
            .overlay(alignment: .top) {
                if let msg = errorMessage {
                    Text(msg)
                        .font(.footnote)
                        .padding(8)
                        .background(.red.opacity(0.9), in: Capsule())
                        .foregroundStyle(.white)
                        .padding(.top, 12)
                }
            }
        case .clipboard:
            clipboardFlow
        }
    }

    // MARK: - Manual entry

    private var manualEntry: some View {
        Form {
            Section(L10n.t(.vlessURL, lang.language)) {
                TextField("vless://uuid@host:port/?...",
                          text: $text,
                          axis: .vertical)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .lineLimit(4...10)
                    .font(.system(.footnote, design: .monospaced))
            }
            if let msg = errorMessage {
                Section {
                    Text(msg).foregroundStyle(.red).font(.footnote)
                }
            }
        }
    }

    // MARK: - Clipboard

    private var clipboardFlow: some View {
        VStack(spacing: 16) {
            if didTryClipboard, let msg = errorMessage {
                Image(systemName: "exclamationmark.triangle")
                    .font(.largeTitle)
                    .foregroundStyle(.orange)
                Text(msg)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                Button(L10n.t(.tryAgain, lang.language)) { handleClipboard() }
                    .buttonStyle(.borderedProminent)
            } else {
                ProgressView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            // Defer one runloop tick so the sheet is visible before the
            // clipboard-permission prompt appears on iOS 16+.
            DispatchQueue.main.async { handleClipboard() }
        }
    }

    private func handleClipboard() {
        didTryClipboard = true
        errorMessage = nil
        let text = UIPasteboard.general.string ?? ""
        if text.isEmpty {
            errorMessage = L10n.t(.clipboardEmpty, lang.language)
            return
        }
        tryAdd(text)
    }

    // MARK: - Shared add

    private func tryAdd(_ raw: String) {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        do {
            _ = try store.addFromURL(trimmed)
            dismiss()
        } catch {
            errorMessage = String(describing: error)
        }
    }
}
