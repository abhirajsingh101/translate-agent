import SwiftUI

struct MessageView: View {
    @ObservedObject var viewModel: ChatListViewModel
    let chat: Chat
    
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(chat.messages) { message in
                        MessageBubble(message: message)
                    }
                }
                .padding()
            }
            .onAppear {
                // Scroll to the last message when the view appears
                if let lastMessage = chat.messages.last {
                    withAnimation {
                        proxy.scrollTo(lastMessage.id, anchor: .bottom)
                    }
                }
            }
            .onChange(of: chat.messages) { _ in
                // Scroll to the bottom when new messages are added
                if let lastMessage = chat.messages.last {
                    withAnimation {
                        proxy.scrollTo(lastMessage.id, anchor: .bottom)
                    }
                }
            }
        }
    }
}

// Create a separate view for the message bubble
struct MessageBubble: View {
    let message: TranslatedMessage
    @State private var isExpanded = false
    
    var body: some View {
        HStack {
            if message.isFromMe { Spacer(minLength: 24) }
            
            VStack(alignment: .leading, spacing: 8) {
                // Show translated text if available, otherwise show original text
                HStack {
                    Text(message.translatedText.isEmpty ? message.originalText : message.translatedText)
                        .font(.body)
                        .foregroundColor(message.isFromMe ? .white : .primary)
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)
                        .textSelection(.enabled)
                    
                    Spacer(minLength: 4)
                    
                    // Only show dropdown if there's a translation
                    if !message.translatedText.isEmpty {
                        Image(systemName: isExpanded ? "chevron.up.circle.fill" : "chevron.down.circle.fill")
                            .font(.system(size: 16))
                            .foregroundColor(message.isFromMe ? .white : .blue)
                            .padding(4)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    isExpanded.toggle()
                                }
                            }
                    }
                }
                
                // Show original text only when expanded and there's a translation
                if isExpanded && !message.translatedText.isEmpty {
                    Divider()
                        .background(message.isFromMe ? .white.opacity(0.3) : .gray.opacity(0.3))
                    
                    Text(message.originalText)
                        .font(.callout)
                        .foregroundColor(message.isFromMe ? .white.opacity(0.9) : .secondary)
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)
                        .textSelection(.enabled)
                }
            }
            .padding(12)
            .background(
                message.isFromMe ?
                    Color.blue :
                    Color(NSColor.controlBackgroundColor).opacity(0.8)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(
                        message.isFromMe ?
                            Color.clear :
                            Color.gray.opacity(0.2),
                        lineWidth: 1
                    )
            )
            .cornerRadius(16)
            .frame(maxWidth: UIConstants.messageBubbleMaxWidth)
            
            if !message.isFromMe { Spacer(minLength: 24) }
        }
        .padding(.horizontal, 8)
    }
}

private enum UIConstants {
    static let messageBubbleMaxWidth: CGFloat = 400
}

// Update the preview provider
struct MessageView_Previews: PreviewProvider {
    static var previews: some View {
        let chat = Chat(
            name: "Test Chat",
            messages: [
                TranslatedMessage(
                    sender: "John",
                    originalText: "안녕하세요",
                    translatedText: "Hello",
                    timestamp: Date(),
                    position: .left
                ),
                TranslatedMessage(
                    sender: "Me",
                    originalText: "Hi there!",
                    translatedText: "Hi there!",
                    timestamp: Date(),
                    position: .right
                )
            ],
            latestScreenshot: nil
        )
        
        MessageView(viewModel: ChatListViewModel(), chat: chat)
            .frame(width: 400, height: 600)
    }
} 