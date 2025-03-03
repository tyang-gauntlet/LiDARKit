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
    
    private let session = ARSession()
    private let configuration = ARWorldTrackingConfiguration()
    public weak var delegate: LiDARCaptureDelegate?
    
    public var isRunning: Bool {
        session.currentFrame != nil
    }
    
    public override init() {
        super.init()
        setupSession()
    }
    
    private func setupSession() {
        session.delegate = self
        
        guard ARWorldTrackingConfiguration.supportsFrameSemantics(.sceneDepth) else {
            delegate?.captureSession(self, didFailWithError: CaptureError.deviceNotSupported)
            return
        }
        
        configuration.frameSemantics = .sceneDepth
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
        
        // Process depth data and create points
        // This is a simplified version - in practice, you'd want to:
        // 1. Use vImage or Metal for faster processing
        // 2. Implement proper depth to world space conversion
        // 3. Add filtering for noisy points
        // 4. Handle confidence values properly
        
        return points
    }
}

extension LiDARCaptureSession: ARSessionDelegate {
    public func session(_ session: ARSession, didFailWithError error: Error) {
        delegate?.captureSession(self, didFailWithError: error)
    }
    
    public func session(_ session: ARSession, didUpdate frame: ARFrame) {
        guard let depthMap = frame.sceneDepth?.depthMap,
              let confidenceMap = frame.sceneDepth?.confidenceMap else {
            return
        }
        
        let points = processDepthMap(depthMap, confidence: confidenceMap)
        let pointCloud = PointCloud(
            points: points,
            metadata: [
                "captureDevice": "LiDAR",
                "frameNumber": frame.timestamp
            ],
            transform: frame.camera.transform
        )
        
        delegate?.captureSession(self, didCapturePointCloud: pointCloud)
    }
} 