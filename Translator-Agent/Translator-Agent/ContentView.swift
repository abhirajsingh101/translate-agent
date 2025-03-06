//
//  ContentView.swift
//  Translator-Agent
//
//  Created by Abhiraj Singh on 3/2/25.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = ScreenshotViewModel()
    
    var body: some View {
        NavigationSplitView {
            List(viewModel.chats, selection: $viewModel.selectedChat) { chat in
                NavigationLink(value: chat) {
                    ChatListItemView(chat: chat)
                }
            }
            .navigationTitle("Chats")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: viewModel.captureScreen) {
                        Label("Capture", systemImage: "camera")
                    }
                    .disabled(viewModel.isProcessing)
                }
            }
            .overlay {
                if viewModel.isProcessing {
                    ProgressView("Processing...")
                }
            }
        } detail: {
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
        .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
            Button("OK") {
                viewModel.errorMessage = nil
            }
        } message: {
            if let error = viewModel.errorMessage {
                Text(error)
            }
        }
    }
}

struct ChatListItemView: View {
    let chat: Chat
    
    var body: some View {
        HStack {
            if let screenshot = chat.latestScreenshot {
                Image(nsImage: screenshot)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 40, height: 40)
                    .clipShape(Circle())
            }
            
            VStack(alignment: .leading) {
                Text(chat.name)
                    .font(.headline)
                if let lastMessage = chat.messages.last {
                    Text(lastMessage.translatedText)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    ContentView()
}
