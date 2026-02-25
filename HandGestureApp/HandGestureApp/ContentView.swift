import SwiftUI
import AVFoundation
import Vision

// MARK: - Root View

struct ContentView: View {

    @StateObject private var camera = CameraManager()

    var body: some View {
        ZStack {
            // ── Camera feed ──────────────────────────────────────────────
            CameraPreviewView(session: camera.session)
                .ignoresSafeArea()

            // ── Hand skeleton overlay ────────────────────────────────────
            GeometryReader { geo in
                HandSkeletonOverlay(
                    joints: camera.jointPoints,
                    size: geo.size
                )
            }
            .ignoresSafeArea()

            // ── Gesture HUD ──────────────────────────────────────────────
            VStack {
                Spacer()
                GestureInfoCard(
                    gesture: camera.detectedGesture,
                    confidence: camera.confidence
                )
                .padding(.horizontal)
                .padding(.bottom, 40)
            }
        }
        .onAppear { camera.startSession() }
        .onDisappear { camera.stopSession() }
        .alert("Camera Access Required",
               isPresented: $camera.permissionDenied) {
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Please allow camera access in Settings to use hand gesture recognition.")
        }
    }
}

// MARK: - Camera Preview (UIKit bridge)

struct CameraPreviewView: UIViewRepresentable {

    let session: AVCaptureSession

    func makeUIView(context: Context) -> _PreviewView {
        let view = _PreviewView()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ uiView: _PreviewView, context: Context) {}

    // Subclass so we can override layerClass
    final class _PreviewView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
    }
}

// MARK: - Hand Skeleton Overlay

struct HandSkeletonOverlay: View {

    let joints: [VNHumanHandPoseObservation.JointName: CGPoint]
    let size: CGSize

    var body: some View {
        Canvas { ctx, _ in
            guard !joints.isEmpty else { return }

            // Draw finger chains (bone lines)
            for chain in HandGestureDetector.fingerChains {
                var path = Path()
                var firstPoint: CGPoint?

                for jointName in chain {
                    guard let pt = joints[jointName] else { continue }
                    let screenPt = visionToScreen(pt)
                    if firstPoint == nil {
                        path.move(to: screenPt)
                        firstPoint = screenPt
                    } else {
                        path.addLine(to: screenPt)
                    }
                }

                ctx.stroke(path,
                           with: .color(.green.opacity(0.85)),
                           style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
            }

            // Draw joint dots
            for (_, pt) in joints {
                let screenPt = visionToScreen(pt)
                let rect = CGRect(x: screenPt.x - 5, y: screenPt.y - 5,
                                  width: 10, height: 10)
                ctx.fill(Path(ellipseIn: rect), with: .color(.yellow))
                ctx.stroke(Path(ellipseIn: rect),
                           with: .color(.black.opacity(0.5)),
                           lineWidth: 1)
            }
        }
    }

    // Vision coords: origin bottom-left, y increases upward.
    // Screen coords: origin top-left, y increases downward.
    private func visionToScreen(_ pt: CGPoint) -> CGPoint {
        CGPoint(x: pt.x * size.width,
                y: (1 - pt.y) * size.height)
    }
}

// MARK: - Gesture Info Card

struct GestureInfoCard: View {

    let gesture: HandGesture
    let confidence: Double

    var body: some View {
        VStack(spacing: 6) {
            // Emoji
            Text(gesture.emoji)
                .font(.system(size: 64))
                .shadow(radius: 4)
                .contentTransition(.symbolEffect(.replace))

            // Gesture name
            Text(gesture.name)
                .font(.title2.bold())
                .foregroundStyle(.white)

            // Description
            Text(gesture.description)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.80))
                .multilineTextAlignment(.center)

            // Confidence bar (only visible when a hand is detected)
            if confidence > 0 {
                HStack(spacing: 8) {
                    Text("Confidence")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.70))
                    ProgressView(value: confidence)
                        .progressViewStyle(.linear)
                        .tint(confidenceTint)
                        .frame(maxWidth: 120)
                    Text("\(Int(confidence * 100))%")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.white.opacity(0.70))
                }
            }
        }
        .padding(.vertical, 18)
        .padding(.horizontal, 24)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24))
        .shadow(color: .black.opacity(0.3), radius: 12, y: 6)
        .animation(.spring(duration: 0.3), value: gesture)
    }

    private var confidenceTint: Color {
        switch confidence {
        case 0.8...: return .green
        case 0.5..<0.8: return .yellow
        default: return .orange
        }
    }
}

// MARK: - Preview

#Preview {
    ContentView()
}
