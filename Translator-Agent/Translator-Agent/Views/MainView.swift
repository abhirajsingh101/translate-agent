import SwiftUI

struct MainView: View {
    @StateObject private var viewModel = ScreenshotViewModel()
    
    var body: some View {
        HSplitView {
            // Left sidebar with chat list
            VStack(spacing: 0) {
                // Update button at top
                Button(action: {
                    viewModel.captureScreen()
                }) {
                    Label("Update", systemImage: "arrow.clockwise")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.isProcessing)
                .padding(8)
                
                // Chat list
                List(viewModel.chats) { chat in
                    ChatRowView(chat: chat, isSelected: viewModel.selectedChat?.id == chat.id)
                        .onTapGesture {
                            viewModel.selectChat(chat)
                        }
                }
            }
            .frame(minWidth: 250, maxWidth: 350)
            
            // Right content - Selected chat view
            if let selectedChat = viewModel.selectedChat {
                ChatDetailView(chat: selectedChat)
            } else {
                ContentUnavailableView(
                    "No Chat Selected",
                    systemImage: "bubble.left",
                    description: Text("Select a chat from the sidebar")
                )
            }
        }
    }
}

// MARK: - Supporting Views
struct ChatDetailView: View {
    let chat: Chat
    @State private var scrolledToBottom = false
    
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 12) {
                    // Group messages by sender
                    ForEach(groupMessages(chat.messages)) { group in
                        VStack(alignment: group.position == .left ? .leading : .trailing, spacing: 4) {
                            // Show sender name for other people's messages
                            if group.position == .left {
                                Text(group.sender)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .padding(.horizontal)
                            }
                            
                            // Show messages in the group
                            ForEach(group.messages) { message in
                                MessageBubble(message: message)
                            }
                        }
                    }
                    
                    // Invisible anchor view at the bottom
                    Color.clear
                        .frame(height: 1)
                        .id("bottom")
                }
                .padding()
            }
            .onAppear {
                // Scroll to bottom with a slight delay to ensure view is laid out
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    withAnimation {
                        proxy.scrollTo("bottom", anchor: .bottom)
                    }
                    scrolledToBottom = true
                }
            }
            .onChange(of: chat.messages) { _ in
                // Scroll to bottom when new messages are added
                withAnimation {
                    proxy.scrollTo("bottom", anchor: .bottom)
                }
            }
            // Force scroll to bottom when chat changes
            .onChange(of: chat.id) { _ in
                scrolledToBottom = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    withAnimation {
                        proxy.scrollTo("bottom", anchor: .bottom)
                    }
                    scrolledToBottom = true
                }
            }
        }
    }
    
    // Helper function to group messages by sender
    private func groupMessages(_ messages: [TranslatedMessage]) -> [MessageGroup] {
        var groups: [MessageGroup] = []
        var currentGroup: MessageGroup?
        
        for message in messages {
            if let group = currentGroup, group.sender == message.sender {
                currentGroup?.messages.append(message)
            } else {
                if let group = currentGroup {
                    groups.append(group)
                }
                currentGroup = MessageGroup(
                    sender: message.sender,
                    messages: [message],
                    position: message.position
                )
            }
        }
        
        if let lastGroup = currentGroup {
            groups.append(lastGroup)
        }
        
        return groups
    }
} 