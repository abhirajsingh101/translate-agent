import SwiftUI

struct ChatRowView: View {
    let chat: Chat
    let isSelected: Bool
    
    var body: some View {
        HStack {
            Text(chat.name)
                .font(.headline)
            
            Spacer()
            
            if chat.unreadCount > 0 {
                Circle()
                    .fill(Color.red)
                    .frame(width: 8, height: 8)
                
                Text("\(chat.unreadCount)")
                    .foregroundColor(.red)
                    .font(.caption.bold())
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(Color.red.opacity(0.1))
                    )
            }
        }
        .padding(.vertical, 4)
        .background(isSelected ? Color.accentColor.opacity(0.1) : Color.clear)
    }
} 