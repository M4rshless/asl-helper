import Vision
import CoreVideo

/// Runs `VNDetectHumanHandPoseRequest` on incoming pixel buffers and forwards
/// results to a caller-supplied completion handler.
final class HandGestureDetector {

    // MARK: Properties

    private let request: VNDetectHumanHandPoseRequest = {
        let r = VNDetectHumanHandPoseRequest()
        r.maximumHandCount = 1
        return r
    }()

    private let classifier = GestureClassifier()

    /// All recognized joint locations from the latest frame, in Vision's
    /// normalised image coordinates (origin at bottom-left).
    private(set) var lastJointPoints: [VNHumanHandPoseObservation.JointName: CGPoint] = [:]

    // MARK: Detection

    /// Processes one video frame and calls `completion` on whatever queue
    /// the caller is on (typically a background serial queue).
    func detect(
        in pixelBuffer: CVPixelBuffer,
        completion: @escaping (_ gesture: HandGesture, _ confidence: Double, _ joints: [VNHumanHandPoseObservation.JointName: CGPoint]) -> Void
    ) {
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer,
                                            orientation: .up,
                                            options: [:])
        do {
            try handler.perform([request])
        } catch {
            completion(.none, 0, [:])
            return
        }

        guard let observation = request.results?.first else {
            completion(.none, 0, [:])
            return
        }

        // Collect all joints for the overlay visualisation
        let joints = collectJoints(from: observation)
        lastJointPoints = joints

        let (gesture, confidence) = classifier.classify(observation: observation)
        completion(gesture, confidence, joints)
    }

    // MARK: Joint Collection

    private func collectJoints(
        from observation: VNHumanHandPoseObservation
    ) -> [VNHumanHandPoseObservation.JointName: CGPoint] {
        var result: [VNHumanHandPoseObservation.JointName: CGPoint] = [:]

        let groups: [VNHumanHandPoseObservation.JointsGroupName] = [
            .thumb, .indexFinger, .middleFinger, .ringFinger, .littleFinger, .all
        ]

        for group in groups {
            guard let points = try? observation.recognizedPoints(group) else { continue }
            for (name, point) in points where point.confidence > 0.3 {
                result[name] = point.location
            }
        }

        return result
    }

    // MARK: Finger Connectivity

    /// Returns ordered joint sequences for drawing the hand skeleton.
    static let fingerChains: [[VNHumanHandPoseObservation.JointName]] = [
        [.wrist, .thumbCMC, .thumbMP, .thumbIP, .thumbTip],
        [.wrist, .indexMCP, .indexPIP, .indexDIP, .indexTip],
        [.wrist, .middleMCP, .middlePIP, .middleDIP, .middleTip],
        [.wrist, .ringMCP, .ringPIP, .ringDIP, .ringTip],
        [.wrist, .littleMCP, .littlePIP, .littleDIP, .littleTip],
        // Knuckle bar
        [.indexMCP, .middleMCP, .ringMCP, .littleMCP]
    ]
}
