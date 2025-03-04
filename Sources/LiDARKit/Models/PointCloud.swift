import Foundation
import simd

/// Represents a single point in 3D space with associated attributes
public struct Point: Sendable {
    /// 3D coordinates using SIMD for better performance
    public let position: SIMD3<Float>
    
    /// Normal vector of the point (surface orientation)
    public let normal: SIMD3<Float>?
    
    /// Confidence value from LiDAR sensor (0-1)
    public let confidence: Float
    
    /// Optional color data (RGBA)
    public let color: SIMD4<UInt8>?
    
    /// Optional intensity value
    public let intensity: Float?
    
    /// Creates a new point with the specified attributes
    /// - Parameters:
    ///   - position: 3D position of the point
    ///   - normal: Optional normal vector
    ///   - confidence: Confidence value (0-1)
    ///   - color: Optional RGBA color
    ///   - intensity: Optional intensity value
    public init(
        position: SIMD3<Float>,
        normal: SIMD3<Float>? = nil,
        confidence: Float,
        color: SIMD4<UInt8>? = nil,
        intensity: Float? = nil
    ) {
        self.position = position
        self.normal = normal
        self.confidence = confidence
        self.color = color
        self.intensity = intensity
    }
}

/// Represents a collection of 3D points with associated metadata
public struct PointCloud: Sendable {
    /// Array of points in the cloud
    public private(set) var points: [Point]
    
    /// Timestamp when the point cloud was captured
    public let timestamp: Date
    
    /// Metadata about the capture
    public let metadata: [String: Any]
    
    /// Transform matrix representing the point cloud's position and orientation
    public var transform: simd_float4x4
    
    /// Creates a new point cloud with the specified attributes
    /// - Parameters:
    ///   - points: Array of points
    ///   - timestamp: Capture timestamp
    ///   - metadata: Additional metadata
    ///   - transform: Transform matrix
    public init(
        points: [Point],
        timestamp: Date = Date(),
        metadata: [String: Any] = [:],
        transform: simd_float4x4 = matrix_identity_float4x4
    ) {
        self.points = points
        self.timestamp = timestamp
        self.metadata = metadata
        self.transform = transform
    }
}

// MARK: - PointCloud Extensions
public extension PointCloud {
    /// Returns the number of points in the cloud
    var count: Int {
        points.count
    }
    
    /// Returns the bounding box of the point cloud
    var boundingBox: (min: SIMD3<Float>, max: SIMD3<Float>) {
        guard let firstPoint = points.first else {
            return (SIMD3<Float>(repeating: 0), SIMD3<Float>(repeating: 0))
        }
        
        var minPoint = firstPoint.position
        var maxPoint = firstPoint.position
        
        for point in points {
            minPoint = min(minPoint, point.position)
            maxPoint = max(maxPoint, point.position)
        }
        
        return (minPoint, maxPoint)
    }
    
    /// Returns the center point of the point cloud
    var center: SIMD3<Float> {
        let box = boundingBox
        return (box.min + box.max) * 0.5
    }
    
    /// Filters points based on a predicate
    /// - Parameter isIncluded: Closure that determines if a point should be included
    /// - Returns: A new point cloud with filtered points
    func filtered(where isIncluded: (Point) -> Bool) -> PointCloud {
        var newCloud = self
        newCloud.points = points.filter(isIncluded)
        return newCloud
    }
} 