# OpenClicky Text Explanation Feature

## Overview

A new AI-powered text explanation feature that allows users to select any text in any application (Chrome, Safari, TextEdit, etc.) and get intelligent, context-aware explanations instantly.

## Features

### Core Functionality
- **System-wide text selection capture**: Works across all macOS applications using Accessibility API
- **Context-aware AI explanations**: Uses Claude to understand text within its broader context
- **Keyboard shortcut trigger**: Activate with `Cmd+Shift+E` (configurable in future versions)
- **Smart overlay UI**: Beautiful explanation bubble with expandable details
- **Follow-up questions**: Ask additional questions about the same selection
- **Copy functionality**: Easily copy explanations to clipboard

### Key Components

1. **TextSelectionMonitor.swift**
   - Monitors system-wide text selection using macOS Accessibility API
   - Captures selected text and surrounding context from any application
   - Handles different application types (browsers, text editors, etc.)
   - Provides permission and error handling

2. **TextExplanationService.swift**
   - AI-powered explanation generation using Claude API
   - Context-aware analysis considering surrounding text
   - Structured response format with summaries and key points
   - Suggested follow-up questions for deeper understanding
   - Conversation history for context retention

3. **TextExplanationOverlay.swift**
   - Elegant SwiftUI overlay for displaying explanations
   - Expandable interface with key points and suggested questions
   - Smooth animations and transitions
   - Copy-to-clipboard functionality
   - Position-aware placement near cursor

4. **TextExplanationShortcutMonitor.swift**
   - Global keyboard shortcut monitoring (Cmd+Shift+E)
   - Uses CGEvent tap for system-wide coverage
   - Lightweight and non-intrusive

5. **CompanionManager Integration**
   - Seamless integration with existing OpenClicky architecture
   - State management for explanation workflow
   - Error handling with user-friendly alerts
   - Cursor-based feedback for errors and confirmations

## How to Use

### Basic Usage
1. Select any text in any application (Chrome, Safari, TextEdit, etc.)
2. Press `Cmd+Shift+E` to trigger the explanation
3. View the AI-generated explanation in the overlay bubble
4. Click "More" to expand key points and suggested questions
5. Click any suggested question to get a follow-up explanation
6. Click "Copy" to copy the explanation to clipboard
7. Click the X to dismiss the overlay

### Example Scenarios

**In Chrome:**
- Select a technical term on a webpage → Get a simple explanation
- Highlight a complex paragraph → Understand the key points
- Select foreign language text → Get translation and context

**In TextEdit:**
- Select a sentence you wrote → Get writing suggestions
- Highlight a complex concept → Get simplified explanation
- Select code snippets → Get code explanations

**In Safari:**
- Select news article text → Get unbiased summary
- Highlight academic text → Get plain English explanation
- Select product descriptions → Get unbiased analysis

## Architecture

### Workflow
```
User selects text + presses Cmd+Shift+E
↓
TextSelectionShortcutMonitor detects shortcut
↓
TextSelectionMonitor captures selected text + context
↓
TextExplanationService sends to Claude API
↓
Claude generates structured explanation
↓
TextExplanationOverlayManager displays bubble
↓
User interacts (expand, ask follow-up, copy)
↓
Follow-up questions use same context
```

### Key Design Decisions

1. **Accessibility API**: Chosen for system-wide compatibility without requiring per-app integrations
2. **Context Capture**: Includes surrounding text to provide better explanations
3. **Claude Integration**: Uses existing OpenClicky Claude infrastructure for consistency
4. **Overlay Positioning**: Smart placement near cursor to avoid obscuring content
5. **Error Handling**: Graceful degradation with clear user feedback

## Technical Details

### Permissions Required
- **Accessibility**: Required for text selection capture (system prompt will request)
- **Screen Recording**: Already required by OpenClicky for other features

### API Usage
- Uses existing Claude API configuration from OpenClicky settings
- Follows OpenClicky's SDK-first, HTTP-fallback approach
- Token-efficient prompting to minimize costs

### Performance
- Lightweight shortcut monitoring (CGEvent tap)
- Async text capture to avoid UI blocking
- Cached context for follow-up questions
- Optimized overlay animations

## File Structure

```
cursor-buddy/
├── TextSelectionMonitor.swift           # Text capture via Accessibility
├── TextExplanationService.swift         # AI explanation generation
├── TextExplanationOverlay.swift         # UI overlay components
├── TextExplanationShortcutMonitor.swift # Keyboard shortcut handling
└── CompanionManager.swift               # Integration point (modified)
```

## Future Enhancements

### Planned Features
- [ ] Customizable keyboard shortcut
- [ ] Multi-language support
- [ ] Explanation history
- [ ] Export explanations to notes
- [ ] Voice activation for explanations
- [ ] Integration with OpenClicky's agent system
- [ ] Support for PDF and image text
- [ ] Context window size configuration
- [ ] Explanation quality feedback

### Potential Improvements
- [ ] Faster text capture with caching
- [ ] Offline mode for local explanations
- [ ] Collaborative explanations
- [ ] Explanation sharing
- [ ] Deep integration with specific applications

## Troubleshooting

### "Accessibility permission needed"
- Go to System Settings → Privacy & Security → Accessibility
- Ensure OpenClicky has permission granted
- Restart the application

### "No text selected"
- Ensure text is actually highlighted/selected before pressing shortcut
- Try selecting text again in the target application

### "Application not supported"
- Some applications may not support Accessibility API text selection
- Try copying text to a supported application like TextEdit

### Explanation doesn't appear
- Check that Claude API key is configured in OpenClicky settings
- Ensure internet connection is active
- Check Console.app for detailed error logs

## Development Notes

### Testing
All files have been validated with `swiftc -parse` to ensure compilation compatibility:
```bash
swiftc -parse cursor-buddy/TextSelectionMonitor.swift
swiftc -parse cursor-buddy/TextExplanationService.swift
swiftc -parse cursor-buddy/TextExplanationOverlay.swift
swiftc -parse cursor-buddy/TextExplanationShortcutMonitor.swift
swiftc -parse cursor-buddy/CompanionManager.swift
```

### Integration Notes
- Uses existing OpenClicky infrastructure (Claude API, overlay system)
- Follows OpenClicky's design patterns and naming conventions
- Maintains compatibility with existing features
- No breaking changes to existing functionality

### Build Instructions
1. Open the project in Xcode: `open cursor-buddy.xcodeproj`
2. The new files will be automatically detected (PBXFileSystemSynchronizedRootGroup)
3. Build and run with `Cmd+R`
4. Grant Accessibility permissions when prompted
5. Test with text selection in any application

## License

This feature is part of OpenClicky and follows the same license terms as the main project.

## Credits

Developed as an enhancement to OpenClicky by Jason Kneen's open-source project.
Built with Claude AI integration following OpenClicky's architecture patterns.