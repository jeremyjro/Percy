//
//  TextSelectionMonitor.swift
//  cursor-buddy
//
//  Monitors for text selection events system-wide using macOS Accessibility API.
//  Captures selected text and surrounding context from any application when
//  the user triggers the text explanation feature.
//

import AppKit
import Foundation
import Combine

/// Information about a text selection captured from any application
struct TextSelectionInfo: Sendable {
    let selectedText: String
    let surroundingContext: String
    let applicationName: String
    let selectionLocation: CGPoint
    let timestamp: Date
}

/// Result of a text selection capture attempt
enum TextSelectionCaptureResult {
    case success(TextSelectionInfo)
    case noSelection
    case permissionDenied
    case applicationNotSupported(String)
    case error(String)
}

/// Monitors for text selection events using macOS Accessibility API
@MainActor
final class TextSelectionMonitor: ObservableObject {
    @Published private(set) var lastCapturedSelection: TextSelectionInfo?
    @Published private(set) var isMonitoring = false
    
    // Context window size - how much surrounding text to capture
    private let contextWindowSize = 500 // characters before and after selection
    
    init() {
        // Simplified initialization - we'll check accessibility when needed
        print("✅ TextSelectionMonitor: Initialized")
    }
    
    /// Captures the currently selected text from the focused application
    func captureSelectedText() -> TextSelectionCaptureResult {
        guard AXIsProcessTrusted() else {
            return .permissionDenied
        }
        
        guard let focusedApp = NSWorkspace.shared.frontmostApplication else {
            return .error("No focused application")
        }
        
        let appName = focusedApp.localizedName ?? "Unknown"
        
        // Try to get selected text from the clipboard (most reliable method)
        if let selectedText = getSelectedTextFromClipboard() {
            // Get cursor location for positioning the explanation
            let cursorLocation = NSEvent.mouseLocation
            
            let selectionInfo = TextSelectionInfo(
                selectedText: selectedText,
                surroundingContext: selectedText, // Simplified - use selected text as context
                applicationName: appName,
                selectionLocation: cursorLocation,
                timestamp: Date()
            )
            
            lastCapturedSelection = selectionInfo
            return .success(selectionInfo)
        }
        
        return .noSelection
    }
    
    /// Gets selected text from clipboard (most reliable cross-application method)
    private func getSelectedTextFromClipboard() -> String? {
        let pasteboard = NSPasteboard.general
        guard let text = pasteboard.string(forType: .string), !text.isEmpty else {
            return nil
        }
        return text
    }
    
    /// Stops monitoring for text selection
    func stopMonitoring() {
        isMonitoring = false
        print("🛑 TextSelectionMonitor: Stopped monitoring")
    }
    
    deinit {
        stopMonitoring()
    }
}