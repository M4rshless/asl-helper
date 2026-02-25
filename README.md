# asl-helper

Small projects to help educate me in ASL and in the future create even better camera detection system for hand signs.

---

## HandGestureApp — Real-Time Hand Gesture Recognition

An iOS app that uses the device camera and Apple's **Vision** framework to detect and name your hand gestures in real time.

### Detected Gestures

| Gesture | Name | Description |
|---------|------|-------------|
| 👍 | Thumbs Up | Only thumb extended, pointing up |
| 👎 | Thumbs Down | Only thumb extended, pointing down |
| ✌️ | Peace / Victory | Index + middle extended |
| 🖐 | Open Palm | All five fingers extended |
| ✊ | Fist | All five fingers curled |
| ☝️ | Pointing | Only index finger extended |
| 👌 | OK | Thumb + index tips pinched, other 3 fingers out |
| 🤘 | Rock On | Index + little (pinky) extended |

### Architecture

```
HandGestureApp/
├── HandGestureApp.xcodeproj/
└── HandGestureApp/
    ├── HandGestureApp.swift       # @main entry point
    ├── ContentView.swift          # SwiftUI UI: camera preview + skeleton overlay + HUD
    ├── CameraManager.swift        # AVFoundation session, publishes gesture state
    ├── HandGestureDetector.swift  # VNDetectHumanHandPoseRequest wrapper
    ├── GestureClassifier.swift    # Rule-based classifier + HandGesture enum
    ├── Info.plist                 # NSCameraUsageDescription permission
    └── Assets.xcassets/
```

### How it works

1. **Camera** — `AVCaptureSession` streams 720p video from the front camera.
2. **Detection** — Every 3rd frame, `VNDetectHumanHandPoseRequest` extracts 21 hand landmarks (joints) with confidence scores.
3. **Classification** — `GestureClassifier` checks which fingers are extended using wrist-relative distances and dot-product maths to determine thumb direction (up vs down).
4. **UI** — A live skeleton overlay (green lines + yellow dots) is drawn on top of the camera feed; the detected gesture name and emoji appear in a frosted-glass card at the bottom.

### Requirements

- Xcode 15 or later
- iOS 17 deployment target (VNDetectHumanHandPoseRequest available from iOS 14+)
- A physical iPhone or iPad (camera not available in Simulator)

### Quick Start

```bash
# Clone the repo
git clone https://github.com/M4rshless/asl-helper.git
cd asl-helper/HandGestureApp

# Open in Xcode
open HandGestureApp.xcodeproj
```

1. Select your device in the Xcode toolbar.
2. Set your **Development Team** in *Signing & Capabilities*.
3. Build & Run (`⌘R`).
4. Grant camera permission when prompted.
5. Hold your hand in front of the camera — the detected gesture appears on screen!
