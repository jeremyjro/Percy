//
//  TextExplanationShortcutMonitor.swift
//  cursor-buddy
//
//  Monitors for the text explanation keyboard shortcut (Cmd+Shift+E by default).
//  When triggered, captures the currently selected text and initiates the explanation workflow.
//

import AppKit
import Combine
import CoreGraphics
import Foundation

final class TextExplanationShortcutMonitor: ObservableObject {
    let shortcutTriggeredPublisher = PassthroughSubject<Void, Never>()
    
    @Published private(set) var isShortcutEnabled = true
    @Published private(set) var isShortcutCurrentlyPressed = false
    
    private var globalEventTap: CFMachPort?
    private var globalEventTapRunLoopSource: CFRunLoopSource?
    
    // Default shortcut: Cmd+Shift+E
    private let shortcutKeyCode: UInt32 = 14 // E key
    private let shortcutModifiers: CGEventFlags = [.maskCommand, .maskShift]
    
    deinit {
        if let globalEventTapRunLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), globalEventTapRunLoopSource, .commonModes)
        }
        
        if let globalEventTap {
            CFMachPortInvalidate(globalEventTap)
        }
    }
    
    func start() {
        guard globalEventTap == nil else { return }
        
        let monitoredEventTypes: [CGEventType] = [.flagsChanged, .keyDown, .keyUp]
        let eventMask = monitoredEventTypes.reduce(CGEventMask(0)) { currentMask, eventType in
            currentMask | (CGEventMask(1) << eventType.rawValue)
        }
        
        let eventTapCallback: CGEventTapCallBack = { _, eventType, event, userInfo in
            guard let userInfo else {
                return Unmanaged.passUnretained(event)
            }
            
            let monitor = Unmanaged<TextExplanationShortcutMonitor>
                .fromOpaque(userInfo)
                .takeUnretainedValue()
            
            return monitor.handleGlobalEventTap(
                eventType: eventType,
                event: event
            )
        }
        
        guard let globalEventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: eventMask,
            callback: eventTapCallback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            print("⚠️ TextExplanationShortcutMonitor: couldn't create CGEvent tap")
            return
        }
        
        guard let globalEventTapRunLoopSource = CFMachPortCreateRunLoopSource(
            kCFAllocatorDefault,
            globalEventTap,
            0
        ) else {
            CFMachPortInvalidate(globalEventTap)
            print("⚠️ TextExplanationShortcutMonitor: couldn't create event tap run loop source")
            return
        }
        
        self.globalEventTap = globalEventTap
        self.globalEventTapRunLoopSource = globalEventTapRunLoopSource
        
        CFRunLoopAddSource(CFRunLoopGetMain(), globalEventTapRunLoopSource, .commonModes)
        CGEvent.tapEnable(tap: globalEventTap, enable: true)
        
        print("✅ TextExplanationShortcutMonitor: Started monitoring (Cmd+Shift+E)")
    }
    
    func stop() {
        if let globalEventTapRunLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), globalEventTapRunLoopSource, .commonModes)
        }
        
        if let globalEventTap {
            CGEvent.tapEnable(tap: globalEventTap, enable: false)
            CFMachPortInvalidate(globalEventTap)
        }
        
        self.globalEventTap = nil
        self.globalEventTapRunLoopSource = nil
        
        print("🛑 TextExplanationShortcutMonitor: Stopped monitoring")
    }
    
    private func handleGlobalEventTap(eventType: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        guard isShortcutEnabled else {
            return Unmanaged.passUnretained(event)
        }
        
        switch eventType {
        case .flagsChanged:
            handleFlagsChanged(event)
        case .keyDown:
            handleKeyDown(event)
        case .keyUp:
            handleKeyUp(event)
        default:
            break
        }
        
        return Unmanaged.passUnretained(event)
    }
    
    private func handleFlagsChanged(_ event: CGEvent) {
        let flags = event.flags
        
        // Check if our shortcut modifiers are pressed
        let commandPressed = flags.contains(.maskCommand)
        let shiftPressed = flags.contains(.maskShift)
        let allModifiersPressed = commandPressed && shiftPressed
        
        // Update the pressed state if we have the key down
        if isShortcutCurrentlyPressed && !allModifiersPressed {
            isShortcutCurrentlyPressed = false
        }
    }
    
    private func handleKeyDown(_ event: CGEvent) {
        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        let flags = event.flags
        
        // Check if this is our shortcut combination
        let commandPressed = flags.contains(.maskCommand)
        let shiftPressed = flags.contains(.maskShift)
        let isCorrectKey = UInt32(keyCode) == shortcutKeyCode
        let isCorrectModifiers = commandPressed && shiftPressed
        
        if isCorrectKey && isCorrectModifiers {
            isShortcutCurrentlyPressed = true
            shortcutTriggeredPublisher.send()
            print("🎯 TextExplanationShortcutMonitor: Shortcut triggered (Cmd+Shift+E)")
        }
    }
    
    private func handleKeyUp(_ event: CGEvent) {
        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        
        if UInt32(keyCode) == shortcutKeyCode {
            isShortcutCurrentlyPressed = false
        }
    }
    
    /// Sets a custom shortcut (not implemented in this version, always uses Cmd+Shift+E)
    func setShortcut(keyCode: UInt32, modifiers: CGEventFlags) {
        // Future implementation for customizable shortcuts
        print("⚠️ TextExplanationShortcutMonitor: Custom shortcuts not yet implemented")
    }
}