import Foundation
import CoreGraphics
import AppKit
import OSLog

struct OCRResult {
    let text: String
    let translatedText: String
    let sender: String
    let boundingBox: CGRect
    let isSenderName: Bool
    let isFromUser: Bool
}

class OpenAIVisionService {
    private let logger = Logger(subsystem: "Abhi.Translator-Agent", category: "OpenAIVision")
    private let apiKey: String
    private let baseURL = "https://api.openai.com/v1/chat/completions"
    
    init(apiKey: String) {
        self.apiKey = apiKey
    }
    
    func extractAndTranslateText(from image: CGImage) async throws -> [OCRResult] {
        let base64Image = convertImageToBase64(image)
        
        var request = URLRequest(url: URL(string: baseURL)!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let payload: [String: Any] = [
            "model": "gpt-4o",
            "messages": [
                [
                    "role": "system",
                    "content": """
                    You are a chat message extractor and translator. Extract all messages from the KakaoTalk screenshot, including:
                    1. Who sent the message (sender name)
                    2. The original message content
                    3. Whether it's a user message (right-aligned in the screenshot and also in yellow color background) or received message (left-aligned in the screenshot and also in white color background)
                    4. Translate Korean text to English
                    
                    Format your response as a JSON array of messages, each with:
                    {
                        "sender": "name",
                        "originalText": "original message",
                        "translatedText": "English translation",
                        "isFromUser": boolean,
                        "boundingBox": {"x": float, "y": float, "width": float, "height": float}
                    }
                    """
                ],
                [
                    "role": "user",
                    "content": [
                        [
                            "type": "image_url",
                            "image_url": ["url": "data:image/jpeg;base64,\(base64Image)"]
                        ]
                    ]
                ]
            ],
            "max_tokens": 4000,
            "temperature": 0.3  // Lower temperature for more consistent results
        ]
        
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: payload)
            request.httpBody = jsonData
            
            // Set a timeout for the request
            let session = URLSession(configuration: .default)
            let (data, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                logger.error("Invalid HTTP response type")
                throw VisionError.invalidResponse
            }
            
            logger.debug("API Response: \(String(data: data, encoding: .utf8) ?? "Unable to decode response")")
            
            if httpResponse.statusCode != 200 {
                let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
                logger.error("API request failed (\(httpResponse.statusCode)): \(errorMessage)")
                throw VisionError.apiError(message: "Status \(httpResponse.statusCode): \(errorMessage)")
            }
            
            guard let jsonResponse = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                logger.error("Failed to parse response as JSON dictionary")
                throw VisionError.invalidJSON(details: "Initial JSON parsing failed")
            }
            
            guard let choices = jsonResponse["choices"] as? [[String: Any]] else {
                logger.error("No 'choices' array in response: \(jsonResponse)")
                throw VisionError.invalidResponse
            }
            
            guard let messageContent = choices.first?["message"] as? [String: Any] else {
                logger.error("No 'message' in first choice: \(choices)")
                throw VisionError.invalidResponse
            }
            
            guard let content = messageContent["content"] as? String else {
                logger.error("No 'content' in message: \(messageContent)")
                throw VisionError.invalidResponse
            }
            
            // Parse the response immediately to ensure we have valid data
            let results = try parseOpenAIResponse(content)
            
            // Log the number of messages extracted
            logger.debug("Successfully extracted \(results.count) messages from image")
            
            return results
        } catch {
            logger.error("Vision API error: \(error.localizedDescription)")
            if let visionError = error as? VisionError {
                throw visionError
            }
            throw VisionError.apiError(message: error.localizedDescription)
        }
    }
    
    private func convertImageToBase64(_ image: CGImage) -> String {
        let bitmapRep = NSBitmapImageRep(cgImage: image)
        guard let jpegData = bitmapRep.representation(using: .jpeg, properties: [:]) else {
            logger.error("Failed to convert image to JPEG")
            return ""
        }
        return jpegData.base64EncodedString()
    }
    
    private func parseOpenAIResponse(_ jsonString: String) throws -> [OCRResult] {
        do {
            logger.debug("Parsing response content: \(jsonString)")
            
            // Remove markdown code block markers if present
            var cleanedJson = jsonString
            if cleanedJson.hasPrefix("```json") {
                cleanedJson = String(cleanedJson.dropFirst(7))
            }
            if cleanedJson.hasSuffix("```") {
                cleanedJson = String(cleanedJson.dropLast(3))
            }
            cleanedJson = cleanedJson.trimmingCharacters(in: .whitespacesAndNewlines)
            
            logger.debug("Cleaned JSON: \(cleanedJson)")
            
            guard let jsonData = cleanedJson.data(using: .utf8) else {
                logger.error("Failed to convert response string to data")
                throw VisionError.invalidJSON(details: "String to Data conversion failed")
            }
            
            guard let messages = try? JSONSerialization.jsonObject(with: jsonData) as? [[String: Any]] else {
                logger.error("Failed to parse content as JSON array")
                throw VisionError.invalidJSON(details: "Content is not a JSON array")
            }
            
            return try messages.enumerated().compactMap { index, message in
                do {
                    guard let sender = message["sender"] as? String,
                          let originalText = message["originalText"] as? String,
                          let translatedText = message["translatedText"] as? String,
                          let isFromUser = message["isFromUser"] as? Bool,
                          let boundingBox = message["boundingBox"] as? [String: CGFloat] else {
                        logger.warning("Invalid message format at index \(index): \(message)")
                        return nil
                    }
                    
                    let rect = CGRect(
                        x: boundingBox["x"] ?? 0,
                        y: boundingBox["y"] ?? 0,
                        width: boundingBox["width"] ?? 0,
                        height: boundingBox["height"] ?? 0
                    )
                    
                    return OCRResult(
                        text: originalText,
                        translatedText: translatedText,
                        sender: sender,
                        boundingBox: rect,
                        isSenderName: false,
                        isFromUser: isFromUser
                    )
                } catch {
                    logger.error("Failed to parse message at index \(index): \(error.localizedDescription)")
                    return nil
                }
            }
        } catch {
            logger.error("JSON parsing error: \(error.localizedDescription)")
            throw VisionError.invalidJSON(details: error.localizedDescription)
        }
    }
}

enum VisionError: Error, CustomStringConvertible {
    case apiError(message: String)
    case invalidResponse
    case invalidJSON(details: String)
    
    var description: String {
        switch self {
        case .apiError(let message):
            return "API Error: \(message)"
        case .invalidResponse:
            return "Invalid response from server"
        case .invalidJSON(let details):
            return "Failed to parse server response: \(details)"
        }
    }
} 
