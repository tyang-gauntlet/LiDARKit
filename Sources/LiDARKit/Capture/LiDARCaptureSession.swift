import Foundation
import ARKit

public protocol LiDARCaptureDelegate: AnyObject {
    func captureSession(_ session: LiDARCaptureSession, didCapturePointCloud pointCloud: PointCloud)
    func captureSession(_ session: LiDARCaptureSession, didFailWithError error: Error)
}

public class LiDARCaptureSession: NSObject {
    public enum CaptureError: Error {
        case deviceNotSupported
        case sessionConfigurationFailed
        case noDepthDataAvailable
    }
    
    private let session: ARSession
    private let configuration: ARWorldTrackingConfiguration
    public weak var delegate: LiDARCaptureDelegate?
    
    public var isRunning: Bool {
        session.currentFrame != nil
    }
    
    public init(session: ARSession? = nil) {
        self.session = session ?? ARSession()
        self.configuration = ARWorldTrackingConfiguration()
        super.init()
        setupSession()
    }
    
    private func setupSession() {
        session.delegate = self
        
        guard ARWorldTrackingConfiguration.supportsFrameSemantics(.sceneDepth) else {
            delegate?.captureSession(self, didFailWithError: CaptureError.deviceNotSupported)
            return
        }
        
        // Enable both scene depth and smoothed scene depth
        configuration.frameSemantics = [.sceneDepth, .smoothedSceneDepth]
    }
    
    public func startCapture() {
        session.run(configuration)
    }
    
    public func stopCapture() {
        session.pause()
    }
    
    private func processDepthMap(_ depthMap: CVPixelBuffer, confidence: CVPixelBuffer?) -> [Point] {
        var points: [Point] = []
        let width = CVPixelBufferGetWidth(depthMap)
        let height = CVPixelBufferGetHeight(depthMap)
        
        CVPixelBufferLockBaseAddress(depthMap, .readOnly)
        if let confidence {
            CVPixelBufferLockBaseAddress(confidence, .readOnly)
        }
        
        defer {
            CVPixelBufferUnlockBaseAddress(depthMap, .readOnly)
            if let confidence {
                CVPixelBufferUnlockBaseAddress(confidence, .readOnly)
            }
        }
        
        // Get base address of depth and confidence buffers
        guard let depthData = CVPixelBufferGetBaseAddress(depthMap) else { return points }
        
        let confidenceData = confidence.flatMap { buffer -> UnsafeMutableRawPointer? in
            CVPixelBufferGetBaseAddress(buffer)
        }
        
        // Get bytes per row for efficient traversal
        let depthBytesPerRow = CVPixelBufferGetBytesPerRow(depthMap)
        let confidenceBytesPerRow = confidence.map { CVPixelBufferGetBytesPerRow($0) } ?? 0
        
        // Create arrays to store echo data
        var echoPoints: [(position: SIMD3<Float>, confidence: Float)] = []
        
        // Process depth data
        for y in 0..<height {
            for x in 0..<width {
                let depthOffset = y * depthBytesPerRow + x * MemoryLayout<Float32>.size
                let confidenceOffset = y * confidenceBytesPerRow + x * MemoryLayout<UInt8>.size
                
                // Get depth value
                let depth = depthData.load(fromByteOffset: depthOffset, as: Float32.self)
                
                // Skip if depth is invalid - more lenient range
                guard depth > 0 && depth < 20.0 else { continue }
                
                // Get confidence value
                var normalizedConfidence: Float = 1.0
                if let confidenceData = confidenceData {
                    let confidenceValue = confidenceData.load(fromByteOffset: confidenceOffset, as: UInt8.self)
                    normalizedConfidence = Float(confidenceValue) / 255.0
                }
                
                // Convert to camera space coordinates
                let normalizedX = (2.0 * Float(x) / Float(width)) - 1.0
                let normalizedY = 1.0 - (2.0 * Float(y) / Float(height))
                
                let position = SIMD3<Float>(
                    normalizedX * depth,
                    normalizedY * depth,
                    -depth  // Negative Z is forward in camera space
                )
                
                echoPoints.append((position: position, confidence: normalizedConfidence))
            }
        }
        
        // Take all points - no sorting by confidence
        points = echoPoints.map { echo in
            Point(
                position: echo.position,
                confidence: echo.confidence
            )
        }
        
        return points
    }
}

extension LiDARCaptureSession: ARSessionDelegate {
    public func session(_ session: ARSession, didFailWithError error: Error) {
        delegate?.captureSession(self, didFailWithError: error)
    }
    
    public func session(_ session: ARSession, didUpdate frame: ARFrame) {
        // Process frame on background queue to avoid blocking main thread
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self,
                  let depthMap = frame.sceneDepth?.depthMap,
                  let confidenceMap = frame.sceneDepth?.confidenceMap else {
                return
            }
            
            let points = self.processDepthMap(depthMap, confidence: confidenceMap)
            
            // Create point cloud on main thread to ensure proper memory management
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                
                let pointCloud = PointCloud(
                    points: points,
                    metadata: [
                        "captureDevice": "LiDAR",
                        "frameNumber": "\(frame.timestamp)"
                    ],
                    transform: frame.camera.transform
                )
                
                self.delegate?.captureSession(self, didCapturePointCloud: pointCloud)
            }
        }
    }
} 