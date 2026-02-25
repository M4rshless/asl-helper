import Vision
import CoreGraphics

// MARK: - Hand Gesture Model

enum HandGesture: Equatable {
    case none
    case thumbsUp
    case thumbsDown
    case peace
    case openPalm
    case fist
    case pointing
    case ok
    case rockOn

    var name: String {
        switch self {
        case .none:       return "No Hand Detected"
        case .thumbsUp:   return "Thumbs Up"
        case .thumbsDown: return "Thumbs Down"
        case .peace:      return "Peace / Victory"
        case .openPalm:   return "Open Palm"
        case .fist:       return "Fist"
        case .pointing:   return "Pointing"
        case .ok:         return "OK"
        case .rockOn:     return "Rock On"
        }
    }

    var emoji: String {
        switch self {
        case .none:       return "🤷"
        case .thumbsUp:   return "👍"
        case .thumbsDown: return "👎"
        case .peace:      return "✌️"
        case .openPalm:   return "🖐"
        case .fist:       return "✊"
        case .pointing:   return "☝️"
        case .ok:         return "👌"
        case .rockOn:     return "🤘"
        }
    }

    var description: String {
        switch self {
        case .none:       return "Show your hand to the camera"
        case .thumbsUp:   return "Positive signal — great job!"
        case .thumbsDown: return "Negative signal — not good"
        case .peace:      return "Peace & Victory sign"
        case .openPalm:   return "Hello! / Stop"
        case .fist:       return "Power / Strength"
        case .pointing:   return "One / Attention / Direction"
        case .ok:         return "OK / Perfect / Agree"
        case .rockOn:     return "Rock On! 🎸"
        }
    }
}

// MARK: - Gesture Classifier

struct GestureClassifier {

    // MARK: Internal State

    private struct FingerState {
        let isExtended: Bool
        let tipPoint: CGPoint
        let mcpPoint: CGPoint
    }

    private struct HandState {
        let thumb: FingerState
        let index: FingerState
        let middle: FingerState
        let ring: FingerState
        let little: FingerState
        let wrist: CGPoint
        /// Dot product of the thumb vector with the hand's "up" direction.
        /// Positive → thumb pointing away from palm (upward relative to hand).
        let thumbAlignWithHandUp: CGFloat
    }

    // MARK: Public Interface

    func classify(observation: VNHumanHandPoseObservation) -> (gesture: HandGesture, confidence: Double) {
        guard let state = try? buildHandState(from: observation) else {
            return (.none, 0)
        }
        return identifyGesture(state)
    }

    // MARK: Hand State Extraction

    private func buildHandState(from observation: VNHumanHandPoseObservation) throws -> HandState {
        let thumbPts  = try observation.recognizedPoints(.thumb)
        let indexPts  = try observation.recognizedPoints(.indexFinger)
        let midPts    = try observation.recognizedPoints(.middleFinger)
        let ringPts   = try observation.recognizedPoints(.ringFinger)
        let littlePts = try observation.recognizedPoints(.littleFinger)
        let allPts    = try observation.recognizedPoints(.all)

        // Confidence threshold — require at least 30% certainty per point
        let threshold: Float = 0.3

        guard
            let thumbTip  = thumbPts[.thumbTip],   thumbTip.confidence  > threshold,
            let thumbIP   = thumbPts[.thumbIP],    thumbIP.confidence   > threshold,
            let thumbMP   = thumbPts[.thumbMP],    thumbMP.confidence   > threshold,
            let thumbCMC  = thumbPts[.thumbCMC],   thumbCMC.confidence  > threshold,

            let indexTip  = indexPts[.indexTip],   indexTip.confidence  > threshold,
            let indexPIP  = indexPts[.indexPIP],   indexPIP.confidence  > threshold,
            let indexMCP  = indexPts[.indexMCP],   indexMCP.confidence  > threshold,

            let midTip    = midPts[.middleTip],    midTip.confidence    > threshold,
            let midPIP    = midPts[.middlePIP],    midPIP.confidence    > threshold,
            let midMCP    = midPts[.middleMCP],    midMCP.confidence    > threshold,

            let ringTip   = ringPts[.ringTip],     ringTip.confidence   > threshold,
            let ringPIP   = ringPts[.ringPIP],     ringPIP.confidence   > threshold,
            let ringMCP   = ringPts[.ringMCP],     ringMCP.confidence   > threshold,

            let littleTip = littlePts[.littleTip], littleTip.confidence > threshold,
            let littlePIP = littlePts[.littlePIP], littlePIP.confidence > threshold,
            let littleMCP = littlePts[.littleMCP], littleMCP.confidence > threshold,

            let wristPt   = allPts[.wrist],        wristPt.confidence   > threshold
        else {
            throw NSError(domain: "GestureClassifier", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "Insufficient confidence"])
        }

        let wrist = wristPt.location

        // Compute the hand's local "up" direction: wrist → middle-MCP
        let handUp = normalizedVector(from: wrist, to: midMCP.location)

        let indexExt  = isFingerExtended(tip: indexTip.location,  pip: indexPIP.location,  mcp: indexMCP.location,  wrist: wrist)
        let midExt    = isFingerExtended(tip: midTip.location,    pip: midPIP.location,    mcp: midMCP.location,    wrist: wrist)
        let ringExt   = isFingerExtended(tip: ringTip.location,   pip: ringPIP.location,   mcp: ringMCP.location,   wrist: wrist)
        let littleExt = isFingerExtended(tip: littleTip.location, pip: littlePIP.location, mcp: littleMCP.location, wrist: wrist)
        let thumbExt  = isThumbExtended(tip: thumbTip.location, ip: thumbIP.location, mp: thumbMP.location, cmc: thumbCMC.location)

        // Direction the thumb points relative to the hand's up axis
        let thumbVec = normalizedVector(from: thumbCMC.location, to: thumbTip.location)
        let thumbAlign = dot(thumbVec, handUp)

        return HandState(
            thumb:  FingerState(isExtended: thumbExt,  tipPoint: thumbTip.location,  mcpPoint: thumbMP.location),
            index:  FingerState(isExtended: indexExt,  tipPoint: indexTip.location,  mcpPoint: indexMCP.location),
            middle: FingerState(isExtended: midExt,    tipPoint: midTip.location,    mcpPoint: midMCP.location),
            ring:   FingerState(isExtended: ringExt,   tipPoint: ringTip.location,   mcpPoint: ringMCP.location),
            little: FingerState(isExtended: littleExt, tipPoint: littleTip.location, mcpPoint: littleMCP.location),
            wrist: wrist,
            thumbAlignWithHandUp: thumbAlign
        )
    }

    // MARK: Finger Extension Detection

    /// A finger is considered extended when its tip is significantly farther from the wrist
    /// than the MCP knuckle (≥1.6× the MCP-to-wrist distance).
    private func isFingerExtended(tip: CGPoint, pip: CGPoint, mcp: CGPoint, wrist: CGPoint) -> Bool {
        let tipDist = distance(tip, wrist)
        let mcpDist = distance(mcp, wrist)
        return tipDist > mcpDist * 1.6
    }

    /// Thumb is extended when its tip is farther from the thumb-MP than the CMC is.
    private func isThumbExtended(tip: CGPoint, ip: CGPoint, mp: CGPoint, cmc: CGPoint) -> Bool {
        let tipToMP = distance(tip, mp)
        let cmcToMP = distance(cmc, mp)
        return tipToMP > cmcToMP * 0.9
    }

    // MARK: Gesture Identification

    private func identifyGesture(_ h: HandState) -> (HandGesture, Double) {
        let T = h.thumb.isExtended
        let I = h.index.isExtended
        let M = h.middle.isExtended
        let R = h.ring.isExtended
        let L = h.little.isExtended

        // ── Thumbs Up: only thumb extended, pointing "with" the hand's up axis
        if T && !I && !M && !R && !L && h.thumbAlignWithHandUp > 0.3 {
            return (.thumbsUp, 0.92)
        }

        // ── Thumbs Down: only thumb extended, pointing "against" the hand's up axis
        if T && !I && !M && !R && !L && h.thumbAlignWithHandUp < -0.3 {
            return (.thumbsDown, 0.92)
        }

        // ── Open Palm: all five digits extended
        if T && I && M && R && L {
            return (.openPalm, 0.95)
        }

        // ── Fist: all five digits curled
        if !T && !I && !M && !R && !L {
            return (.fist, 0.90)
        }

        // ── Peace / Victory: index + middle up, others down
        if !T && I && M && !R && !L {
            return (.peace, 0.90)
        }

        // ── Pointing: only index finger extended
        if !T && I && !M && !R && !L {
            return (.pointing, 0.90)
        }

        // ── Rock On: index + little extended (devil horns)
        if !T && I && !M && !R && L {
            return (.rockOn, 0.88)
        }

        // ── OK: thumb tip and index tip pinched together, other three fingers extended
        let thumbIndexDist = distance(h.thumb.tipPoint, h.index.tipPoint)
        if thumbIndexDist < 0.09 && M && R && L {
            return (.ok, 0.85)
        }

        // ── Thumb extended but direction ambiguous (e.g. sideways)
        if T && !I && !M && !R && !L {
            return (.thumbsUp, 0.45)
        }

        return (.none, 0)
    }

    // MARK: Vector Math Helpers

    private func distance(_ a: CGPoint, _ b: CGPoint) -> CGFloat {
        let dx = a.x - b.x
        let dy = a.y - b.y
        return sqrt(dx * dx + dy * dy)
    }

    private func normalizedVector(from a: CGPoint, to b: CGPoint) -> CGPoint {
        let dx = b.x - a.x
        let dy = b.y - a.y
        let mag = sqrt(dx * dx + dy * dy)
        guard mag > 0 else { return .zero }
        return CGPoint(x: dx / mag, y: dy / mag)
    }

    private func dot(_ a: CGPoint, _ b: CGPoint) -> CGFloat {
        a.x * b.x + a.y * b.y
    }
}
