import UIKit
import SceneKit
import LiDARKit

class PointCloudViewController: UIViewController {
    private let pointCloud: PointCloud
    private var sceneView: SCNView!
    private let renderer: PointCloudRenderer
    
    init(pointCloud: PointCloud) {
        self.pointCloud = pointCloud
        self.renderer = SceneKitPointCloudRenderer(configuration: RenderConfiguration(
            pointSize: 10,
            colorScheme: .confidence,
            showNormals: false,
            maxPoints: nil
        ))
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        renderPointCloud()
    }
    
    private func setupUI() {
        view.backgroundColor = .black
        
        // Setup SceneKit view
        sceneView = SCNView(frame: view.bounds)
        sceneView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        sceneView.backgroundColor = .black
        sceneView.antialiasingMode = .multisampling4X
        sceneView.preferredFramesPerSecond = 60
        sceneView.isJitteringEnabled = true
        view.addSubview(sceneView)
        
        // Setup close button
        let closeButton = UIButton(type: .system)
        closeButton.setTitle("Close", for: .normal)
        closeButton.setTitleColor(.white, for: .normal)
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(closeButton)
        
        NSLayoutConstraint.activate([
            closeButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            closeButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            closeButton.widthAnchor.constraint(equalToConstant: 60),
            closeButton.heightAnchor.constraint(equalToConstant: 44)
        ])
        
        closeButton.addTarget(self, action: #selector(closeButtonTapped), for: .touchUpInside)
        
        // Initialize renderer with improved settings
        renderer.initialize(with: sceneView)
    }
    
    private func renderPointCloud() {
        renderer.render(pointCloud)
        
        // Center the camera on the point cloud
        if let sceneView = sceneView {
            let boundingBox = pointCloud.boundingBox
            let center = (boundingBox.min + boundingBox.max) * 0.5
            let size = boundingBox.max - boundingBox.min
            let maxDimension = max(size.x, max(size.y, size.z))
            
            // Position camera to see the entire point cloud
            let cameraNode = sceneView.pointOfView ?? SCNNode()
            cameraNode.camera = SCNCamera()
            cameraNode.position = SCNVector3(
                center.x,
                center.y,
                center.z + maxDimension * 2
            )
            cameraNode.look(at: SCNVector3(center.x, center.y, center.z))
            
            if sceneView.pointOfView == nil {
                sceneView.scene?.rootNode.addChildNode(cameraNode)
                sceneView.pointOfView = cameraNode
            }
        }
    }
    
    @objc private func closeButtonTapped() {
        dismiss(animated: true)
    }
} 