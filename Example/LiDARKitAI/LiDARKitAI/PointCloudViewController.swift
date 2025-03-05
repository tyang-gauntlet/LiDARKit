import UIKit
import SceneKit
import LiDARKit

class PointCloudViewController: UIViewController {
    private let pointCloud: PointCloud
    private var sceneView: SCNView!
    private let renderer: PointCloudRenderer
    private var loadingIndicator: UIActivityIndicatorView!
    
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
        
        // Setup analyze button
        let analyzeButton = UIButton(type: .system)
        analyzeButton.setTitle("Analyze Point Cloud", for: .normal)
        analyzeButton.setTitleColor(.white, for: .normal)
        analyzeButton.backgroundColor = .systemBlue
        analyzeButton.layer.cornerRadius = 8
        analyzeButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(analyzeButton)
        
        // Setup loading indicator
        loadingIndicator = UIActivityIndicatorView(style: .large)
        loadingIndicator.color = .white
        loadingIndicator.hidesWhenStopped = true
        loadingIndicator.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(loadingIndicator)
        
        NSLayoutConstraint.activate([
            closeButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            closeButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            closeButton.widthAnchor.constraint(equalToConstant: 60),
            closeButton.heightAnchor.constraint(equalToConstant: 44),
            
            analyzeButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            analyzeButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            analyzeButton.widthAnchor.constraint(equalToConstant: 180),
            analyzeButton.heightAnchor.constraint(equalToConstant: 50),
            
            loadingIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            loadingIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
        
        closeButton.addTarget(self, action: #selector(closeButtonTapped), for: .touchUpInside)
        analyzeButton.addTarget(self, action: #selector(analyzeButtonTapped), for: .touchUpInside)
        
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
    
    @objc private func analyzeButtonTapped() {
        loadingIndicator.startAnimating()
        
        // Perform analysis in background
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            // Gather point cloud statistics
            let stats = self.analyzePointCloud()
            
            // Generate analysis prompt for OpenAI
            let prompt = """
            Analyze this detailed LiDAR point cloud data and provide specific insights about the captured scene. Here are the statistics:
            
            Basic Information:
            - Total points: \(stats.pointCount)
            - Dimensions: \(String(format: "%.2f", stats.dimensions.x))m × \(String(format: "%.2f", stats.dimensions.y))m × \(String(format: "%.2f", stats.dimensions.z))m
            - Point density: \(String(format: "%.2f", stats.density)) points/m³
            - Average confidence: \(String(format: "%.2f", stats.avgConfidence))
            
            Height Analysis:
            - Floor height: \(String(format: "%.2f", stats.heightDistribution.floorHeight))m
            - Ceiling height: \(String(format: "%.2f", stats.heightDistribution.ceilingHeight))m
            - Room height: \(String(format: "%.2f", stats.heightDistribution.ceilingHeight - stats.heightDistribution.floorHeight))m
            - Height distribution (normalized): \(stats.heightDistribution.heightHistogram.map { String(format: "%.2f", $0) }.joined(separator: ", "))
            
            Plane Analysis:
            - Vertical planes detected: \(stats.planeSummary.verticalPlanes.count)
            - Horizontal planes detected: \(stats.planeSummary.horizontalPlanes.count)
            - Largest vertical plane area: \(String(format: "%.2f", stats.planeSummary.verticalPlanes.first?.area ?? 0))m²
            - Largest horizontal plane area: \(String(format: "%.2f", stats.planeSummary.horizontalPlanes.first?.area ?? 0))m²
            
            Density Analysis:
            - Number of dense regions: \(stats.spatialDensity.denseRegions.count)
            - Number of sparse regions: \(stats.spatialDensity.sparseRegions.count)
            - Average local density: \(String(format: "%.2f", stats.spatialDensity.averageLocalDensity)) points/cell
            
            Based on these detailed statistics, please provide:
            1. A specific description of the environment (room type, layout, dimensions)
            2. Identification of key architectural features (walls, floor, ceiling, openings)
            3. Analysis of potential furniture or objects based on dense regions
            4. Technical assessment of scan quality and coverage
            5. Specific recommendations for improving the scan
            
            Focus on concrete, actionable insights rather than general observations.
            """
            
            let messages = [OpenAIService.Message(role: "user", content: prompt)]
            
            OpenAIService.sendMessage(messages: messages) { [weak self] result in
                DispatchQueue.main.async {
                    self?.loadingIndicator.stopAnimating()
                    
                    switch result {
                    case .success(let response):
                        self?.showAnalysisResults(response)
                    case .failure(let error):
                        self?.showError(message: "Failed to analyze point cloud: \(error.localizedDescription)")
                    }
                }
            }
        }
    }
    
    private func analyzePointCloud() -> PointCloudStatistics {
        let points = pointCloud.points
        let boundingBox = pointCloud.boundingBox
        let dimensions = boundingBox.max - boundingBox.min
        let volume = dimensions.x * dimensions.y * dimensions.z
        
        // Basic statistics
        var totalConfidence: Float = 0
        var pointsWithNormals = 0
        
        for point in points {
            totalConfidence += point.confidence
            if point.normal != nil {
                pointsWithNormals += 1
            }
        }
        
        // Height analysis
        let heights = points.map { $0.position.y }
        let sortedHeights = heights.sorted()
        let floorHeight = sortedHeights.first ?? 0
        let ceilingHeight = sortedHeights.last ?? 0
        let medianHeight = sortedHeights[sortedHeights.count / 2]
        
        // Create height histogram (10 bins)
        var histogram = Array(repeating: 0.0 as Float, count: 10)
        let heightRange = ceilingHeight - floorHeight
        if heightRange > 0 {
            for height in heights {
                let normalizedHeight = (height - floorHeight) / heightRange
                let binIndex = min(9, Int(normalizedHeight * 10))
                histogram[binIndex] += 1
            }
            // Normalize histogram
            let maxCount = histogram.max() ?? 1
            histogram = histogram.map { $0 / Float(maxCount) }
        }
        
        // Plane detection
        let verticalPlanes = detectPlanes(in: points, maxAngleFromVertical: 0.2)
        let horizontalPlanes = detectPlanes(in: points, maxAngleFromVertical: Float.pi/2 - 0.2)
        
        // Spatial density analysis
        let spatialDensity = analyzeSpatialDensity(points: points, boundingBox: boundingBox)
        
        return PointCloudStatistics(
            pointCount: points.count,
            dimensions: dimensions,
            density: Float(points.count) / volume,
            avgConfidence: totalConfidence / Float(points.count),
            normalPercentage: (Float(pointsWithNormals) / Float(points.count)) * 100,
            heightDistribution: HeightDistribution(
                floorHeight: floorHeight,
                ceilingHeight: ceilingHeight,
                medianHeight: medianHeight,
                heightHistogram: histogram
            ),
            planeSummary: PlaneSummary(
                verticalPlanes: verticalPlanes,
                horizontalPlanes: horizontalPlanes,
                dominantPlaneCount: verticalPlanes.count + horizontalPlanes.count
            ),
            spatialDensity: spatialDensity
        )
    }
    
    private func detectPlanes(in points: [Point], maxAngleFromVertical: Float) -> [(center: SIMD3<Float>, normal: SIMD3<Float>, area: Float)] {
        var planes: [(center: SIMD3<Float>, normal: SIMD3<Float>, area: Float)] = []
        var remainingPoints = points
        
        // Simple RANSAC-like plane detection
        while !remainingPoints.isEmpty && planes.count < 5 {  // Limit to top 5 planes
            guard let plane = findLargestPlane(in: remainingPoints, maxAngleFromVertical: maxAngleFromVertical) else {
                break
            }
            planes.append(plane)
            // Remove points belonging to the detected plane
            remainingPoints = remainingPoints.filter { point in
                let vectorToPoint = point.position - plane.center
                let distance = abs(simd_dot(vectorToPoint, plane.normal))
                return distance > 0.1  // 10cm threshold
            }
        }
        
        return planes
    }
    
    private func findLargestPlane(in points: [Point], maxAngleFromVertical: Float) -> (center: SIMD3<Float>, normal: SIMD3<Float>, area: Float)? {
        guard points.count >= 3 else { return nil }
        
        // Simple plane detection using first three non-collinear points
        var bestPlane: (center: SIMD3<Float>, normal: SIMD3<Float>, area: Float)?
        var maxPoints = 0
        
        for _ in 0..<10 {  // Try 10 random seeds
            let randomIndices = (0..<points.count).shuffled().prefix(3)
            let p1 = points[randomIndices[0]].position
            let p2 = points[randomIndices[1]].position
            let p3 = points[randomIndices[2]].position
            
            let v1 = p2 - p1
            let v2 = p3 - p1
            var normal = simd_normalize(simd_cross(v1, v2))
            
            // Ensure normal points upward for horizontal planes
            if abs(simd_dot(normal, SIMD3<Float>(0, 1, 0))) > cos(maxAngleFromVertical) {
                if normal.y < 0 {
                    normal = -normal
                }
            }
            
            // Count points on this plane
            let pointsOnPlane = points.filter { point in
                let vectorToPoint = point.position - p1
                let distance = abs(simd_dot(vectorToPoint, normal))
                return distance < 0.1  // 10cm threshold
            }
            
            if pointsOnPlane.count > maxPoints {
                maxPoints = pointsOnPlane.count
                
                // Calculate center and approximate area
                let center = pointsOnPlane.reduce(SIMD3<Float>(0, 0, 0)) { $0 + $1.position } / Float(pointsOnPlane.count)
                let area = calculatePlaneArea(points: pointsOnPlane.map { $0.position }, normal: normal)
                
                bestPlane = (center: center, normal: normal, area: area)
            }
        }
        
        return bestPlane
    }
    
    private func calculatePlaneArea(points: [SIMD3<Float>], normal: SIMD3<Float>) -> Float {
        // Project points onto plane and calculate convex hull area (simplified)
        // For now, use bounding box as approximation
        let projected = points.map { point in
            let d = simd_dot(point, normal)
            return point - d * normal
        }
        
        let xs = projected.map { $0.x }
        let zs = projected.map { $0.z }
        
        let width = (xs.max() ?? 0) - (xs.min() ?? 0)
        let length = (zs.max() ?? 0) - (zs.min() ?? 0)
        
        return width * length
    }
    
    private func analyzeSpatialDensity(points: [Point], boundingBox: (min: SIMD3<Float>, max: SIMD3<Float>)) -> SpatialDensity {
        let gridSize = 5  // 5x5x5 grid
        var grid = Array(repeating: 0, count: gridSize * gridSize * gridSize)
        let dimensions = boundingBox.max - boundingBox.min
        
        // Assign points to grid cells
        for point in points {
            let normalized = (point.position - boundingBox.min) / dimensions
            let x = min(gridSize - 1, Int(normalized.x * Float(gridSize)))
            let y = min(gridSize - 1, Int(normalized.y * Float(gridSize)))
            let z = min(gridSize - 1, Int(normalized.z * Float(gridSize)))
            let index = x + y * gridSize + z * gridSize * gridSize
            grid[index] += 1
        }
        
        // Find dense and sparse regions
        let avgDensity = Float(points.count) / Float(gridSize * gridSize * gridSize)
        var denseRegions: [(center: SIMD3<Float>, density: Float)] = []
        var sparseRegions: [(center: SIMD3<Float>, density: Float)] = []
        
        for i in 0..<grid.count {
            let density = Float(grid[i])
            let x = Float(i % gridSize)
            let y = Float((i / gridSize) % gridSize)
            let z = Float(i / (gridSize * gridSize))
            
            let center = boundingBox.min + dimensions * SIMD3<Float>(
                (x + 0.5) / Float(gridSize),
                (y + 0.5) / Float(gridSize),
                (z + 0.5) / Float(gridSize)
            )
            
            if density > avgDensity * 2 {
                denseRegions.append((center: center, density: density))
            } else if density < avgDensity * 0.5 {
                sparseRegions.append((center: center, density: density))
            }
        }
        
        // Sort by density and take top 5
        denseRegions.sort { $0.density > $1.density }
        sparseRegions.sort { $0.density < $1.density }
        denseRegions = Array(denseRegions.prefix(5))
        sparseRegions = Array(sparseRegions.prefix(5))
        
        return SpatialDensity(
            denseRegions: denseRegions,
            sparseRegions: sparseRegions,
            averageLocalDensity: avgDensity
        )
    }
    
    private func showAnalysisResults(_ analysis: String) {
        // Format the analysis text for UIAlert by removing markdown and cleaning up the text
        let formattedAnalysis = analysis
            .replacingOccurrences(of: "#", with: "")
            .replacingOccurrences(of: "*", with: "")
            .replacingOccurrences(of: "`", with: "")
            .replacingOccurrences(of: "\n\n", with: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let alertController = UIAlertController(
            title: "Point Cloud Analysis",
            message: formattedAnalysis,
            preferredStyle: .actionSheet
        )
        
        // Configure for iPad
        if let popoverController = alertController.popoverPresentationController {
            popoverController.sourceView = self.view
            popoverController.sourceRect = CGRect(x: self.view.bounds.midX, y: self.view.bounds.midY, width: 0, height: 0)
            popoverController.permittedArrowDirections = []
        }
        
        // Add actions for different visualizations
        alertController.addAction(UIAlertAction(title: "Show Height Map", style: .default) { [weak self] _ in
            self?.updateVisualization(mode: .height)
        })
        
        alertController.addAction(UIAlertAction(title: "Show Density", style: .default) { [weak self] _ in
            self?.updateVisualization(mode: .density)
        })
        
        alertController.addAction(UIAlertAction(title: "Show Planes", style: .default) { [weak self] _ in
            self?.updateVisualization(mode: .planes)
        })
        
        alertController.addAction(UIAlertAction(title: "Reset View", style: .default) { [weak self] _ in
            self?.updateVisualization(mode: .normal)
        })
        
        alertController.addAction(UIAlertAction(title: "OK", style: .cancel))
        
        present(alertController, animated: true)
    }
    
    private func updateVisualization(mode: VisualizationMode) {
        let config = RenderConfiguration(
            pointSize: 10,
            colorScheme: getColorScheme(for: mode),
            showNormals: mode == .planes,
            maxPoints: nil
        )
        renderer.updateConfiguration(config)
        renderer.render(pointCloud) // Re-render with new configuration
    }
    
    private func getColorScheme(for mode: VisualizationMode) -> RenderConfiguration.ColorScheme {
        switch mode {
        case .normal:
            return .confidence
        case .height:
            return .height
        case .density:
            return .rgb
        case .planes:
            return .uniform(UIColor.systemBlue)
        }
    }
    
    private func showError(message: String) {
        let alert = UIAlertController(
            title: "Error",
            message: message,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}

// Structure to hold point cloud statistics
struct PointCloudStatistics {
    let pointCount: Int
    let dimensions: SIMD3<Float>
    let density: Float
    let avgConfidence: Float
    let normalPercentage: Float
    let heightDistribution: HeightDistribution
    let planeSummary: PlaneSummary
    let spatialDensity: SpatialDensity
}

struct HeightDistribution {
    let floorHeight: Float
    let ceilingHeight: Float
    let medianHeight: Float
    let heightHistogram: [Float]  // Normalized height distribution
}

struct PlaneSummary {
    let verticalPlanes: [(center: SIMD3<Float>, normal: SIMD3<Float>, area: Float)]
    let horizontalPlanes: [(center: SIMD3<Float>, normal: SIMD3<Float>, area: Float)]
    let dominantPlaneCount: Int
}

struct SpatialDensity {
    let denseRegions: [(center: SIMD3<Float>, density: Float)]
    let sparseRegions: [(center: SIMD3<Float>, density: Float)]
    let averageLocalDensity: Float
}

enum VisualizationMode {
    case normal
    case height
    case density
    case planes
} 