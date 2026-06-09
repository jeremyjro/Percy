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
    
    private var accessibilityObserver: AXObserver?
    private var focusedApplicationObserver: AXObserver?
    private var monitoredElement: AXUIElement?
    
    // Context window size - how much surrounding text to capture
    private let contextWindowSize = 500 // characters before and after selection
    
    init() {
        setupAccessibilityMonitoring()
    }
    
    /// Sets up accessibility observers for text selection monitoring
    private func setupAccessibilityMonitoring() {
        guard AXIsProcessTrusted() else {
            print("⚠️ TextSelectionMonitor: Accessibility permissions not granted")
            return
        }
        
        // Monitor focused application changes
        setupFocusedApplicationObserver()
        
        print("✅ TextSelectionMonitor: Accessibility monitoring initialized")
    }
    
    /// Sets up observer for when the focused application changes
    private func setupFocusedApplicationObserver() {
        let callback: AXObserverCallback = { (observer, element, notification, refcon) in
            Task { @MainActor in
                // Handle application focus change
                print("📱 TextSelectionMonitor: Focused application changed")
            }
        }
        
        let focusedApp = NSWorkspace.shared.frontmostApplication
        guard let appElement = focusedApp?.axUIElement else {
            print("⚠️ TextSelectionMonitor: Could not get focused app element")
            return
        }
        
        var observer: AXObserver?
        let result = AXObserverCreate(appElement.processIdentifier, callback, &observer)
        
        if result == .success {
            self.focusedApplicationObserver = observer
            AXObserverAddNotification(observer, appElement, kAXFocusedApplicationChangedNotification as CFString, Unmanaged.passUnretained(self).toOpaque())
            AXObserverAddNotification(observer, appElement, kAXFocusedWindowChangedNotification as CFString, Unmanaged.passUnretained(self).toOpaque())
            CFRunLoopAddSource(CFRunLoopGetCurrent(), AXObserverGetRunLoopSource(observer), .commonModes)
            
            // Store the monitored element
            monitoredElement = appElement
            isMonitoring = true
        } else {
            print("⚠️ TextSelectionMonitor: Failed to create observer: \(result.rawValue)")
        }
    }
    
    /// Captures the currently selected text from the focused application
    func captureSelectedText() -> TextSelectionCaptureResult {
        guard AXIsProcessTrusted() else {
            return .permissionDenied
        }
        
        guard let focusedApp = NSWorkspace.shared.frontmostApplication else {
            return .error("No focused application")
        }
        
        let appElement = focusedApp.axUIElement
        let appName = focusedApp.localizedName ?? "Unknown"
        
        // Get the focused window
        guard let focusedWindow = getFocusedWindow(from: appElement) else {
            return .error("Could not get focused window")
        }
        
        // Try to get selected text using various methods
        if let selectedText = getSelectedText(from: focusedWindow) {
            // Get surrounding context
            let context = getSurroundingContext(from: focusedWindow, selectedText: selectedText)
            
            // Get cursor location for positioning the explanation
            let cursorLocation = NSEvent.mouseLocation
            
            let selectionInfo = TextSelectionInfo(
                selectedText: selectedText,
                surroundingContext: context,
                applicationName: appName,
                selectionLocation: cursorLocation,
                timestamp: Date()
            )
            
            lastCapturedSelection = selectionInfo
            return .success(selectionInfo)
        }
        
        return .noSelection
    }
    
    /// Gets the focused window from an application element
    private func getFocusedWindow(from appElement: AXUIElement) -> AXUIElement? {
        var focusedWindow: AnyObject?
        let result = AXUIElementCopyAttributeValue(appElement, kAXFocusedWindowAttribute as CFString, &focusedWindow)
        
        if result == .success, let window = focusedWindow as? AXUIElement {
            return window
        }
        
        return nil
    }
    
    /// Gets selected text from an AX element using multiple methods
    private func getSelectedText(from element: AXUIElement) -> String? {
        // Method 1: Try standard selection attribute
        if let selection = getSelectedTextStandard(element) {
            return selection
        }
        
        // Method 2: Try for web browsers (Chrome, Safari)
        if let webSelection = getSelectedTextFromWebBrowser(element) {
            return webSelection
        }
        
        // Method 3: Try for text editors (TextEdit, etc.)
        if let editorSelection = getSelectedTextFromTextEditor(element) {
            return editorSelection
        }
        
        return nil
    }
    
    /// Standard method to get selected text
    private func getSelectedTextStandard(_ element: AXUIElement) -> String? {
        var selectedTextValue: AnyObject?
        let result = AXUIElementCopyAttributeValue(element, kAXSelectedTextAttribute as CFString, &selectedTextValue)
        
        if result == .success, let text = selectedTextValue as? String, !text.isEmpty {
            return text
        }
        
        return nil
    }
    
    /// Gets selected text from web browsers (Chrome, Safari, etc.)
    private func getSelectedTextFromWebBrowser(_ element: AXUIElement) -> String? {
        // Try to get selected text from web area
        var selectedTextValue: AnyObject?
        let result = AXUIElementCopyAttributeValue(element, kAXSelectedTextAttribute as CFString, &selectedTextValue)
        
        if result == .success, let text = selectedTextValue as? String, !text.isEmpty {
            return text
        }
        
        // Alternative: try to get from the web area directly
        if let webArea = findWebArea(in: element) {
            var webSelectedText: AnyObject?
            let webResult = AXUIElementCopyAttributeValue(webArea, kAXSelectedTextAttribute as CFString, &webSelectedText)
            
            if webResult == .success, let text = webSelectedText as? String, !text.isEmpty {
                return text
            }
        }
        
        return nil
    }
    
    /// Gets selected text from text editors
    private func getSelectedTextFromTextEditor(_ element: AXUIElement) -> String? {
        // Try to get the entire text content and selection range
        var entireText: AnyObject?
        let textResult = AXUIElementCopyAttributeValue(element, kAXValueAttribute as CFString, &entireText)
        
        if textResult == .success, let fullText = entireText as? String {
            // Try to get selection range
            var selectionRange: AnyObject?
            let rangeResult = AXUIElementCopyAttributeValue(element, kAXSelectedTextRangeAttribute as CFString, &selectionRange)
            
            if rangeResult == .success, let range = selectionRange as? AXValue {
                // Extract the selected portion based on range
                if let selectedRange = extractRange(from: range) {
                    let startIndex = fullText.index(fullText.startIndex, offsetBy: selectedRange.location)
                    let endIndex = fullText.index(startIndex, offsetBy: selectedRange.length)
                    return String(fullText[startIndex..<endIndex])
                }
            }
        }
        
        return nil
    }
    
    /// Finds a web area within an element hierarchy
    private func findWebArea(in element: AXUIElement) -> AXUIElement? {
        var children: AnyObject?
        let result = AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &children)
        
        if result == .success, let childArray = children as? [AXUIElement] {
            for child in childArray {
                // Check if this is a web area
                var role: AnyObject?
                let roleResult = AXUIElementCopyAttributeValue(child, kAXRoleAttribute as CFString, &role)
                
                if roleResult == .success, let roleString = role as? String {
                    if roleString == kAXWebAreaRole || roleString == kAXTextAreaRole {
                        return child
                    }
                }
                
                // Recursively search
                if let found = findWebArea(in: child) {
                    return found
                }
            }
        }
        
        return nil
    }
    
    /// Gets surrounding context around the selected text
    private func getSurroundingContext(from element: AXUIElement, selectedText: String) -> String {
        // Try to get the entire text content
        var entireText: AnyObject?
        let result = AXUIElementCopyAttributeValue(element, kAXValueAttribute as CFString, &entireText)
        
        if result == .success, let fullText = entireText as? String {
            // Find the selected text in the full text
            if let range = fullText.range(of: selectedText, options: .literal) {
                let startIndex = max(fullText.startIndex, fullText.index(range.lowerBound, offsetBy: -contextWindowSize))
                let endIndex = min(fullText.endIndex, fullText.index(range.upperBound, offsetBy: contextWindowSize))
                return String(fullText[startIndex..<endIndex])
            }
        }
        
        // Fallback: return just the selected text
        return selectedText
    }
    
    /// Extracts selection range from AXValue
    private func extractRange(from axValue: AXValue) -> NSRange? {
        var range: NSRange = NSRange(location: 0, length: 0)
        let success = AXValueGetValue(axValue, .cgRect, &range)
        return success ? range : nil
    }
    
    /// Stops monitoring for text selection
    func stopMonitoring() {
        if let observer = accessibilityObserver {
            AXObserverRemoveNotification(observer, monitoredElement, kAXFocusedApplicationChangedNotification as CFString)
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), AXObserverGetRunLoopSource(observer), .commonModes)
            accessibilityObserver = nil
        }
        
        isMonitoring = false
        print("🛑 TextSelectionMonitor: Stopped monitoring")
    }
    
    deinit {
        stopMonitoring()
    }
}

// MARK: - AXUIElement Extension

extension AXUIElement {
    /// Helper to get the role description
    var roleDescription: String? {
        var description: AnyObject?
        let result = AXUIElementCopyAttributeValue(self, kAXRoleDescriptionAttribute as CFString, &description)
        return result == .success ? description as? String : nil
    }
}