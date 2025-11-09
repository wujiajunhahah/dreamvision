//
//  DreamInputView.swift
//  Dreamecho
//
//  Created by sztu on 2025/11/9.
//

import SwiftUI

struct DreamInputView: View {
    @Environment(DreamStore.self) private var dreamStore
    @State private var title = ""
    @State private var description = ""
    @State private var isRecording = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showProcessingView = false
    @State private var processingDream: Dream?
    
    @State private var speechService = SpeechRecognitionService()
    
    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                // Header - 使用组件
                VStack(spacing: 12) {
                    Image(systemName: "moon.zzz.fill")
                        .font(.system(size: 56))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.blue, .purple],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .symbolEffect(.pulse, options: .repeating)
                    
                    Text("Record Your Dream")
                        .font(DesignSystem.title)
                        .foregroundStyle(.primary)
                    
                    Text("Transform your dreams into 3D models")
                        .font(DesignSystem.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 40)
                
                // Form - 使用组件化输入框
                VStack(spacing: 20) {
                    LiquidGlassTextField(
                        "Title",
                        text: $title,
                        placeholder: "Enter dream title",
                        icon: "text.badge.plus"
                    )
                    
                    LiquidGlassTextEditor(
                        "Description",
                        text: $description,
                        placeholder: "Describe your dream in detail...",
                        icon: "text.alignleft"
                    )
                    
                    // Voice input button - 使用组件
                    Button {
                        Task { @MainActor in
                            if isRecording {
                                speechService.stopListening()
                                description = speechService.transcribedText
                                isRecording = false
                            } else {
                                do {
                                    try await speechService.startListening()
                                    isRecording = true
                                } catch {
                                    errorMessage = error.localizedDescription
                                    showError = true
                                    isRecording = false
                                }
                            }
                        }
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: isRecording ? "mic.fill" : "mic")
                                .font(.system(size: 18, weight: .medium))
                                .symbolEffect(.pulse, isActive: isRecording)
                            Text(isRecording ? "Stop Recording" : "Voice Input")
                                .font(.system(size: 17, weight: .medium))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .foregroundStyle(isRecording ? .primary : .secondary)
                        .background(.ultraThinMaterial)
                        .cornerRadius(12)
                    }
                    .buttonStyle(.plain)
                    
                    if isRecording {
                        HStack(spacing: 8) {
                            Image(systemName: "waveform")
                                .font(.system(size: 14))
                                .foregroundStyle(.secondary)
                            Text(speechService.transcribedText.isEmpty ? "Listening..." : speechService.transcribedText)
                                .font(.system(size: 15))
                                .foregroundStyle(.secondary)
                        }
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.ultraThinMaterial)
                        .cornerRadius(12)
                    }
                }
                .padding(.horizontal, 32)
                
                Spacer(minLength: 40)
                
                // Analyze button - 只分析梦境
                LiquidGlassButton(
                    "Analyze Dream",
                    icon: "brain.head.profile",
                    style: .primary,
                    isEnabled: !title.isEmpty && !description.isEmpty && !dreamStore.isLoading
                ) {
                    createDream()
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 40)
                
                // Error message display
                if let errorMessage = dreamStore.errorMessage, !errorMessage.isEmpty {
                    LiquidGlassCard(padding: 16) {
                        HStack(spacing: 12) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 20))
                                .foregroundStyle(.red)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Error")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(.primary)
                                Text(errorMessage)
                                    .font(.system(size: 13))
                                    .foregroundStyle(.secondary)
                            }
                            
                            Spacer()
                            
                            Button {
                                dreamStore.errorMessage = nil
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 20))
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 32)
                    .padding(.bottom, 20)
                }
            }
        }
        .liquidGlassBackground()
        .accessibilityModifiers()
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
        .onChange(of: speechService.isListening) { oldValue, newValue in
            Task { @MainActor in
                isRecording = newValue
            }
        }
        .fullScreenCover(isPresented: $showProcessingView) {
            if let dream = processingDream {
                DreamProcessingView(dream: dream)
                    .environment(dreamStore)
            }
        }
    }
    
    private func createDream() {
        let dream = dreamStore.createDream(title: title, description: description)
        title = ""
        description = ""
        
        // 显示处理界面
        processingDream = dream
        showProcessingView = true
        
        // 开始分析
        Task {
            await dreamStore.analyzeDream(dream)
        }
    }
    
}

#Preview {
    DreamInputView()
        .environment(DreamStore())
}
