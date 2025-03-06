import Foundation
import CoreGraphics
import AppKit

struct ChatWindow: Identifiable, Hashable {
    let id: Int32 // CGWindowID is typealias for Int32
    let name: String
    let bounds: CGRect
    
    static func == (lhs: ChatWindow, rhs: ChatWindow) -> Bool {
        lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

enum MessagePosition {
    case left  // Other person's message
    case right // My message
}

struct TranslatedMessage: Identifiable, Equatable {
    let id: UUID
    let sender: String
    let originalText: String
    let translatedText: String
    let timestamp: Date
    let position: MessagePosition
    
    // Helper to determine if this is the user's message
    var isFromMe: Bool {
        position == .right
    }
    
    // Default initializer
    init(sender: String, originalText: String, translatedText: String, 
         timestamp: Date, position: MessagePosition) {
        self.id = UUID()
        self.sender = sender
        self.originalText = originalText
        self.translatedText = translatedText
        self.timestamp = timestamp
        self.position = position
    }
    
    // Initializer with id for persistence
    init(id: UUID, sender: String, originalText: String, translatedText: String,
         timestamp: Date, position: MessagePosition) {
        self.id = id
        self.sender = sender
        self.originalText = originalText
        self.translatedText = translatedText
        self.timestamp = timestamp
        self.position = position
    }
    
    // Add Equatable conformance
    static func == (lhs: TranslatedMessage, rhs: TranslatedMessage) -> Bool {
        lhs.id == rhs.id
    }
}

struct Chat: Identifiable, Hashable {
    let id: UUID
    let name: String
    var messages: [TranslatedMessage]
    var latestScreenshot: NSImage?
    var unreadCount: Int = 0  // Track number of unread messages
    var lastMessageTimestamp: Date  // For sorting
    
    init(name: String, messages: [TranslatedMessage], latestScreenshot: NSImage?) {
        self.id = UUID()
        self.name = name
        self.messages = messages
        self.latestScreenshot = latestScreenshot
        self.unreadCount = messages.count  // New chats start with all messages unread
        self.lastMessageTimestamp = messages.last?.timestamp ?? Date()
    }
    
    // Initializer with id for persistence
    init(id: UUID, name: String, messages: [TranslatedMessage], latestScreenshot: NSImage?) {
        self.id = id
        self.name = name
        self.messages = messages
        self.latestScreenshot = latestScreenshot
        self.unreadCount = messages.count
        self.lastMessageTimestamp = messages.last?.timestamp ?? Date()
    }
    
    static func == (lhs: Chat, rhs: Chat) -> Bool {
        lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

// Helper struct to group messages by sender
struct MessageGroup: Identifiable {
    let id = UUID()  // Add id for Identifiable conformance
    let sender: String
    var messages: [TranslatedMessage]
    let position: MessagePosition
} 