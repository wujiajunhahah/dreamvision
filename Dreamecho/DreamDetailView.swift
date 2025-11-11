//
//  DreamDetailView.swift
//  Dreamecho
//
//  Created by sztu on 2025/11/9.
//

import SwiftUI

/// 梦境详情视图 - 符合 visionOS HIG 和辅助功能指南
struct DreamDetailView: View {
    let dream: Dream
    @Environment(\.dismiss) private var dismiss
    @Environment(AppModel.self) private var appModel
    @Environment(\.openImmersiveSpace) private var openImmersiveSpace
    @Environment(\.dismissImmersiveSpace) private var dismissImmersiveSpace
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showWindowPreview = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 12) {
                    Text(dream.title)
                        .font(DesignSystem.title)
                        .foregroundStyle(.primary)
                    
                    Text(dream.createdAt, style: .date)
                        .font(DesignSystem.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 20)
                
                // Description
                LiquidGlassCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Dream Description", systemImage: "text.alignleft")
                            .font(DesignSystem.headline)
                            .foregroundStyle(.primary)
                        
                        Text(dream.description)
                            .font(DesignSystem.body)
                            .foregroundStyle(.secondary)
                    }
                }
                
                // Analysis Results (if available)
                if let analysis = dream.analysis {
                    // Keywords
                    if !analysis.keywords.isEmpty {
                        LiquidGlassCard {
                            VStack(alignment: .leading, spacing: 12) {
                                Label("Keywords", systemImage: "tag.fill")
                                    .font(DesignSystem.headline)
                                    .foregroundStyle(.primary)
                                
                                FlowLayout(spacing: 8) {
                                    ForEach(analysis.keywords, id: \.self) { keyword in
                                        LiquidGlassTag(keyword, icon: "tag.fill")
                                    }
                                }
                            }
                        }
                    }
                    
                    // Emotions
                    if !analysis.emotions.isEmpty {
                        LiquidGlassCard {
                            VStack(alignment: .leading, spacing: 12) {
                                Label("Emotions", systemImage: "heart.fill")
                                    .font(DesignSystem.headline)
                                    .foregroundStyle(.primary)
                                
                                FlowLayout(spacing: 8) {
                                    ForEach(analysis.emotions, id: \.self) { emotion in
                                        LiquidGlassTag(emotion, icon: "heart.fill")
                                            .foregroundStyle(.pink)
                                    }
                                }
                            }
                        }
                    }
                    
                    // Symbols
                    if !analysis.symbols.isEmpty {
                        LiquidGlassCard {
                            VStack(alignment: .leading, spacing: 12) {
                                Label("Symbols", systemImage: "sparkles")
                                    .font(DesignSystem.headline)
                                    .foregroundStyle(.primary)
                                
                                FlowLayout(spacing: 8) {
                                    ForEach(analysis.symbols, id: \.self) { symbol in
                                        LiquidGlassTag(symbol, icon: "sparkles")
                                    }
                                }
                            }
                        }
                    }
                    
                    // Visual Description
                    if !analysis.visualDescription.isEmpty {
                        LiquidGlassCard {
                            VStack(alignment: .leading, spacing: 12) {
                                Label("Visual Description", systemImage: "eye.fill")
                                    .font(DesignSystem.headline)
                                    .foregroundStyle(.primary)
                                
                                Text(analysis.visualDescription)
                                    .font(DesignSystem.body)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    
                    // Interpretation
                    if !analysis.interpretation.isEmpty {
                        LiquidGlassCard {
                            VStack(alignment: .leading, spacing: 12) {
                                Label("Interpretation", systemImage: "brain.head.profile")
                                    .font(DesignSystem.headline)
                                    .foregroundStyle(.primary)
                                
                                Text(analysis.interpretation)
                                    .font(DesignSystem.body)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                
                // 重新生成按钮（如果梦境有分析但没有模型）
                if dream.analysis != nil && dream.modelURL == nil {
                    LiquidGlassButton(
                        "Generate 3D Model",
                        icon: "cube.fill",
                        style: .primary,
                        isEnabled: !appModel.dreamStore.isLoading
                    ) {
                        Task {
                            await appModel.dreamStore.generateModel(for: dream)
                        }
                    }
                    .accessibilityLabel("Generate 3D model for this dream")
                    .accessibilityHint("Creates a 3D visualization of your dream")
                }
                
                // 3D Model Buttons（如果已有模型）
                if dream.modelURL != nil {
                    VStack(spacing: 16) {
                        // 窗口预览按钮（快速预览）
                        LiquidGlassButton(
                            "Preview 3D Model",
                            icon: "cube.fill",
                            style: .secondary,
                            isEnabled: true
                        ) {
                            showWindowPreview = true
                        }
                        .accessibilityLabel("Preview 3D model in window")
                        .accessibilityHint("Opens a window preview of your dream model")
                        
                        // 沉浸式空间按钮（完整体验）
                        LiquidGlassButton(
                            "Enter Immersive Space",
                            icon: "cube.transparent.fill",
                            style: .primary,
                            isEnabled: appModel.immersiveSpaceState != .inTransition
                        ) {
                            Task { @MainActor in
                                // 防止重复操作
                                guard appModel.immersiveSpaceState != .inTransition else { return }
                                
                                // 如果空间已打开，先关闭再打开新的
                                if appModel.immersiveSpaceState == .open {
                                    // 如果选中的是同一个梦境，不需要重新打开
                                    if appModel.selectedDream?.id == dream.id {
                                        return
                                    }
                                    // 关闭当前空间
                                    appModel.immersiveSpaceState = .inTransition
                                    await dismissImmersiveSpace()
                                    // 等待一下确保空间完全关闭
                                    try? await Task.sleep(nanoseconds: 500_000_000) // 0.5秒
                                }
                                
                                // 设置选中的梦境
                                appModel.selectedDream = dream
                                
                                // 打开沉浸式空间
                                appModel.immersiveSpaceState = .inTransition
                                switch await openImmersiveSpace(id: appModel.immersiveSpaceID) {
                                case .opened:
                                    // 状态会在 ImmersiveView.onAppear 中更新为 .open
                                    break
                                case .userCancelled, .error:
                                    appModel.immersiveSpaceState = .closed
                                @unknown default:
                                    appModel.immersiveSpaceState = .closed
                                }
                            }
                        }
                        .accessibilityLabel("View dream in 3D immersive space")
                        .accessibilityHint("Opens a full immersive 3D view of your dream model")
                    }
                }
            }
            .padding(32)
        }
        .liquidGlassBackground()
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityModifiers()
        .sheet(isPresented: $showWindowPreview) {
            if let modelURL = dream.modelURL {
                DreamRealityView(
                    modelURL: modelURL,
                    dreamTitle: dream.title
                )
            }
        }
    }
}

#Preview {
    NavigationStack {
        DreamDetailView(dream: Dream(
            title: "Flying Dream",
            description: "I was flying freely through the sky",
            status: .completed,
            analysis: DreamAnalysis(
                keywords: ["flying", "sky", "freedom"],
                emotions: ["excitement", "joy"],
                symbols: ["wings", "clouds"],
                visualDescription: "A person flying through blue sky with white clouds",
                interpretation: "This dream represents a desire for freedom and escape from daily constraints."
            ),
            keywords: ["flying", "sky"],
            emotions: ["excitement"],
            symbols: ["wings"]
        ))
        .environment(AppModel())
    }
}

