//
//  TextExplanationOverlay.swift
//  cursor-buddy
//
//  UI component for displaying text explanations near the cursor/selection.
//  Integrates with OpenClicky's existing overlay system to show intelligent
//  explanations when users select text and trigger the feature.
//

import SwiftUI
import AppKit
import Combine

/// Configuration for the explanation overlay appearance
struct TextExplanationOverlayConfiguration {
    let maxExplanationWidth: CGFloat
    let animationDuration: TimeInterval
    let cornerRadius: CGFloat
    let shadowRadius: CGFloat
    let backgroundColor: Color
    let textColor: Color
    let accentColor: Color
    
    static let `default` = TextExplanationOverlayConfiguration(
        maxExplanationWidth: 320,
        animationDuration: 0.3,
        cornerRadius: 12,
        shadowRadius: 16,
        backgroundColor: Color(nsColor: .windowBackgroundColor),
        textColor: Color.primary,
        accentColor: .blue
    )
}

/// View for displaying text explanation bubbles
struct TextExplanationOverlayView: View {
    let explanation: TextExplanationResult
    let configuration: TextExplanationOverlayConfiguration
    let onDismiss: () -> Void
    let onAskQuestion: (String) -> Void
    let onCopy: () -> Void
    
    @State private var isExpanded = false
    @State private var showCopyConfirmation = false
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with dismiss button
            HStack {
                Text("OpenClicky")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(configuration.accentColor)
                
                Spacer()
                
                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            
            Divider()
            
            // Main explanation
            VStack(alignment: .leading, spacing: 8) {
                Text(explanation.summary)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(configuration.textColor)
                
                Text(explanation.explanation)
                    .font(.body)
                    .foregroundColor(configuration.textColor)
                    .lineLimit(isExpanded ? nil : 3)
            }
            
            // Expandable key points
            if !explanation.keyPoints.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Button(action: { withAnimation { isExpanded.toggle() }}) {
                        HStack {
                            Text("Key Points")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(configuration.accentColor)
                            
                            Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                                .font(.caption2)
                                .foregroundColor(configuration.accentColor)
                        }
                    }
                    .buttonStyle(.plain)
                    
                    if isExpanded {
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(Array(explanation.keyPoints.enumerated()), id: \.offset) { _, point in
                                HStack(alignment: .top) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.caption2)
                                        .foregroundColor(configuration.accentColor)
                                    Text(point)
                                        .font(.caption)
                                        .foregroundColor(configuration.textColor)
                                }
                            }
                        }
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }
            }
            
            Divider()
            
            // Suggested questions
            if !explanation.suggestedQuestions.isEmpty && isExpanded {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Suggested Questions")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(configuration.accentColor)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(Array(explanation.suggestedQuestions.prefix(3).enumerated()), id: \.offset) { _, question in
                            Button(action: { onAskQuestion(question) }) {
                                HStack {
                                    Image(systemName: "questionmark.bubble.fill")
                                        .font(.caption2)
                                        .foregroundColor(configuration.accentColor)
                                    Text(question)
                                        .font(.caption)
                                        .foregroundColor(configuration.textColor)
                                        .lineLimit(1)
                                    Spacer()
                                    Image(systemName: "arrow.right")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 6)
                                .background(
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(Color.primary.opacity(0.05))
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
            
            // Action buttons
            HStack(spacing: 8) {
                Button(action: {
                    onCopy()
                    withAnimation(.spring()) {
                        showCopyConfirmation = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                            showCopyConfirmation = false
                        }
                    }
                }) {
                    HStack {
                        Image(systemName: showCopyConfirmation ? "checkmark" : "doc.on.doc")
                            .font(.caption)
                        Text(showCopyConfirmation ? "Copied!" : "Copy")
                            .font(.caption)
                    }
                    .foregroundColor(configuration.textColor)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.primary.opacity(0.1))
                    )
                }
                .buttonStyle(.plain)
                
                Spacer()
                
                Button(action: { withAnimation { isExpanded.toggle() }}) {
                    HStack {
                        Text(isExpanded ? "Less" : "More")
                            .font(.caption)
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.caption2)
                    }
                    .foregroundColor(configuration.accentColor)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .frame(maxWidth: configuration.maxExplanationWidth)
        .background(
            RoundedRectangle(cornerRadius: configuration.cornerRadius)
                .fill(configuration.backgroundColor)
                .shadow(color: .black.opacity(0.15), radius: configuration.shadowRadius, y: 4)
        )
        .overlay(
            RoundedRectangle(cornerRadius: configuration.cornerRadius)
                .stroke(configuration.accentColor.opacity(0.3), lineWidth: 1)
        )
    }
}

/// Window manager for text explanation overlays
@MainActor
final class TextExplanationOverlayManager: ObservableObject {
    @Published private(set) var isVisible = false
    @Published private(set) var currentExplanation: TextExplanationResult?
    @Published private(set) var overlayPosition: CGPoint = .zero
    
    private var overlayWindow: NSWindow?
    private let configuration: TextExplanationOverlayConfiguration
    
    // Callbacks
    var onAskQuestion: ((String) -> Void)?
    var onDismiss: (() -> Void)?
    var onCopy: (() -> Void)?
    
    init(configuration: TextExplanationOverlayConfiguration) {
        self.configuration = configuration
    }
    
    convenience init() {
        self.init(configuration: .default)
    }
    
    /// Shows an explanation overlay at the specified position
    func showExplanation(
        _ explanation: TextExplanationResult,
        at position: CGPoint
    ) {
        self.currentExplanation = explanation
        self.overlayPosition = position
        self.isVisible = true
        
        // Ensure overlay window exists
        if overlayWindow == nil {
            createOverlayWindow()
        }
        
        // Position the window
        overlayWindow?.setFrameOrigin(position)
        
        // Show the window
        overlayWindow?.orderFrontRegardless()
        overlayWindow?.alphaValue = 0
        
        // Animate in
        NSAnimationContext.runAnimationGroup { context in
            context.duration = configuration.animationDuration
            overlayWindow?.animator().alphaValue = 1.0
        }
    }
    
    /// Hides the explanation overlay
    func hideOverlay() {
        guard isVisible else { return }
        
        // Animate out
        NSAnimationContext.runAnimationGroup { context in
            context.duration = configuration.animationDuration
            overlayWindow?.animator().alphaValue = 0
        } completionHandler: { [weak self] in
            MainActor.assumeIsolated {
                self?.overlayWindow?.orderOut(nil)
                self?.isVisible = false
                self?.currentExplanation = nil
            }
        }
    }
    
    /// Creates the overlay window
    private func createOverlayWindow() {
        let contentView = TextExplanationOverlayView(
            explanation: currentExplanation ?? createPlaceholderExplanation(),
            configuration: configuration,
            onDismiss: { [weak self] in
                self?.hideOverlay()
                self?.onDismiss?()
            },
            onAskQuestion: { [weak self] question in
                self?.onAskQuestion?(question)
            },
            onCopy: { [weak self] in
                self?.copyExplanationToClipboard()
                self?.onCopy?()
            }
        )
        .padding(16)
        
        let hostingView = NSHostingView(rootView: contentView)
        hostingView.translatesAutoresizingMaskIntoConstraints = false
        
        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: CGSize(width: configuration.maxExplanationWidth + 32, height: 200)),
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        
        window.contentViewController = NSViewController()
        window.contentViewController?.view.addSubview(hostingView)
        window.contentView?.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            hostingView.topAnchor.constraint(equalTo: window.contentView!.topAnchor),
            hostingView.leadingAnchor.constraint(equalTo: window.contentView!.leadingAnchor),
            hostingView.trailingAnchor.constraint(equalTo: window.contentView!.trailingAnchor),
            hostingView.bottomAnchor.constraint(equalTo: window.contentView!.bottomAnchor)
        ])
        
        window.isOpaque = false
        window.backgroundColor = .clear
        window.level = .floating
        window.ignoresMouseEvents = false
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.isReleasedWhenClosed = false
        
        overlayWindow = window
    }
    
    /// Copies the current explanation to clipboard
    private func copyExplanationToClipboard() {
        guard let explanation = currentExplanation else { return }
        
        let textToCopy = """
        \(explanation.summary)

        \(explanation.explanation)

        Key Points:
        \(explanation.keyPoints.enumerated().map { "\($0.offset + 1). \($0.element)" }.joined(separator: "\n"))
        """
        
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(textToCopy, forType: .string)
    }
    
    /// Creates a placeholder explanation for UI testing
    private func createPlaceholderExplanation() -> TextExplanationResult {
        TextExplanationResult(
            explanation: "Select text to see an explanation here.",
            summary: "Text explanation will appear here",
            keyPoints: [],
            suggestedQuestions: [],
            timestamp: Date()
        )
    }
    
    deinit {
        MainActor.assumeIsolated {
            overlayWindow?.close()
        }
    }
}

// MARK: - Preview Helpers

#if DEBUG
struct TextExplanationOverlayView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            TextExplanationOverlayView(
                explanation: TextExplanationResult(
                    explanation: "This is a detailed explanation of the selected text that provides context and meaning. It explains what the text means in the broader context of the document.",
                    summary: "This text explains a key concept",
                    keyPoints: [
                        "First important point about the text",
                        "Second key insight",
                        "Third crucial detail"
                    ],
                    suggestedQuestions: [
                        "Can you explain this further?",
                        "How does this relate to the main topic?",
                        "What are the implications?"
                    ],
                    timestamp: Date()
                ),
                configuration: .default,
                onDismiss: {},
                onAskQuestion: { _ in },
                onCopy: {}
            )
            .previewDisplayName("Standard Explanation")
            
            TextExplanationOverlayView(
                explanation: TextExplanationResult(
                    explanation: "Technical explanation with complex terminology broken down into simpler concepts.",
                    summary: "Technical concept explained",
                    keyPoints: [
                        "Technical point one",
                        "Technical point two"
                    ],
                    suggestedQuestions: [],
                    timestamp: Date()
                ),
                configuration: .default,
                onDismiss: {},
                onAskQuestion: { _ in },
                onCopy: {}
            )
            .previewDisplayName("Technical Explanation")
        }
        .padding()
        .frame(width: 400, height: 600)
    }
}
#endif
