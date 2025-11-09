//
//  DreamechoApp.swift
//  Dreamecho
//
//  Created by sztu on 2025/11/9.
//

import SwiftUI

@main
struct DreamechoApp: App {
    @State private var dreamStore = DreamStore()
    @State private var appModel = AppModel()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(dreamStore)
                .environment(appModel)
        }
        .windowStyle(.automatic)
        
        ImmersiveSpace(id: appModel.immersiveSpaceID) {
            ImmersiveView()
                .environment(appModel)
        }
        .immersionStyle(selection: .constant(.full), in: .full)
    }
}
