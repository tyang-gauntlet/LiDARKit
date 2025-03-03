import Foundation
import simd

public struct Point {
    /// 3D coordinates using SIMD for better performance
    public let position: SIMD3<Float>
    
    /// Normal vector of the point
    public let normal: SIMD3<Float>?
    
    /// Confidence value from LiDAR sensor (0-1)
    public let confidence: Float
    
    /// Optional color data
    public let color: SIMD4<UInt8>?
    
    /// Optional intensity value
    public let intensity: Float?
}

public struct PointCloud {
    /// Array of points in the cloud
    public private(set) var points: [Point]
    
    /// Timestamp when the point cloud was captured
    public let timestamp: Date
    
    /// Metadata about the capture
    public let metadata: [String: Any]
    
    /// Transform matrix representing the point cloud's position and orientation
    public var transform: simd_float4x4
    
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
} 