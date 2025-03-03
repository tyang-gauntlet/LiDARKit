import Foundation
import SceneKit
import ARKit

public protocol PointCloudRenderer: AnyObject {
    /// Initialize the renderer with a view
    func initialize(with view: SCNView)
    
    /// Render a point cloud
    func render(_ pointCloud: PointCloud)
    
    /// Update the rendering configuration
    func updateConfiguration(_ config: RenderConfiguration)
    
    /// Clear the current rendering
    func clear()
}

public struct RenderConfiguration {
    /// Size of points in the visualization
    public var pointSize: CGFloat
    
    /// Color scheme for points
    public var colorScheme: ColorScheme
    
    /// Whether to show normals
    public var showNormals: Bool
    
    /// Maximum number of points to render (for performance)
    public var maxPoints: Int?
    
    public init(
        pointSize: CGFloat = 3,
        colorScheme: ColorScheme = .confidence,
        showNormals: Bool = false,
        maxPoints: Int? = nil
    ) {
        self.pointSize = pointSize
        self.colorScheme = colorScheme
        self.showNormals = showNormals
        self.maxPoints = maxPoints
    }
    
    public enum ColorScheme {
        case uniform(UIColor)
        case confidence
        case height
        case intensity
        case rgb
    }
}

public class SceneKitPointCloudRenderer: PointCloudRenderer {
    private var sceneView: SCNView?
    private var pointsNode: SCNNode?
    private var configuration: RenderConfiguration
    
    public init(configuration: RenderConfiguration = RenderConfiguration()) {
        self.configuration = configuration
    }
    
    public func initialize(with view: SCNView) {
        self.sceneView = view
        
        // Setup scene
        let scene = SCNScene()
        view.scene = scene
        view.backgroundColor = .black
        
        // Setup camera
        let camera = SCNCamera()
        let cameraNode = SCNNode()
        cameraNode.camera = camera
        cameraNode.position = SCNVector3(0, 0, 2)
        scene.rootNode.addChildNode(cameraNode)
        
        // Setup lighting
        let light = SCNLight()
        light.type = .omni
        let lightNode = SCNNode()
        lightNode.light = light
        lightNode.position = SCNVector3(0, 10, 10)
        scene.rootNode.addChildNode(lightNode)
        
        // Enable default camera controls
        view.allowsCameraControl = true
        view.showsStatistics = true
    }
    
    public func render(_ pointCloud: PointCloud) {
        guard let sceneView = sceneView else { return }
        
        // Remove existing points
        pointsNode?.removeFromParentNode()
        
        // Create geometry for points
        let vertices = pointCloud.points.map { SCNVector3($0.position) }
        let colors = pointCloud.points.map { point -> UIColor in
            switch configuration.colorScheme {
            case .uniform(let color):
                return color
            case .confidence:
                return UIColor(white: CGFloat(point.confidence), alpha: 1)
            case .height:
                return colorForHeight(point.position.y)
            case .intensity:
                return UIColor(white: CGFloat(point.intensity ?? 0), alpha: 1)
            case .rgb:
                if let color = point.color {
                    return UIColor(
                        red: CGFloat(color.x) / 255,
                        green: CGFloat(color.y) / 255,
                        blue: CGFloat(color.z) / 255,
                        alpha: CGFloat(color.w) / 255
                    )
                }
                return .white
            }
        }
        
        let geometry = createPointGeometry(
            vertices: vertices,
            colors: colors,
            pointSize: configuration.pointSize
        )
        
        // Create and add node
        let node = SCNNode(geometry: geometry)
        node.transform = SCNMatrix4(pointCloud.transform)
        sceneView.scene?.rootNode.addChildNode(node)
        pointsNode = node
        
        if configuration.showNormals {
            addNormalLines(for: pointCloud, to: node)
        }
    }
    
    public func updateConfiguration(_ config: RenderConfiguration) {
        self.configuration = config
        if let pointCloud = currentPointCloud {
            render(pointCloud)
        }
    }
    
    public func clear() {
        pointsNode?.removeFromParentNode()
        pointsNode = nil
    }
    
    // MARK: - Private
    
    private var currentPointCloud: PointCloud?
    
    private func createPointGeometry(
        vertices: [SCNVector3],
        colors: [UIColor],
        pointSize: CGFloat
    ) -> SCNGeometry {
        let vertexSource = SCNGeometrySource(
            vertices: vertices,
            count: vertices.count
        )
        
        let colorData = colors.map { color -> NSData in
            var red: CGFloat = 0
            var green: CGFloat = 0
            var blue: CGFloat = 0
            var alpha: CGFloat = 0
            color.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
            
            var colorArray: [Float] = [Float(red), Float(green), Float(blue), Float(alpha)]
            return NSData(bytes: &colorArray, length: MemoryLayout<Float>.size * 4)
        }
        
        let colorSource = SCNGeometrySource(
            data: NSMutableData(data: colorData.reduce(Data(), { $0 + ($1 as Data) })),
            semantic: .color,
            vectorCount: colors.count,
            usesFloatComponents: true,
            componentsPerVector: 4,
            bytesPerComponent: MemoryLayout<Float>.size,
            dataOffset: 0,
            dataStride: MemoryLayout<Float>.size * 4
        )
        
        let indices = (0..<vertices.count).map { UInt32($0) }
        let element = SCNGeometryElement(
            indices: indices,
            primitiveType: .point
        )
        
        let geometry = SCNGeometry(sources: [vertexSource, colorSource], elements: [element])
        
        // Set point size
        let program = SCNProgram()
        program.vertexFunctionName = "pointVertex"
        program.fragmentFunctionName = "pointFragment"
        geometry.program = program
        
        geometry.setValue(NSNumber(value: Float(pointSize)), forKey: "pointSize")
        
        return geometry
    }
    
    private func colorForHeight(_ height: Float) -> UIColor {
        // Simple height-based coloring
        let hue = (height + 1) / 2 // Normalize to 0-1
        return UIColor(hue: CGFloat(hue), saturation: 1, brightness: 1, alpha: 1)
    }
    
    private func addNormalLines(for pointCloud: PointCloud, to parentNode: SCNNode) {
        for point in pointCloud.points {
            guard let normal = point.normal else { continue }
            
            let start = point.position
            let end = start + normal * 0.05 // Scale normal vector
            
            let vertices = [
                SCNVector3(start),
                SCNVector3(end)
            ]
            
            let source = SCNGeometrySource(vertices: vertices)
            let element = SCNGeometryElement(
                indices: [0, 1],
                primitiveType: .line
            )
            
            let geometry = SCNGeometry(sources: [source], elements: [element])
            let node = SCNNode(geometry: geometry)
            parentNode.addChildNode(node)
        }
    }
} 