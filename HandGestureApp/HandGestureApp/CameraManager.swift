import AVFoundation
import Vision
import Combine

/// Manages the `AVCaptureSession`, delivers sample buffers to
/// `HandGestureDetector`, and publishes results for the SwiftUI layer.
final class CameraManager: NSObject, ObservableObject {

    // MARK: Published State

    @Published var detectedGesture: HandGesture = .none
    @Published var confidence: Double = 0.0
    /// Hand skeleton joints in Vision's normalized image coordinates.
    @Published var jointPoints: [VNHumanHandPoseObservation.JointName: CGPoint] = [:]
    /// Whether camera permission has been denied.
    @Published var permissionDenied = false

    // MARK: AVFoundation

    let session = AVCaptureSession()

    private let videoOutput = AVCaptureVideoDataOutput()
    private let processingQueue = DispatchQueue(label: "com.handgesture.processing",
                                                qos: .userInteractive)

    // MARK: Detection

    private let detector = HandGestureDetector()

    /// Skip frames to balance responsiveness with CPU usage.
    /// Process 1 out of every `frameSkip` frames.
    private let frameSkip = 3
    private var frameCounter = 0

    // MARK: Initialisation

    override init() {
        super.init()
        configureSession()
    }

    // MARK: Session Configuration

    private func configureSession() {
        session.beginConfiguration()
        session.sessionPreset = .hd1280x720

        // Prefer the front-facing camera so users can see their own gesture
        let position: AVCaptureDevice.Position = .front
        guard
            let device = AVCaptureDevice.default(.builtInWideAngleCamera,
                                                 for: .video,
                                                 position: position),
            let input = try? AVCaptureDeviceInput(device: device),
            session.canAddInput(input)
        else {
            session.commitConfiguration()
            return
        }

        session.addInput(input)

        videoOutput.alwaysDiscardsLateVideoFrames = true
        videoOutput.setSampleBufferDelegate(self, queue: processingQueue)

        guard session.canAddOutput(videoOutput) else {
            session.commitConfiguration()
            return
        }
        session.addOutput(videoOutput)

        // Mirror the front camera so it feels like a mirror
        if let connection = videoOutput.connection(with: .video) {
            if connection.isVideoOrientationSupported {
                connection.videoOrientation = .portrait
            }
            if connection.isVideoMirroringSupported {
                connection.isVideoMirrored = true
            }
        }

        session.commitConfiguration()
    }

    // MARK: Session Lifecycle

    func startSession() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            startRunning()

        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                if granted {
                    self?.startRunning()
                } else {
                    DispatchQueue.main.async { self?.permissionDenied = true }
                }
            }

        default:
            DispatchQueue.main.async { [weak self] in
                self?.permissionDenied = true
            }
        }
    }

    func stopSession() {
        guard session.isRunning else { return }
        processingQueue.async { [weak self] in
            self?.session.stopRunning()
        }
    }

    private func startRunning() {
        processingQueue.async { [weak self] in
            self?.session.startRunning()
        }
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate

extension CameraManager: AVCaptureVideoDataOutputSampleBufferDelegate {

    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        frameCounter += 1
        guard frameCounter % frameSkip == 0 else { return }

        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        detector.detect(in: pixelBuffer) { [weak self] gesture, confidence, joints in
            DispatchQueue.main.async {
                self?.detectedGesture = gesture
                self?.confidence = confidence
                self?.jointPoints = joints
            }
        }
    }
}
