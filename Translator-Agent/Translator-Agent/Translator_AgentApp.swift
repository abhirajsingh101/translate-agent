//
//  Translator_AgentApp.swift
//  Translator-Agent
//
//  Created by Abhiraj Singh on 3/2/25.
//

import SwiftUI

@main
struct Translator_AgentApp: App {
    var body: some Scene {
        WindowGroup {
            MainView()
                .frame(minWidth: 800, minHeight: 600)
        }
        .windowStyle(.hiddenTitleBar)
    }
}
