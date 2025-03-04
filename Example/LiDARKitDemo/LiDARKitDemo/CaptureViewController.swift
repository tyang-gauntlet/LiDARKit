import UIKit
import ARKit
import LiDARKit
import AVFoundation

class CaptureViewController: UIViewController {
    private var captureSession: LiDARCaptureSession!
    private var arView: ARSCNView!
    private var captureButton: UIButton!
    private var latestPointCloud: PointCloud?
    private var arSession: ARSession!
    private var pointCloudNode: SCNNode?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        checkCameraPermission()
    }
    
    private func checkCameraPermission() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            setupCaptureSession()
            setupUI()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                if granted {
                    DispatchQueue.main.async {
                        self?.setupCaptureSession()
                        self?.setupUI()
                    }
                }
            }
        default:
            showCameraPermissionAlert()
        }
    }
    
    private func showCameraPermissionAlert() {
        let alert = UIAlertController(
            title: "Camera Access Required",
            message: "Please grant camera access in Settings to use the LiDAR scanner.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Open Settings", style: .default) { _ in
            if let url = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(url)
            }
        })
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alert, animated: true)
    }
    
    private func setupUI() {
        // Setup AR view
        arView = ARSCNView(frame: view.bounds)
        arView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(arView)
        
        // Configure AR view
        arView.session = arSession
        arView.delegate = self
        arView.automaticallyUpdatesLighting = true
        arView.scene = SCNScene()
        arView.debugOptions = [.showFeaturePoints, .showWorldOrigin]  // Show more debug info
        arView.rendersContinuously = true  // Ensure continuous rendering
        arView.antialiasingMode = .multisampling4X  // Improve point rendering quality
        arView.preferredFramesPerSecond = 60  // Smooth rendering
        
        // Set up camera
        let camera = arView.pointOfView?.camera
        camera?.wantsHDR = true
        camera?.wantsExposureAdaptation = true
        camera?.exposureOffset = 1
        camera?.minimumExposure = -1
        camera?.maximumExposure = 3
        
        // Add ambient light to ensure points are visible
        let ambientLight = SCNLight()
        ambientLight.type = .ambient
        ambientLight.intensity = 1000
        let ambientNode = SCNNode()
        ambientNode.light = ambientLight
        arView.scene.rootNode.addChildNode(ambientNode)
        
        // Setup capture button
        captureButton = UIButton(type: .system)
        captureButton.setTitle("Capture", for: .normal)
        captureButton.backgroundColor = .systemBlue
        captureButton.setTitleColor(.white, for: .normal)
        captureButton.layer.cornerRadius = 25
        captureButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(captureButton)
        
        NSLayoutConstraint.activate([
            captureButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            captureButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            captureButton.widthAnchor.constraint(equalToConstant: 120),
            captureButton.heightAnchor.constraint(equalToConstant: 50)
        ])
        
        captureButton.addTarget(self, action: #selector(captureButtonTapped), for: .touchUpInside)
    }
    
    private func setupCaptureSession() {
        arSession = ARSession()
        
        // Configure AR session for LiDAR
        let configuration = ARWorldTrackingConfiguration()
        guard ARWorldTrackingConfiguration.supportsFrameSemantics(.sceneDepth) else {
            let alert = UIAlertController(
                title: "Device Not Supported",
                message: "This device does not support LiDAR scanning.",
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            present(alert, animated: true)
            return
        }
        
        // Enable both scene depth and smoothed scene depth
        configuration.frameSemantics = [.sceneDepth, .smoothedSceneDepth]
        
        // Enable auto-focus and people occlusion for better depth
        configuration.isAutoFocusEnabled = true
        if ARWorldTrackingConfiguration.supportsFrameSemantics(.personSegmentationWithDepth) {
            configuration.frameSemantics.insert(.personSegmentationWithDepth)
        }
        
        // Start AR session with configuration
        arSession.run(configuration, options: [.removeExistingAnchors, .resetTracking])
        
        // Create capture session
        captureSession = LiDARCaptureSession(session: arSession)
        captureSession.delegate = self
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        captureSession.startCapture()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        captureSession.stopCapture()
    }
    
    @objc private func captureButtonTapped() {
        guard let pointCloud = latestPointCloud else { return }
        
        let viewController = PointCloudViewController(pointCloud: pointCloud)
        viewController.modalPresentationStyle = .fullScreen
        present(viewController, animated: true)
    }
}

extension CaptureViewController: ARSCNViewDelegate {
    func renderer(_ renderer: SCNSceneRenderer, didFailWithError error: Error) {
        // Handle AR rendering failure
        let alert = UIAlertController(
            title: "AR Rendering Failed",
            message: error.localizedDescription,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}

extension CaptureViewController: LiDARCaptureDelegate {
    func captureSession(_ session: LiDARCaptureSession, didCapturePointCloud pointCloud: PointCloud) {
        // Process point cloud on background queue to avoid blocking main thread
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
            
            let vertexData = Data(bytes: vertices, count: vertices.count * MemoryLayout<SCNVector3>.size)
            let colorData = Data(bytes: colors, count: colors.count * MemoryLayout<SCNVector4>.size)
            
            // Create geometry on main thread
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                
                // Clear previous resources
                self.pointCloudNode?.geometry = nil
                self.pointCloudNode?.removeFromParentNode()
                self.pointCloudNode = nil
                self.latestPointCloud = nil
                
                // Skip if no points
                guard !pointCloud.points.isEmpty else { return }
                
                // Create geometry sources
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
                
                // Configure shader with fixed point size
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
                node.simdTransform = pointCloud.transform
                
                // Store references
                self.pointCloudNode = node
                self.latestPointCloud = pointCloud
                
                // Add to scene
                self.arView.scene.rootNode.addChildNode(node)
            }
        }
    }
    
    func captureSession(_ session: LiDARCaptureSession, didFailWithError error: Error) {
        let alert = UIAlertController(
            title: "Capture Error",
            message: error.localizedDescription,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}

// Add extension for point cloud visualization
extension SCNGeometry {
    static func points(from points: [Point]) -> SCNGeometry {
        let vertices = points.map { SCNVector3($0.position.x, $0.position.y, $0.position.z) }
        let vertexData = Data(bytes: vertices, count: vertices.count * MemoryLayout<SCNVector3>.size)
        
        let source = SCNGeometrySource(
            data: vertexData,
            semantic: .vertex,
            vectorCount: vertices.count,
            usesFloatComponents: true,
            componentsPerVector: 3,
            bytesPerComponent: MemoryLayout<Float>.size,
            dataOffset: 0,
            dataStride: MemoryLayout<SCNVector3>.size
        )
        
        let element = SCNGeometryElement(
            data: nil,
            primitiveType: .point,
            primitiveCount: vertices.count,
            bytesPerIndex: 0
        )
        
        let geometry = SCNGeometry(sources: [source], elements: [element])
        let material = SCNMaterial()
        material.diffuse.contents = UIColor.white
        material.lightingModel = .constant  // Disable lighting effects
        geometry.materials = [material]
        
        return geometry
    }
} 