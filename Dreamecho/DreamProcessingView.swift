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
    
    private let analysisTargetDuration: TimeInterval = 15 // 分析通常需要10-15秒
    private let generationTargetDuration: TimeInterval = 180 // 3D生成通常需要1.5-3分钟（180秒=3分钟，根据实际测试调整）
    
    var body: some View {
        ZStack {
            // 背景 - 液态玻璃效果
            LiquidGlassBackground()
                .ignoresSafeArea()
            
            // 内容
            VStack(spacing: 40) {
                Spacer()
                
                // 梦境标题 - 使用实时更新的标题（安全获取）
                let currentDreamState = dreamStore.dreams.first(where: { $0.id == dream.id }) ?? dream
                let currentStatus = currentDreamState.status
                
                // 如果状态是失败，显示错误信息
                if currentStatus == .failed {
                    VStack(spacing: 24) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 64))
                            .foregroundStyle(.orange)
                        
                        Text("分析失败")
                            .font(DesignSystem.title)
                            .foregroundStyle(.primary)
                        
                        if let errorMsg = dreamStore.errorMessage {
                            Text(errorMsg)
                                .font(DesignSystem.body)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 40)
                        }
                        
                        Button("返回") {
                            dismiss()
                        }
                        .buttonStyle(.borderedProminent)
                        .padding(.top, 20)
                    }
                } else {
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
            
            print("🔄 Status changed: \(oldValue?.rawValue ?? "nil") -> \(newValue.rawValue)")
            
            // 如果分析完成，自动关闭并返回列表
            if newValue == .analyzed {
                print("✅ Analysis completed, dismissing in 1.5s...")
                stopTimer()
                // 延迟一下让用户看到完成状态
                Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 1_500_000_000) // 1.5秒
                    print("🚪 Dismissing DreamProcessingView...")
                    dismiss()
                }
            }
            
            // 如果生成完成或失败，也关闭
            if newValue == .completed || newValue == .failed {
                print("✅ Processing \(newValue == .completed ? "completed" : "failed"), dismissing in 2s...")
                stopTimer()
                Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 2_000_000_000) // 2秒
                    print("🚪 Dismissing DreamProcessingView...")
                    dismiss()
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
            // 3D生成进度：基于实际时间，但不超过90%（保留10%给最终处理）
            let normalized = min(stageElapsed / generationTargetDuration, 0.9)
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
            // 如果超过预计时间，显示已用时间而不是剩余时间
            return remaining > 0 ? remaining : nil
        case .generating:
            // 3D生成时间较长，使用更灵活的预计时间
            // 如果已经超过预计时间，显示"Processing..."而不是剩余时间
            let remaining = max(generationTargetDuration - stageElapsed, 0)
            // 如果剩余时间少于1分钟，不显示预计时间（避免显示0秒）
            return remaining > 60 ? remaining : nil
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
