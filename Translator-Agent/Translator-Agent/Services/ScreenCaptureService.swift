import SwiftUI
import ScreenCaptureKit
import CoreImage
import OSLog

class ScreenCaptureService: NSObject, ObservableObject {
    private let logger = Logger(subsystem: "Abhi.Translator-Agent", category: "ScreenCapture")
    private var isPermissionChecked = false
    
    /// Checks if screen recording permission is granted
    func checkScreenCapturePermission() async -> Bool {
        if isPermissionChecked {
            logger.debug("Permission already checked, returning cached result")
            return true
        }
        
        do {
            // Try to get the current shareable content
            let content = try await SCShareableContent.current
            // If we get here, permission is granted
            logger.debug("Screen capture permission granted")
            isPermissionChecked = true
            return true
        } catch {
            // If we get an error, permission is likely denied
            logger.error("Screen capture permission error: \(error.localizedDescription)")
            await promptForPermission()
            return false
        }
    }
    
    /// Prompts the user to grant screen recording permissions
    @MainActor
    private func promptForPermission() {
        let alert = NSAlert()
        alert.messageText = "Screen Recording Permission Required"
        alert.informativeText = "Please grant screen recording permission in System Settings → Privacy & Security → Screen Recording."
        alert.addButton(withTitle: "Open System Settings")
        alert.addButton(withTitle: "Cancel")
        
        if alert.runModal() == .alertFirstButtonReturn {
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
                NSWorkspace.shared.open(url)
            }
        }
    }
    
    /// Captures the screen
    func captureScreen() async throws -> CGImage? {
        logger.debug("Starting screen capture process...")
        
        // Check permission
        guard await checkScreenCapturePermission() else {
            logger.error("Screen capture permission not granted")
            throw ScreenCaptureError.permissionDenied
        }
        
        // Get shareable content
        let shareable = try await SCShareableContent.current
        logger.debug("Got shareable content")
        
        // Get the main display
        guard let display = shareable.displays.first else {
            logger.error("No display found")
            throw ScreenCaptureError.noDisplayFound
        }
        logger.debug("Found display: \(display.width)x\(display.height)")
        
        // Filter applications to keep only KakaoTalk and exclude everything else
        let kakaoApp = shareable.applications.first { 
            $0.bundleIdentifier.contains("KakaoTalk") 
        }
        
        let excludedApps = shareable.applications.filter { app in
            // Keep KakaoTalk, exclude everything else
            !app.bundleIdentifier.contains("KakaoTalk")
        }
        
        // Create content filter that excludes all apps except KakaoTalk
        let myContentFilter = SCContentFilter(
            display: display,
            excludingApplications: excludedApps,
            exceptingWindows: []
        )
        
        let myConfiguration = SCStreamConfiguration()
        myConfiguration.width = Int(display.width)
        myConfiguration.height = Int(display.height)
        myConfiguration.minimumFrameInterval = CMTime(value: 1, timescale: 1)
        myConfiguration.queueDepth = 1
        myConfiguration.pixelFormat = kCVPixelFormatType_32BGRA
        myConfiguration.showsCursor = false  // Changed to false since we don't need cursor
        
        // Call the screenshot API and get your screenshot image
        if let screenshot = try? await SCScreenshotManager.captureSampleBuffer(
            contentFilter: myContentFilter,
            configuration: myConfiguration
        ) {
            // Convert CMSampleBuffer to CGImage
            if let imageBuffer = CMSampleBufferGetImageBuffer(screenshot) {
                let ciImage = CIImage(cvPixelBuffer: imageBuffer)
                let context = CIContext(options: nil)
                if let cgImage = context.createCGImage(ciImage, from: ciImage.extent) {
                    logger.debug("Screenshot captured successfully")
                    return cgImage
                }
            }
        }
        
        logger.error("Failed to capture screenshot")
        throw ScreenCaptureError.captureError
    }
    
    /// Converts a CGImage to NSImage for display in SwiftUI
    func convertToNSImage(from cgImage: CGImage) -> NSImage {
        NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
    }
}

// Custom error types for better error handling
enum ScreenCaptureError: Error, LocalizedError {
    case permissionDenied
    case noDisplayFound
    case captureError
    
    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "Screen recording permission not granted"
        case .noDisplayFound:
            return "No display found to capture"
        case .captureError:
            return "Failed to capture screenshot"
        }
    }
}
