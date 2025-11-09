//
//  DreamProcessingView.swift
//  Dreamecho
//
//  Created by sztu on 2025/11/9.
//

import SwiftUI

/// 全屏等待界面 - 显示梦境处理进度和预计时间
struct DreamProcessingView: View {
    let dream: Dream
    @Environment(\.dismiss) private var dismiss
    @Environment(DreamStore.self) private var dreamStore
    
    @State private var elapsedTime: TimeInterval = 0
    @State private var timer: Timer?
    
    private let analysisTargetDuration: TimeInterval = 12
    private let generationTargetDuration: TimeInterval = 80
    
    var body: some View {
        ZStack {
            // 背景 - 液态玻璃效果
            LiquidGlassBackground()
                .ignoresSafeArea()
            
            // 内容
            VStack(spacing: 40) {
                Spacer()
                
                // 梦境标题 - 使用实时更新的标题
                let currentDreamState = dreamStore.dreams.first(where: { $0.id == dream.id }) ?? dream
                let currentStatus = currentDreamState.status
                VStack(spacing: 12) {
                    Text(currentDreamState.title)
                        .font(DesignSystem.title)
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.center)
                    
                    Text("Processing your dream...")
                        .font(DesignSystem.subheadline)
                        .foregroundStyle(.secondary)
                }
                
                DreamProgressView(
                    status: currentStatus,
                    progress: progress(for: currentDreamState),
                    message: messageForStatus(currentStatus)
                )
                .frame(maxWidth: 500)
                
                // 预计时间显示
                if let estimatedTime = estimatedTime(for: currentDreamState) {
                    VStack(spacing: 8) {
                        HStack(spacing: 8) {
                            Image(systemName: "clock.fill")
                                .font(.system(size: 16))
                                .foregroundStyle(.secondary)
                            Text("Estimated time remaining")
                                .font(DesignSystem.caption)
                                .foregroundStyle(.secondary)
                        }
                        
                        Text(formatTime(estimatedTime))
                            .font(DesignSystem.title2)
                            .foregroundStyle(.primary)
                    }
                    .padding(20)
                    .background(.ultraThinMaterial)
                    .cornerRadius(16)
                }
                
                // 已用时间
                VStack(spacing: 4) {
                    Text("Elapsed time")
                        .font(DesignSystem.caption)
                        .foregroundStyle(.tertiary)
                    Text(formatTime(elapsedTime))
                        .font(DesignSystem.subheadline)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                // 取消按钮（仅在分析阶段显示）
                if currentStatus == .analyzing {
                    Button {
                        // 取消处理
                        Task {
                            await dreamStore.cancelProcessing(dream)
                        }
                        dismiss()
                    } label: {
                        Text("Cancel")
                            .font(DesignSystem.body)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 12)
                            .background(.ultraThinMaterial)
                            .cornerRadius(12)
                    }
                    .buttonStyle(.plain)
                    .padding(.bottom, 40)
                }
            }
            .padding(40)
        }
        .onAppear {
            startTimer()
        }
        .onDisappear {
            stopTimer()
        }
        .onChange(of: dreamStore.dreams.first(where: { $0.id == dream.id })?.status) { oldValue, newValue in
            guard let newValue = newValue else { return }
            
            // 如果分析完成，自动关闭并返回列表
            if newValue == .analyzed {
                stopTimer()
                // 延迟一下让用户看到完成状态
                Task {
                    try? await Task.sleep(nanoseconds: 1_500_000_000) // 1.5秒
                    await MainActor.run {
                        dismiss()
                    }
                }
            }
            
            // 如果生成完成或失败，也关闭
            if newValue == .completed || newValue == .failed {
                stopTimer()
                Task {
                    try? await Task.sleep(nanoseconds: 2_000_000_000) // 2秒
                    await MainActor.run {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            elapsedTime += 0.1
        }
    }
    
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
    
    private func progress(for currentDream: Dream) -> Double {
        let status = currentDream.status
        let stageElapsed = stageElapsedTime(for: currentDream)
        
        switch status {
        case .draft: return 0.0
        case .analyzing: 
            let normalized = min(stageElapsed / analysisTargetDuration, 1.0)
            return 0.1 + normalized * 0.4 // 10% - 50%
        case .analyzed: return 1.0
        case .generating:
            let normalized = min(stageElapsed / generationTargetDuration, 1.0)
            return 0.5 + normalized * 0.4 // 50% - 90%
        case .completed: return 1.0
        case .failed: return 0.0
        }
    }
    
    private func messageForStatus(_ status: DreamStatus) -> String {
        switch status {
        case .draft: return "Preparing..."
        case .analyzing: return "Analyzing your dream with AI..."
        case .analyzed: return "Analysis completed!"
        case .generating: return "Generating 3D model..."
        case .completed: return "Dream model generated!"
        case .failed: return "Processing failed. Please try again."
        }
    }
    
    private func estimatedTime(for currentDream: Dream) -> TimeInterval? {
        let stageElapsed = stageElapsedTime(for: currentDream)
        
        switch currentDream.status {
        case .analyzing:
            let remaining = max(analysisTargetDuration - stageElapsed, 0)
            return remaining > 0 ? remaining : nil
        case .generating:
            let remaining = max(generationTargetDuration - stageElapsed, 0)
            return remaining > 0 ? remaining : nil
        default:
            return nil
        }
    }
    
    private func stageElapsedTime(for dream: Dream) -> TimeInterval {
        guard let start = dream.statusUpdatedAt else { return 0 }
        return max(Date().timeIntervalSince(start), 0)
    }
    
    private func formatTime(_ time: TimeInterval) -> String {
        if time < 60 {
            return String(format: "%.0f seconds", time)
        } else {
            let minutes = Int(time) / 60
            let seconds = Int(time) % 60
            return "\(minutes)m \(seconds)s"
        }
    }
}

#Preview {
    DreamProcessingView(
        dream: Dream(
            title: "Flying Dream",
            description: "I was flying through the sky",
            status: .analyzing
        )
    )
    .environment(DreamStore())
}
