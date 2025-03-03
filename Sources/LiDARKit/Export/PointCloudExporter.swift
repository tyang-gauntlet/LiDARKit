import Foundation

public protocol PointCloudExporter {
    func export(_ pointCloud: PointCloud) throws -> Data
    func write(_ pointCloud: PointCloud, to url: URL) throws
}

public enum ExportError: Error {
    case invalidFormat
    case writeError
    case unsupportedFormat
}

public class PLYExporter: PointCloudExporter {
    public enum Format {
        case ascii
        case binary
    }
    
    private let format: Format
    
    public init(format: Format = .binary) {
        self.format = format
    }
    
    public func export(_ pointCloud: PointCloud) throws -> Data {
        var output = Data()
        
        // Write PLY header
        let header = """
        ply
        format \(format == .ascii ? "ascii" : "binary_little_endian") 1.0
        element vertex \(pointCloud.count)
        property float x
        property float y
        property float z
        property float nx
        property float ny
        property float nz
        property float confidence
        property uchar red
        property uchar green
        property uchar blue
        property uchar alpha
        end_header
        
        """
        
        output.append(header.data(using: .ascii)!)
        
        // Write vertex data
        for point in pointCloud.points {
            switch format {
            case .ascii:
                let line = String(
                    format: "%f %f %f %f %f %f %f %d %d %d %d\n",
                    point.position.x,
                    point.position.y,
                    point.position.z,
                    point.normal?.x ?? 0,
                    point.normal?.y ?? 0,
                    point.normal?.z ?? 0,
                    point.confidence,
                    point.color?.x ?? 255,
                    point.color?.y ?? 255,
                    point.color?.z ?? 255,
                    point.color?.w ?? 255
                )
                output.append(line.data(using: .ascii)!)
                
            case .binary:
                var vertex = point.position
                output.append(Data(bytes: &vertex, count: MemoryLayout<SIMD3<Float>>.size))
                
                var normal = point.normal ?? SIMD3<Float>(repeating: 0)
                output.append(Data(bytes: &normal, count: MemoryLayout<SIMD3<Float>>.size))
                
                var confidence = point.confidence
                output.append(Data(bytes: &confidence, count: MemoryLayout<Float>.size))
                
                var color = point.color ?? SIMD4<UInt8>(repeating: 255)
                output.append(Data(bytes: &color, count: MemoryLayout<SIMD4<UInt8>>.size))
            }
        }
        
        return output
    }
    
    public func write(_ pointCloud: PointCloud, to url: URL) throws {
        let data = try export(pointCloud)
        try data.write(to: url)
    }
}

// Factory for creating exporters based on file extension
public enum PointCloudExporterFactory {
    public static func exporter(for url: URL) throws -> PointCloudExporter {
        switch url.pathExtension.lowercased() {
        case "ply":
            return PLYExporter()
        // Add support for other formats here
        default:
            throw ExportError.unsupportedFormat
        }
    }
} 