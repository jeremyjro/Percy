//
//  TextExplanationService.swift
//  cursor-buddy
//
//  Provides AI-powered context-aware explanations of selected text.
//  Integrates with OpenClicky's existing Claude API infrastructure to deliver
//  intelligent explanations that consider the broader context of the selected content.
//

import Foundation

/// Result of a text explanation request
struct TextExplanationResult: Sendable {
    let explanation: String
    let summary: String
    let keyPoints: [String]
    let suggestedQuestions: [String]
    let timestamp: Date
}

/// Service for generating context-aware text explanations
@MainActor
final class TextExplanationService: ObservableObject {
    @Published private(set) var isExplaining = false
    @Published private(set) var lastExplanation: TextExplanationResult?
    @Published private(set) var currentExplanationProgress: Double = 0.0
    
    private let claudeAPI: ClaudeAPI
    private var explanationHistory: [(selection: String, explanation: TextExplanationResult)] = []
    
    init(claudeAPI: ClaudeAPI) {
        self.claudeAPI = claudeAPI
    }
    
    /// Generates a context-aware explanation for selected text
    func explainText(
        selectedText: String,
        context: String,
        applicationName: String,
        followUpQuestion: String? = nil
    ) async throws -> TextExplanationResult {
        isExplaining = true
        currentExplanationProgress = 0.1
        defer {
            isExplaining = false
            currentExplanationProgress = 1.0
        }
        
        // Build the prompt for Claude
        let prompt = buildExplanationPrompt(
            selectedText: selectedText,
            context: context,
            applicationName: applicationName,
            followUpQuestion: followUpQuestion
        )
        
        currentExplanationProgress = 0.3
        
        // Call Claude API
        let response = try await claudeAPI.sendMessage(
            prompt: prompt,
            model: "claude-sonnet-4-6",
            maxTokens: 1000
        )
        
        currentExplanationProgress = 0.7
        
        // Parse the structured response
        let explanation = parseExplanationResponse(response, selectedText: selectedText)
        
        // Store in history
        explanationHistory.append((selectedText, explanation))
        
        lastExplanation = explanation
        return explanation
    }
    
    /// Builds the explanation prompt for Claude
    private func buildExplanationPrompt(
        selectedText: String,
        context: String,
        applicationName: String,
        followUpQuestion: String?
    ) -> String {
        var prompt = """
        You are OpenClicky, an intelligent AI assistant that helps users understand text in context.
        
        The user has selected this text in \(applicationName):
        
        "\(selectedText)"
        
        Here is the surrounding context from the document/page:
        
        "\(context)"
        
        """
        
        if let followUp = followUpQuestion {
            prompt += """
            
            The user has this follow-up question about the selected text:
            
            "\(followUp)"
            
            Please answer their question specifically while keeping the broader context in mind.
            """
        } else {
            prompt += """
            
            Please provide a clear, concise explanation of what this text means in the context of the surrounding content.
            """
        }
        
        prompt += """

        Format your response as JSON with this structure:
        {
            "explanation": "A clear, conversational explanation (2-4 sentences)",
            "summary": "A one-sentence summary of the key point",
            "keyPoints": ["First key point", "Second key point", "Third key point"],
            "suggestedQuestions": ["Question about this concept", "Follow-up question", "Related topic question"]
        }

        Guidelines:
        - Keep the explanation conversational and easy to understand
        - Focus on the most important meaning in context
        - Provide 2-4 key points that capture the essential information
        - Suggest 3 relevant follow-up questions the user might want to ask
        - If the text is technical, explain it in simpler terms
        - If the text is ambiguous, acknowledge the different possible meanings
        - Consider the source application (e.g., if it's code, explain it as code)
        """
        
        return prompt
    }
    
    /// Parses Claude's response into a structured explanation result
    private func parseExplanationResponse(_ response: String, selectedText: String) -> TextExplanationResult {
        // Try to extract JSON from the response
        if let jsonData = extractJSON(from: response),
           let decoded = try? JSONDecoder().decode(ExplanationResponse.self, from: jsonData) {
            return TextExplanationResult(
                explanation: decoded.explanation,
                summary: decoded.summary,
                keyPoints: decoded.keyPoints,
                suggestedQuestions: decoded.suggestedQuestions,
                timestamp: Date()
            )
        }
        
        // Fallback: create a basic explanation from the raw response
        return TextExplanationResult(
            explanation: response,
            summary: response.prefix(100).description,
            keyPoints: [],
            suggestedQuestions: [],
            timestamp: Date()
        )
    }
    
    /// Extracts JSON from a response that may contain other text
    private func extractJSON(from response: String) -> Data? {
        // Look for JSON between ```json and ``` markers
        if let jsonStart = response.range(of: "```json"),
           let jsonEnd = response.range(of: "```", range: jsonStart.upperBound..<response.endIndex) {
            let jsonString = String(response[jsonStart.upperBound..<jsonEnd.lowerBound])
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return jsonString.data(using: .utf8)
        }
        
        // Try to find a JSON object directly
        if let braceStart = response.firstIndex(of: "{"),
           let braceEnd = response.lastIndex(of: "}") {
            let jsonString = String(response[braceStart...braceEnd])
            return jsonString.data(using: .utf8)
        }
        
        return nil
    }
    
    /// Gets a follow-up explanation based on previous context
    func getFollowUpExplanation(for question: String) async throws -> TextExplanationResult? {
        guard let lastSelection = explanationHistory.last else {
            return nil
        }
        
        return try await explainText(
            selectedText: lastSelection.selection,
            context: "",
            applicationName: "",
            followUpQuestion: question
        )
    }
    
    /// Clears the explanation history
    func clearHistory() {
        explanationHistory.removeAll()
        lastExplanation = nil
    }
}

// MARK: - Response Models

private struct ExplanationResponse: Codable {
    let explanation: String
    let summary: String
    let keyPoints: [String]
    let suggestedQuestions: [String]
}

// MARK: - Explanation Quality Metrics

struct ExplanationQualityMetrics {
    let clarityScore: Double // 0.0 - 1.0
    let contextRelevanceScore: Double // 0.0 - 1.0
    let userSatisfaction: Double // 0.0 - 1.0 (when user provides feedback)
}