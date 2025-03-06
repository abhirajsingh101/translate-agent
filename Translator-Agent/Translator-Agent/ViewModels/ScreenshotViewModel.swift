import SwiftUI
import Combine
import OSLog

@MainActor
class ScreenshotViewModel: ObservableObject {
    @Published var fullScreenshot: NSImage?
    @Published var chats: [Chat] = []
    @Published var isProcessing = false
    @Published var errorMessage: String?
    @Published var selectedChat: Chat?
    
    private let logger = Logger(subsystem: "Abhi.Translator-Agent", category: "Screenshot")
    private let screenCaptureService = ScreenCaptureService()
    private let visionService = OpenAIVisionService(apiKey: AppConfig.openAIKey)
    private let storageService = StorageService()
    
    // Initialize with stored data
    init() {
        loadStoredChats()
    }
    
    // Load chats from disk
    private func loadStoredChats() {
        let storedChats = storageService.loadChats()
        chats = storedChats
        logger.debug("Loaded \(storedChats.count) chats from storage")
    }
    
    // Save chats to disk
    private func saveChats() {
        storageService.saveChats(chats)
    }
    
    private func processWindow(image: CGImage, windowName: String) async throws -> [TranslatedMessage] {
        // Extract and translate text using OpenAI Vision
        let results = try await visionService.extractAndTranslateText(from: image)
        
        // Convert results to TranslatedMessages
        let newMessages = results.map { result in
            TranslatedMessage(
                sender: result.sender,
                originalText: result.text,
                translatedText: result.translatedText,
                timestamp: Date(),
                position: result.isFromUser ? .right : .left
            )
        }
        
        // Filter out duplicate messages
        return filterDuplicateMessages(newMessages, windowName: windowName)
    }
    
    private func messageIsEqual(_ message1: TranslatedMessage, _ message2: TranslatedMessage) -> Bool {
        // First check if senders are the same
        guard message1.sender == message2.sender else { return false }
        
        // Calculate similarity between original texts
        let similarity = calculateStringSimilarity(message1.originalText, message2.originalText)
        return similarity >= 0.9 // 90% similarity threshold
    }
    
    private func calculateStringSimilarity(_ str1: String, _ str2: String) -> Double {
        let empty = Array<Int>(0...str2.count)
        var last = empty
        
        for (i, char1) in str1.enumerated() {
            var current = [i + 1] + Array(repeating: 0, count: str2.count)
            
            for (j, char2) in str2.enumerated() {
                let substitutionCost = char1 == char2 ? 0 : 1
                current[j + 1] = min(
                    current[j] + 1,                  // deletion
                    last[j + 1] + 1,                // insertion
                    last[j] + substitutionCost      // substitution
                )
            }
            
            last = current
        }
        
        let levenshteinDistance = Double(last.last ?? 0)
        let maxLength = Double(max(str1.count, str2.count))
        
        // Convert distance to similarity (0 to 1)
        return 1 - (levenshteinDistance / maxLength)
    }
    
    private func filterDuplicateMessages(_ newMessages: [TranslatedMessage], windowName: String) -> [TranslatedMessage] {
        // Find existing chat
        guard let existingChatIndex = chats.firstIndex(where: { $0.name == windowName }) else {
            return newMessages // If no existing chat, return all messages as new
        }
        
        let existingChat = chats[existingChatIndex]
        let recentMessages = existingChat.messages.suffix(10) // Get last 10 messages
        
        // Only keep messages that don't exist in recent messages
        let uniqueMessages = newMessages.filter { newMessage in
            !recentMessages.contains { existingMessage in
                messageIsEqual(newMessage, existingMessage)
            }
        }
        
        logger.debug("Filtered \(newMessages.count - uniqueMessages.count) duplicate messages")
        return uniqueMessages
    }
    
    private func updateChat(name: String, messages: [TranslatedMessage], screenshot: NSImage) {
        if let index = chats.firstIndex(where: { $0.name == name }) {
            // Add new messages to existing chat
            let newMessageCount = messages.count
            if newMessageCount > 0 {
                // Create a copy of the chat to modify
                var updatedChat = chats[index]
                updatedChat.messages.append(contentsOf: messages)
                updatedChat.latestScreenshot = screenshot
                updatedChat.unreadCount += newMessageCount
                updatedChat.lastMessageTimestamp = messages.last?.timestamp ?? Date()
                
                // Replace the chat in the array
                chats[index] = updatedChat
                
                // Move chat to top
                let chat = chats.remove(at: index)
                chats.insert(chat, at: 0)
                
                // Force UI update for unread counts
                objectWillChange.send()
                
                // Create a temporary copy of the entire chats array to force UI refresh
                let tempChats = chats
                chats = []
                // Small delay to ensure UI updates
                Task {
                    try? await Task.sleep(nanoseconds: 10_000_000) // 0.01 seconds
                    chats = tempChats
                    objectWillChange.send()
                }
            } else {
                // Even if no new messages, update the screenshot
                chats[index].latestScreenshot = screenshot
            }
        } else if !messages.isEmpty {
            // Create new chat only if there are messages
            let newChat = Chat(name: name, messages: messages, latestScreenshot: screenshot)
            // Insert new chat at the top
            chats.insert(newChat, at: 0)
            
            // Force UI update for new chat
            objectWillChange.send()
            
            // Create a temporary copy of the entire chats array to force UI refresh
            let tempChats = chats
            chats = []
            // Small delay to ensure UI updates
            Task {
                try? await Task.sleep(nanoseconds: 10_000_000) // 0.01 seconds
                chats = tempChats
                objectWillChange.send()
            }
        }
    }
    
    private func detectAndProcessKakaoWindows(in image: CGImage) async {
        // Get window list with specific options for active windows
        let options = CGWindowListOption([.optionOnScreenOnly, .excludeDesktopElements])
        guard let windowList = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
            logger.error("Failed to get window list")
            return
        }
        
        // Filter and map KakaoTalk windows
        let kakaoWindows = windowList.compactMap { info -> (name: String, bounds: CGRect)? in
            guard let owner = info[kCGWindowOwnerName as String] as? String,
                  owner.contains("KakaoTalk"),
                  let name = info[kCGWindowName as String] as? String,
                  let boundsDict = info[kCGWindowBounds as String] as? [String: CGFloat],
                  !name.isEmpty else {
                return nil
            }
            
            // Skip system windows
            if name == "Item-0" || name == "KakaoTalk" {
                logger.debug("Skipping system window: \(name)")
                return nil
            }
            
            let rect = CGRect(
                x: boundsDict["X"] ?? 0,
                y: boundsDict["Y"] ?? 0,
                width: boundsDict["Width"] ?? 0,
                height: boundsDict["Height"] ?? 0
            )
            
            return (name: name, bounds: rect)
        }
        
        logger.debug("Found \(kakaoWindows.count) KakaoTalk chat windows (excluding system windows)")
        
        // Store the current chat selection
        let currentSelectedChatId = selectedChat?.id
        
        // Create a local copy of chats that we'll modify and then replace the published property
        var updatedChats = chats
        
        // Process each detected window individually
        for window in kakaoWindows {
            if let croppedImage = image.cropping(to: window.bounds) {
                let nsImage = screenCaptureService.convertToNSImage(from: croppedImage)
                
                do {
                    // Process this window
                    let messages = try await processWindow(image: croppedImage, windowName: window.name)
                    logger.debug("Extracted \(messages.count) messages from window: \(window.name)")
                    
                    if messages.count > 0 {
                        if let index = updatedChats.firstIndex(where: { $0.name == window.name }) {
                            // Update existing chat
                            var chat = updatedChats[index]
                            chat.messages.append(contentsOf: messages)
                            chat.latestScreenshot = nsImage
                            chat.unreadCount += messages.count
                            chat.lastMessageTimestamp = messages.last?.timestamp ?? Date()
                            
                            // Remove and reinsert to ensure it's at the top
                            updatedChats.remove(at: index)
                            updatedChats.insert(chat, at: 0)
                            
                            // CRITICAL: Save after each update
                            chats = updatedChats
                            saveChats()
                            
                            // Reset the published property to force UI refresh
                            chats = []
                            objectWillChange.send()
                            
                            // Small delay for UI to process the empty state
                            try await Task.sleep(for: .milliseconds(50))
                            
                            // Set the updated chats
                            chats = updatedChats
                            objectWillChange.send()
                            
                            // Small delay to let UI update
                            try await Task.sleep(for: .milliseconds(100))
                        } else {
                            // Create new chat
                            let newChat = Chat(name: window.name, messages: messages, latestScreenshot: nsImage)
                            updatedChats.insert(newChat, at: 0)
                            
                            // CRITICAL: Save after creating a new chat
                            chats = updatedChats
                            saveChats()
                            
                            // Reset the published property to force UI refresh
                            chats = []
                            objectWillChange.send()
                            
                            // Small delay for UI to process the empty state
                            try await Task.sleep(for: .milliseconds(50))
                            
                            // Set the updated chats
                            chats = updatedChats
                            objectWillChange.send()
                            
                            // Small delay to let UI update
                            try await Task.sleep(for: .milliseconds(100))
                        }
                    } else if let index = updatedChats.firstIndex(where: { $0.name == window.name }) {
                        // Update screenshot even if no new messages
                        updatedChats[index].latestScreenshot = nsImage
                        
                        // Reset the property to force UI refresh
                        chats = updatedChats
                        objectWillChange.send()
                    }
                } catch {
                    logger.error("Vision processing failed for window \(window.name): \(error.localizedDescription)")
                    errorMessage = "Failed to process text in chat window: \(error.localizedDescription)"
                    objectWillChange.send()
                }
            }
        }
        
        // Restore the selected chat if it exists
        if let selectedId = currentSelectedChatId, 
           let selectedChat = updatedChats.first(where: { $0.id == selectedId }) {
            self.selectedChat = selectedChat
        }
    }
    
    func selectChat(_ chat: Chat) {
        // Mark messages as read when chat is selected
        if let index = chats.firstIndex(where: { $0.id == chat.id }) {
            chats[index].unreadCount = 0
            saveChats() // Save the updated unread count
        }
        selectedChat = chat
    }
    
    // Make sort function public so it can be called when needed
    func sortChats() {
        chats.sort { $0.lastMessageTimestamp > $1.lastMessageTimestamp }
    }
    
    func captureScreen() {
        Task {
            isProcessing = true
            errorMessage = nil
            
            do {
                if let cgImage = try await screenCaptureService.captureScreen() {
                    let nsImage = NSImage(cgImage: cgImage, size: .zero)
                    fullScreenshot = nsImage
                    
                    // Process all windows one by one, with UI updates after each
                    await detectAndProcessKakaoWindows(in: cgImage)
                    
                    // Final UI refresh to ensure everything is up to date
                    objectWillChange.send()
                }
            } catch {
                handleError(error)
            }
            
            isProcessing = false
        }
    }
    
    private func handleError(_ error: Error) {
        logger.error("Screenshot error: \(error.localizedDescription)")
        if let captureError = error as? ScreenCaptureError {
            errorMessage = captureError.errorDescription
        } else {
            errorMessage = "Error capturing screenshot: \(error.localizedDescription)"
        }
    }
}

