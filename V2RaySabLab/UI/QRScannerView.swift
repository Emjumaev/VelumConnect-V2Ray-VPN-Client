import SwiftUI
import AVFoundation

/// SwiftUI wrapper around AVCaptureSession for QR scanning.
/// Emits `onCode(String)` once on the main thread when a QR payload is read,
/// then stops the session — the host view is responsible for dismissing.
struct QRScannerView: UIViewControllerRepresentable {
    let deniedMessage: String
    let onCode: (String) -> Void

    init(deniedMessage: String = "Camera access denied.", onCode: @escaping (String) -> Void) {
        self.deniedMessage = deniedMessage
        self.onCode = onCode
    }

    func makeUIViewController(context: Context) -> ScannerVC {
        let vc = ScannerVC()
        vc.onCode = onCode
        vc.deniedMessage = deniedMessage
        return vc
    }

    func updateUIViewController(_ uiViewController: ScannerVC, context: Context) {
        uiViewController.deniedMessage = deniedMessage
    }

    final class ScannerVC: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
        var onCode: ((String) -> Void)?
        var deniedMessage: String = "Camera access denied."
        private let session = AVCaptureSession()
        private var previewLayer: AVCaptureVideoPreviewLayer?
        private var hasDelivered = false

        override func viewDidLoad() {
            super.viewDidLoad()
            view.backgroundColor = .black
            configureSession()
        }

        private func configureSession() {
            // Ask for permission first; if denied, show a hint and bail.
            switch AVCaptureDevice.authorizationStatus(for: .video) {
            case .authorized:
                startCapture()
            case .notDetermined:
                AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                    DispatchQueue.main.async {
                        if granted { self?.startCapture() } else { self?.showPermissionHint() }
                    }
                }
            case .denied, .restricted:
                showPermissionHint()
            @unknown default:
                showPermissionHint()
            }
        }

        private func startCapture() {
            guard let device = AVCaptureDevice.default(for: .video),
                  let input = try? AVCaptureDeviceInput(device: device),
                  session.canAddInput(input) else {
                showPermissionHint()
                return
            }
            session.addInput(input)

            let output = AVCaptureMetadataOutput()
            guard session.canAddOutput(output) else {
                showPermissionHint()
                return
            }
            session.addOutput(output)
            output.metadataObjectTypes = [.qr]
            output.setMetadataObjectsDelegate(self, queue: .main)

            let preview = AVCaptureVideoPreviewLayer(session: session)
            preview.videoGravity = .resizeAspectFill
            preview.frame = view.bounds
            view.layer.addSublayer(preview)
            previewLayer = preview

            // Session.startRunning blocks; off-main per Apple's docs.
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                self?.session.startRunning()
            }
        }

        private func showPermissionHint() {
            let label = UILabel()
            label.text = deniedMessage
            label.numberOfLines = 0
            label.textAlignment = .center
            label.textColor = .white
            label.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(label)
            NSLayoutConstraint.activate([
                label.centerXAnchor.constraint(equalTo: view.centerXAnchor),
                label.centerYAnchor.constraint(equalTo: view.centerYAnchor),
                label.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
                label.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            ])
        }

        override func viewDidLayoutSubviews() {
            super.viewDidLayoutSubviews()
            previewLayer?.frame = view.bounds
        }

        override func viewWillDisappear(_ animated: Bool) {
            super.viewWillDisappear(animated)
            if session.isRunning {
                DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                    self?.session.stopRunning()
                }
            }
        }

        // MARK: - Delegate

        func metadataOutput(_ output: AVCaptureMetadataOutput,
                            didOutput metadataObjects: [AVMetadataObject],
                            from connection: AVCaptureConnection) {
            guard !hasDelivered else { return }
            guard let mo = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
                  let s = mo.stringValue, !s.isEmpty else { return }
            hasDelivered = true
            session.stopRunning()
            onCode?(s)
        }
    }
}
