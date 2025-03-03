import Foundation

public protocol PointCloudStorage {
    /// Save a point cloud to storage
    func save(_ pointCloud: PointCloud, withIdentifier identifier: String) async throws
    
    /// Load a point cloud from storage
    func load(identifier: String) async throws -> PointCloud
    
    /// Delete a point cloud from storage
    func delete(identifier: String) async throws
    
    /// List all stored point cloud identifiers
    func listStoredPointClouds() async throws -> [String]
}

public enum StorageError: Error {
    case invalidIdentifier
    case fileNotFound
    case invalidData
    case storageError(Error)
}

/// File-based storage implementation for point clouds
public class FilePointCloudStorage: PointCloudStorage {
    private let fileManager: FileManager
    private let storageURL: URL
    
    public init(storageDirectory: URL? = nil) throws {
        self.fileManager = .default
        
        if let storageDirectory {
            self.storageURL = storageDirectory
        } else {
            // Use the app's Documents directory by default
            self.storageURL = try fileManager
                .url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
                .appendingPathComponent("PointClouds", isDirectory: true)
        }
        
        // Create storage directory if it doesn't exist
        try? fileManager.createDirectory(at: storageURL, withIntermediateDirectories: true)
    }
    
    public func save(_ pointCloud: PointCloud, withIdentifier identifier: String) async throws {
        guard identifier.isEmpty == false else {
            throw StorageError.invalidIdentifier
        }
        
        // Create a metadata dictionary
        let metadata: [String: Any] = [
            "timestamp": pointCloud.timestamp,
            "pointCount": pointCloud.count,
            "metadata": pointCloud.metadata,
            "transform": pointCloud.transform
        ]
        
        // Save metadata
        let metadataURL = fileURL(for: identifier, extension: "metadata")
        try JSONSerialization.data(withJSONObject: metadata)
            .write(to: metadataURL)
        
        // Save point cloud data using PLY format for efficiency
        let dataURL = fileURL(for: identifier, extension: "ply")
        let exporter = PLYExporter(format: .binary)
        try exporter.write(pointCloud, to: dataURL)
    }
    
    public func load(identifier: String) async throws -> PointCloud {
        guard identifier.isEmpty == false else {
            throw StorageError.invalidIdentifier
        }
        
        let dataURL = fileURL(for: identifier, extension: "ply")
        let metadataURL = fileURL(for: identifier, extension: "metadata")
        
        guard fileManager.fileExists(atPath: dataURL.path),
              fileManager.fileExists(atPath: metadataURL.path) else {
            throw StorageError.fileNotFound
        }
        
        // Load metadata
        let metadataData = try Data(contentsOf: metadataURL)
        guard let metadata = try JSONSerialization.jsonObject(with: metadataData) as? [String: Any] else {
            throw StorageError.invalidData
        }
        
        // TODO: Implement PLY importer and use it here
        // For now, this is a placeholder that will need to be implemented
        throw StorageError.invalidData
    }
    
    public func delete(identifier: String) async throws {
        guard identifier.isEmpty == false else {
            throw StorageError.invalidIdentifier
        }
        
        let dataURL = fileURL(for: identifier, extension: "ply")
        let metadataURL = fileURL(for: identifier, extension: "metadata")
        
        try? fileManager.removeItem(at: dataURL)
        try? fileManager.removeItem(at: metadataURL)
    }
    
    public func listStoredPointClouds() async throws -> [String] {
        let contents = try fileManager.contentsOfDirectory(at: storageURL, includingPropertiesForKeys: nil)
        return contents
            .filter { $0.pathExtension == "metadata" }
            .map { $0.deletingPathExtension().lastPathComponent }
    }
    
    private func fileURL(for identifier: String, extension: String) -> URL {
        storageURL.appendingPathComponent(identifier).appendingPathExtension(`extension`)
    }
} 