import Foundation
import OSLog
import AppKit

class StorageService {
    private let logger = Logger(subsystem: "Abhi.Translator-Agent", category: "Storage")
    
    // File paths
    private let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    private var chatsFileURL: URL {
        documentsDirectory.appendingPathComponent("translated_chats.json")
    }
    
    // Save chats to disk
    func saveChats(_ chats: [Chat]) {
        do {
            // Create encoder
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            
            // Encode chats array to JSON data
            let data = try encoder.encode(chats.map { ChatStorage(from: $0) })
            
            // Write to file
            try data.write(to: chatsFileURL)
            logger.debug("Successfully saved \(chats.count) chats to disk")
        } catch {
            logger.error("Failed to save chats: \(error.localizedDescription)")
        }
    }
    
    // Load chats from disk
    func loadChats() -> [Chat] {
        do {
            // Check if file exists
            guard FileManager.default.fileExists(atPath: chatsFileURL.path) else {
                logger.debug("No saved chats file found")
                return []
            }
            
            // Read data from file
            let data = try Data(contentsOf: chatsFileURL)
            
            // Create decoder
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            
            // Decode JSON data to array of ChatStorage
            let chatStorages = try decoder.decode([ChatStorage].self, from: data)
            
            // Convert ChatStorage objects to Chat objects
            let chats = chatStorages.map { $0.toChat() }
            logger.debug("Successfully loaded \(chats.count) chats from disk")
            
            return chats
        } catch {
            logger.error("Failed to load chats: \(error.localizedDescription)")
            return []
        }
    }
}

// Codable version of Chat for storage
struct ChatStorage: Codable {
    let id: UUID
    let name: String
    let messages: [MessageStorage]
    let unreadCount: Int
    let lastMessageTimestamp: Date
    
    init(from chat: Chat) {
        self.id = chat.id
        self.name = chat.name
        self.messages = chat.messages.map { MessageStorage(from: $0) }
        self.unreadCount = chat.unreadCount
        self.lastMessageTimestamp = chat.lastMessageTimestamp
    }
    
    func toChat() -> Chat {
        var chat = Chat(
            id: id,
            name: name,
            messages: messages.map { $0.toMessage() },
            latestScreenshot: nil
        )
        chat.unreadCount = unreadCount
        chat.lastMessageTimestamp = lastMessageTimestamp
        return chat
    }
}

// Codable version of TranslatedMessage for storage
struct MessageStorage: Codable {
    let id: UUID
    let sender: String
    let originalText: String
    let translatedText: String
    let timestamp: Date
    let positionRaw: String
    
    init(from message: TranslatedMessage) {
        self.id = message.id
        self.sender = message.sender
        self.originalText = message.originalText
        self.translatedText = message.translatedText
        self.timestamp = message.timestamp
        self.positionRaw = message.position == .right ? "right" : "left"
    }
    
    func toMessage() -> TranslatedMessage {
        return TranslatedMessage(
            id: id,
            sender: sender,
            originalText: originalText,
            translatedText: translatedText,
            timestamp: timestamp,
            position: positionRaw == "right" ? .right : .left
        )
    }
} 