import SwiftUI
import CoreGraphics

@MainActor
class ChatListViewModel: ObservableObject {
    @Published var chatWindows: [ChatWindow] = []
    
    init() {
        updateChatWindows()
    }
    
    func updateChatWindows() {
        // Get window list with specific options for active windows
        let options = CGWindowListOption([.optionOnScreenOnly, .excludeDesktopElements])
        guard let windowList = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
            return
        }
        
        // Filter and map KakaoTalk windows
        chatWindows = windowList.compactMap { info -> ChatWindow? in
            guard let owner = info[kCGWindowOwnerName as String] as? String,
                  owner.contains("KakaoTalk"),
                  let id = info[kCGWindowNumber as String] as? Int32,
                  let name = info[kCGWindowName as String] as? String,
                  let boundsDict = info[kCGWindowBounds as String] as? [String: CGFloat],
                  !name.isEmpty else {
                return nil
            }
            
            let rect = CGRect(
                x: boundsDict["X"] ?? 0,
                y: boundsDict["Y"] ?? 0,
                width: boundsDict["Width"] ?? 0,
                height: boundsDict["Height"] ?? 0
            )
            
            return ChatWindow(id: id, name: name, bounds: rect)
        }
    }
    
    // Call this when the update button is clicked
    func refreshWindows() {
        updateChatWindows()
    }
} 