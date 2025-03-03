# LiDARKit

A Swift library for capturing, processing, and visualizing LiDAR point cloud data on iOS devices.

## Features

-   **Capture**

    -   Real-time LiDAR point cloud capture using ARKit
    -   Confidence values for each captured point
    -   Normal vector calculation
    -   Position and transform tracking

-   **Storage & Export**

    -   Binary and ASCII PLY format support
    -   Efficient local storage with metadata
    -   Async/await API for modern Swift concurrency
    -   Background processing support

-   **Visualization**

    -   High-performance SceneKit rendering
    -   Custom Metal shaders for point cloud display
    -   Multiple visualization modes:
        -   Confidence-based coloring
        -   Height-based coloring
        -   RGB color support
        -   Intensity visualization
        -   Normal vector visualization
    -   Configurable point size and appearance
    -   Interactive 3D camera controls

-   **Point Cloud Data**
    -   SIMD-optimized point storage
    -   Support for:
        -   3D positions
        -   Normal vectors
        -   Confidence values
        -   RGB colors
        -   Intensity values
    -   Transform matrices for positioning

## Requirements

-   iOS 14.0+
-   Xcode 13.0+
-   Swift 5.5+
-   Device with LiDAR sensor (iPhone 12 Pro/Pro Max or newer, iPad Pro 2020 or newer)

## Installation

### Swift Package Manager

Add the following to your `Package.swift` file:

```swift
dependencies: [
    .package(url: "https://github.com/yourusername/LiDARKit.git", from: "1.0.0")
]
```

## Usage

### Basic Capture

```swift
import LiDARKit

class ViewController: UIViewController, LiDARCaptureDelegate {
    private let captureSession = LiDARCaptureSession()

    override func viewDidLoad() {
        super.viewDidLoad()
        captureSession.delegate = self
        captureSession.startCapture()
    }

    func captureSession(_ session: LiDARCaptureSession, didCapturePointCloud pointCloud: PointCloud) {
        // Handle captured point cloud
        print("Captured \(pointCloud.count) points")
    }
}
```

### Visualization with Custom Configuration

```swift
import LiDARKit

class ViewController: UIViewController {
    @IBOutlet weak var sceneView: SCNView!
    private let renderer = SceneKitPointCloudRenderer()

    override func viewDidLoad() {
        super.viewDidLoad()
        renderer.initialize(with: sceneView)

        // Configure rendering with custom settings
        let config = RenderConfiguration(
            pointSize: 5,
            colorScheme: .height,  // Height-based coloring
            showNormals: true,     // Show normal vectors
            maxPoints: 100000      // Limit points for performance
        )
        renderer.updateConfiguration(config)
    }

    func render(_ pointCloud: PointCloud) {
        renderer.render(pointCloud)
    }
}
```

### Storage and Export

```swift
import LiDARKit

// Initialize storage
let storage = try FilePointCloudStorage()

// Save point cloud with metadata
try await storage.save(pointCloud, withIdentifier: "scan_001")

// List available scans
let savedScans = try await storage.listStoredPointClouds()

// Load a specific scan
let loadedCloud = try await storage.load(identifier: "scan_001")

// Export to PLY format
let exporter = PLYExporter(format: .binary)  // or .ascii
try exporter.write(pointCloud, to: fileURL)
```

### Color Schemes

The renderer supports multiple color schemes for visualization:

```swift
// Confidence-based coloring
renderer.updateConfiguration(.init(colorScheme: .confidence))

// Height-based coloring
renderer.updateConfiguration(.init(colorScheme: .height))

// RGB coloring (if color data is available)
renderer.updateConfiguration(.init(colorScheme: .rgb))

// Intensity-based coloring
renderer.updateConfiguration(.init(colorScheme: .intensity))

// Uniform coloring
renderer.updateConfiguration(.init(colorScheme: .uniform(.white)))
```

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request. Here are some areas we're looking to improve:

-   Additional file format support (PCD, LAS)
-   Point cloud processing algorithms
-   Performance optimizations
-   Additional visualization options
-   Documentation improvements

## License

This project is licensed under the MIT License - see the LICENSE file for details.
