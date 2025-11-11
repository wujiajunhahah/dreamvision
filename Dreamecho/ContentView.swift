//
//  ContentView.swift
//  Dreamecho
//
//  Created by sztu on 2025/11/9.
//

import SwiftUI

struct ContentView: View {
    @Environment(DreamStore.self) private var dreamStore
    @Environment(AppModel.self) private var appModel
    
    @State private var selectedItem = LiquidGlassNavigationBar.NavigationItem(
        title: "Record",
        icon: "plus.circle.fill"
    )
    
    // 监听分析完成，自动切换到 Dreams 列表
    @State private var shouldSwitchToDreams = false
    
    private let navigationItems = [
        LiquidGlassNavigationBar.NavigationItem(
            title: "Record",
            icon: "plus.circle.fill"
        ),
        LiquidGlassNavigationBar.NavigationItem(
            title: "Dreams",
            icon: "moon.stars.fill"
        )
    ]

    var body: some View {
        VStack(spacing: 0) {
            // 液态玻璃导航栏
            LiquidGlassNavigationBar(
                items: navigationItems,
                selectedItem: $selectedItem
            )
            
            Divider()
                .opacity(0.2)
            
            // 内容区域
            Group {
                switch selectedItem.title {
                case "Record":
                    DreamInputView()
                case "Dreams":
                    DreamListView()
                default:
                    DreamInputView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .liquidGlassBackground()
        .accessibilityModifiers()
        .onChange(of: dreamStore.dreams.first?.status) { oldValue, newValue in
            // 如果有梦境分析完成，自动切换到 Dreams 列表
            if newValue == .analyzed, selectedItem.title == "Record" {
                selectedItem = navigationItems[1] // 切换到 Dreams
            }
        }
        .sheet(isPresented: Binding(
            get: { appModel.showModelPreview },
            set: { appModel.showModelPreview = $0 }
        )) {
            if let modelURL = appModel.previewModelURL,
               let title = appModel.previewDreamTitle {
                ModelPreviewView(modelURL: modelURL, dreamTitle: title)
                    .onDisappear {
                        // 清理预览状态
                        appModel.previewModelURL = nil
                        appModel.previewDreamTitle = nil
                        appModel.showModelPreview = false
                    }
            }
        }
        .fullScreenCover(isPresented: Binding(
            get: { appModel.showARQuickLook },
            set: { appModel.showARQuickLook = $0 }
        )) {
            if let modelURL = appModel.arQuickLookURL {
                ARQuickLookView(modelURL: modelURL) {
                    // 关闭 AR Quick Look
                    appModel.arQuickLookURL = nil
                    appModel.showARQuickLook = false
                }
            }
        }
    }
}

#Preview(windowStyle: .automatic) {
    ContentView()
        .environment(DreamStore())
        .environment(AppModel())
}
