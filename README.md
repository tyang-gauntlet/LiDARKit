# LiDARKit

A Swift library for capturing, processing, and visualizing LiDAR point cloud data on iOS devices.

## Features

-   **Capture**

    -   Real-time LiDAR point cloud capture using ARKit
    -   Depth map processing with configurable parameters
    -   Position and transform tracking

-   **Storage & Export**

    -   Support for point cloud data storage
    -   Efficient memory management
    -   Transform matrices for positioning

-   **Visualization**

    -   SceneKit rendering with custom shaders
    -   Depth-based coloring
    -   Configurable point size
    -   Interactive 3D camera controls

-   **Point Cloud Data**
    -   SIMD-optimized point storage
    -   Support for:
        -   3D positions
        -   Transform matrices
    -   Memory-efficient implementation

## Requirements

-   iOS 15.0+
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
import ARKit

class ViewController: UIViewController, LiDARCaptureDelegate {
    private var captureSession: LiDARCaptureSession!
    private var arSession: ARSession!

    override func viewDidLoad() {
        super.viewDidLoad()
        setupCaptureSession()
    }

    private func setupCaptureSession() {
        arSession = ARSession()

        // Configure AR session for LiDAR
        let configuration = ARWorldTrackingConfiguration()
        guard ARWorldTrackingConfiguration.supportsFrameSemantics(.sceneDepth) else {
            // Handle devices without LiDAR
            return
        }

        // Enable scene depth
        configuration.frameSemantics = [.sceneDepth, .smoothedSceneDepth]

        // Start AR session
        arSession.run(configuration, options: [.removeExistingAnchors, .resetTracking])

        // Create capture session
        captureSession = LiDARCaptureSession(session: arSession)
        captureSession.delegate = self
        captureSession.startCapture()
    }

    func captureSession(_ session: LiDARCaptureSession, didCapturePointCloud pointCloud: PointCloud) {
        // Handle captured point cloud
        print("Captured point cloud with transform: \(pointCloud.transform)")
    }

    func captureSession(_ session: LiDARCaptureSession, didFailWithError error: Error) {
        // Handle errors
        print("Capture error: \(error.localizedDescription)")
    }
}
```

### Visualization with SceneKit

```swift
import LiDARKit
import SceneKit
import ARKit

class ViewController: UIViewController, LiDARCaptureDelegate {
    private var arView: ARSCNView!
    private var captureSession: LiDARCaptureSession!
    private var pointCloudNode: SCNNode?

    // Setup visualization
    func setupVisualization() {
        arView = ARSCNView(frame: view.bounds)
        view.addSubview(arView)

        // Configure AR view
        arView.session = arSession
        arView.automaticallyUpdatesLighting = true
        arView.scene = SCNScene()
    }

    // Handle point cloud updates
    func captureSession(_ session: LiDARCaptureSession, didCapturePointCloud pointCloud: PointCloud) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            // Create geometry data
            let vertices = pointCloud.points.map { SCNVector3($0.position.x, $0.position.y, $0.position.z) }
            let colors = pointCloud.points.map { point -> SCNVector4 in
                let depth = abs(point.position.z)
                let hue = Float(max(0, min(1, depth / 2.0)))
                let color = UIColor(hue: CGFloat(hue), saturation: 1.0, brightness: 1.0, alpha: 1.0)
                var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
                color.getRed(&r, green: &g, blue: &b, alpha: &a)
                return SCNVector4(Float(r), Float(g), Float(b), 1.0)
            }

            // Create geometry on main thread
            DispatchQueue.main.async {
                self?.updatePointCloudVisualization(vertices: vertices, colors: colors, transform: pointCloud.transform)
            }
        }
    }

    // Update visualization with new point cloud data
    private func updatePointCloudVisualization(vertices: [SCNVector3], colors: [SCNVector4], transform: simd_float4x4) {
        // Clear previous resources
        pointCloudNode?.geometry = nil
        pointCloudNode?.removeFromParentNode()
        pointCloudNode = nil

        // Create geometry sources
        let vertexData = Data(bytes: vertices, count: vertices.count * MemoryLayout<SCNVector3>.size)
        let colorData = Data(bytes: colors, count: colors.count * MemoryLayout<SCNVector4>.size)

        let vertexSource = SCNGeometrySource(
            data: vertexData,
            semantic: .vertex,
            vectorCount: vertices.count,
            usesFloatComponents: true,
            componentsPerVector: 3,
            bytesPerComponent: MemoryLayout<Float>.size,
            dataOffset: 0,
            dataStride: MemoryLayout<SCNVector3>.size
        )

        let colorSource = SCNGeometrySource(
            data: colorData,
            semantic: .color,
            vectorCount: colors.count,
            usesFloatComponents: true,
            componentsPerVector: 4,
            bytesPerComponent: MemoryLayout<Float>.size,
            dataOffset: 0,
            dataStride: MemoryLayout<SCNVector4>.size
        )

        let element = SCNGeometryElement(
            data: nil,
            primitiveType: .point,
            primitiveCount: vertices.count,
            bytesPerIndex: 0
        )

        // Create and configure geometry
        let geometry = SCNGeometry(sources: [vertexSource, colorSource], elements: [element])
        let material = SCNMaterial()
        material.diffuse.contents = UIColor.white
        material.lightingModel = .constant
        material.isDoubleSided = true

        // Configure shader
        material.shaderModifiers = [
            .fragment: """
            #pragma body
            _output.color = _surface.diffuse;
            """,
            .geometry: """
            #pragma body
            _geometry.pointSize = 3.0;
            """
        ]

        geometry.materials = [material]

        // Create and configure node
        let node = SCNNode(geometry: geometry)
        node.scale = SCNVector3(0.1, 0.1, 0.1)
        node.simdTransform = transform

        // Store reference and add to scene
        pointCloudNode = node
        arView.scene.rootNode.addChildNode(node)
    }
}
```

## Memory Management

LiDARKit is designed with efficient memory management to prevent ARFrame retention issues:

```swift
// Best practices for handling point clouds
func captureSession(_ session: LiDARCaptureSession, didCapturePointCloud pointCloud: PointCloud) {
    // Process on background thread
    DispatchQueue.global(qos: .userInitiated).async { [weak self] in
        // Process data...

        // Update UI on main thread
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            // Clear previous resources first
            self.pointCloudNode?.geometry = nil
            self.pointCloudNode?.removeFromParentNode()
            self.pointCloudNode = nil
            self.latestPointCloud = nil

            // Then create new visualization...
        }
    }
}
```

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request. Here are some areas we're looking to improve:

-   Additional file format support (PLY, PCD, LAS)
-   Point cloud processing algorithms
-   Performance optimizations
-   Additional visualization options
-   Documentation improvements

## License

This project is licensed under the MIT License - see the LICENSE file for details.
