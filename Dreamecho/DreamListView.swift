//
//  DreamListView.swift
//  Dreamecho
//
//  Created by sztu on 2025/11/9.
//

import SwiftUI

struct DreamListView: View {
    @Environment(DreamStore.self) private var dreamStore
    @Environment(AppModel.self) private var appModel
    @Environment(\.openImmersiveSpace) private var openImmersiveSpace
    @Environment(\.dismissImmersiveSpace) private var dismissImmersiveSpace
    @State private var selectedDream: Dream?
    @State private var showDetail = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 16) {
                    // 测试按钮：加载本地 USDZ 格式模型（visionOS 最佳支持）
                    LiquidGlassCard {
                        VStack(spacing: 16) {
                            Text("✅ Test Local USDZ Model")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundStyle(.primary)
                            
                            Text("Load local USDZ file from Documents directory")
                                .font(.system(size: 16))
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                            
                            HStack(spacing: 12) {
                                // AR Quick Look 预览（USDZ 最佳预览方式）
                                LiquidGlassButton(
                                    "AR Quick Look",
                                    icon: "arkit",
                                    style: .primary,
                                    isEnabled: true
                                ) {
                                    Task {
                                        // 尝试从多个位置加载本地 USDZ 文件
                                        let fileManager = FileManager.default
                                        let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
                                        
                                        print("🔍 Searching for USDZ files in Documents directory: \(documentsURL.path)")
                                        
                                        var localFileURL: URL?
                                        
                                        // 1. 扫描 Documents 目录中的所有 USDZ 文件
                                        do {
                                            let files = try fileManager.contentsOfDirectory(at: documentsURL, includingPropertiesForKeys: [.isRegularFileKey])
                                            let usdzFiles = files.filter { $0.pathExtension.lowercased() == "usdz" }
                                            
                                            if !usdzFiles.isEmpty {
                                                print("✅ Found \(usdzFiles.count) USDZ file(s) in Documents directory:")
                                                for file in usdzFiles {
                                                    print("   📄 \(file.lastPathComponent)")
                                                }
                                                localFileURL = usdzFiles.first
                                                print("✅ Using first USDZ file: \(localFileURL!.lastPathComponent)")
                                            } else {
                                                print("⚠️ No USDZ files found in Documents directory")
                                            }
                                        } catch {
                                            print("❌ Error scanning Documents directory: \(error.localizedDescription)")
                                        }
                                        
                                        // 2. 如果没找到，尝试从 Bundle 加载
                                        if localFileURL == nil {
                                            print("🔍 Searching for USDZ files in Bundle...")
                                            let possibleFileNames = [
                                                "test_model.usdz",
                                                "dream_model.usdz",
                                                "model.usdz",
                                                "1213.usdz",
                                                "dream_model_1742979231.usdz"
                                            ]
                                            
                                            for fileName in possibleFileNames {
                                                if let bundleURL = Bundle.main.url(forResource: fileName.replacingOccurrences(of: ".usdz", with: ""), withExtension: "usdz") {
                                                    localFileURL = bundleURL
                                                    print("✅ Found USDZ file in Bundle: \(fileName)")
                                                    break
                                                }
                                            }
                                        }
                                        
                                        if let fileURL = localFileURL {
                                            print("✅✅✅ Successfully found USDZ file: \(fileURL.path)")
                                            await MainActor.run {
                                                appModel.arQuickLookURL = fileURL
                                                appModel.showARQuickLook = true
                                                print("🔍 Opening AR Quick Look for local USDZ file: \(fileURL.lastPathComponent)")
                                            }
                                        } else {
                                            print("❌ No local USDZ file found.")
                                            print("💡 Documents directory: \(documentsURL.path)")
                                            print("💡 Please copy a USDZ file to the Documents directory or add it to the Xcode project Bundle")
                                        }
                                    }
                                }
                                
                                // 沉浸式空间预览（USDZ 在 visionOS 上支持最好）
                                LiquidGlassButton(
                                    "Immersive",
                                    icon: "cube.transparent.fill",
                                    style: .primary,
                                    isEnabled: appModel.immersiveSpaceState != .inTransition
                                ) {
                                    Task {
                                        // 尝试从多个位置加载本地 USDZ 文件
                                        let fileManager = FileManager.default
                                        let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
                                        
                                        print("🔍 Searching for USDZ files in Documents directory: \(documentsURL.path)")
                                        
                                        var localFileURL: URL?
                                        
                                        // 1. 扫描 Documents 目录中的所有 USDZ 文件
                                        do {
                                            let files = try fileManager.contentsOfDirectory(at: documentsURL, includingPropertiesForKeys: [.isRegularFileKey])
                                            let usdzFiles = files.filter { $0.pathExtension.lowercased() == "usdz" }
                                            
                                            if !usdzFiles.isEmpty {
                                                print("✅ Found \(usdzFiles.count) USDZ file(s) in Documents directory:")
                                                for file in usdzFiles {
                                                    print("   📄 \(file.lastPathComponent)")
                                                }
                                                localFileURL = usdzFiles.first
                                                print("✅ Using first USDZ file: \(localFileURL!.lastPathComponent)")
                                            } else {
                                                print("⚠️ No USDZ files found in Documents directory")
                                            }
                                        } catch {
                                            print("❌ Error scanning Documents directory: \(error.localizedDescription)")
                                        }
                                        
                                        // 2. 如果没找到，尝试从 Bundle 加载
                                        if localFileURL == nil {
                                            print("🔍 Searching for USDZ files in Bundle...")
                                            let possibleFileNames = [
                                                "test_model.usdz",
                                                "dream_model.usdz",
                                                "model.usdz",
                                                "1213.usdz",
                                                "dream_model_1742979231.usdz"
                                            ]
                                            
                                            for fileName in possibleFileNames {
                                                if let bundleURL = Bundle.main.url(forResource: fileName.replacingOccurrences(of: ".usdz", with: ""), withExtension: "usdz") {
                                                    localFileURL = bundleURL
                                                    print("✅ Found USDZ file in Bundle: \(fileName)")
                                                    break
                                                }
                                            }
                                        }
                                        
                                        guard let fileURL = localFileURL else {
                                            print("❌ No local USDZ file found.")
                                            print("💡 Documents directory: \(documentsURL.path)")
                                            print("💡 Please copy a USDZ file to the Documents directory or add it to the Xcode project Bundle")
                                            return
                                        }
                                        
                                        print("✅✅✅ Successfully found USDZ file: \(fileURL.path)")
                                        
                                        // 使用 file:// URL 格式
                                        let fileURLString = fileURL.absoluteString
                                        print("📦 USDZ file URL: \(fileURLString)")
                                        
                                        // 创建一个临时 Dream 对象用于测试 USDZ
                                        let testDream = Dream(
                                            id: UUID(),
                                            title: "Test Local USDZ Model",
                                            description: "Local USDZ file (optimal format for visionOS)",
                                            createdAt: Date(),
                                            status: .completed,
                                            modelURL: fileURLString
                                        )
                                        appModel.selectedDream = testDream
                                        
                                        if appModel.immersiveSpaceState == .open {
                                            await dismissImmersiveSpace()
                                            try? await Task.sleep(nanoseconds: 1_200_000_000)
                                        }
                                        
                                        appModel.immersiveSpaceState = .inTransition
                                        let result = await openImmersiveSpace(id: appModel.immersiveSpaceID)
                                        switch result {
                                        case .opened:
                                            print("✅ Immersive space opened for local USDZ test model")
                                        case .userCancelled:
                                            appModel.immersiveSpaceState = .closed
                                        case .error:
                                            appModel.immersiveSpaceState = .closed
                                        @unknown default:
                                            appModel.immersiveSpaceState = .closed
                                        }
                                    }
                                }
                            }
                        }
                        .padding(20)
                    }
                    .padding(.horizontal, 32)
                    
                    if dreamStore.dreams.isEmpty {
                        emptyState
                    } else {
                        // 按创建时间倒序排列（最新的在前）
                        ForEach(dreamStore.dreams.sorted(by: { $0.createdAt > $1.createdAt })) { dream in
                            DreamCard(
                                dream: dream,
                                selectedDream: $selectedDream,
                                showDetail: $showDetail
                            )
                            .onTapGesture {
                                selectedDream = dream
                                showDetail = true
                            }
                        }
                    }
                }
                .padding(32)
            }
            .liquidGlassBackground()
            .navigationDestination(isPresented: $showDetail) {
                if let dream = selectedDream {
                    DreamDetailView(dream: dream)
                }
            }
        }
        .accessibilityModifiers()
                .task {
                    // 优先加载保存的梦境，如果没有再加载示例数据
                    if dreamStore.dreams.isEmpty {
                        dreamStore.loadSampleDreamsIfNeeded()
                    }
                }
    }
    
    private var emptyState: some View {
        LiquidGlassCard {
            VStack(spacing: 20) {
                Image(systemName: "moon.stars")
                    .font(.system(size: 64))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.blue.opacity(0.6), .purple.opacity(0.6)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .symbolEffect(.pulse, options: .repeating)
                
                Text("No Dreams Yet")
                    .font(DesignSystem.title2)
                    .foregroundStyle(.primary)
                
                Text("Record your first dream to get started")
                    .font(DesignSystem.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(60)
        }
    }
}

struct DreamCard: View {
    let dream: Dream
    @Environment(DreamStore.self) private var dreamStore
    @Environment(AppModel.self) private var appModel
    @Environment(\.openImmersiveSpace) private var openImmersiveSpace
    @Environment(\.dismissImmersiveSpace) private var dismissImmersiveSpace
    @State private var showProcessingView = false
    @Binding var selectedDream: Dream?
    @Binding var showDetail: Bool
    
    var body: some View {
        LiquidGlassCard {
            VStack(alignment: .leading, spacing: 16) {
                // Header
                HStack {
                    HStack(spacing: 10) {
                        Image(systemName: statusIcon(for: dream.status))
                            .font(.system(size: 18, weight: .medium))
                            .foregroundStyle(statusColor(for: dream.status))
                        
                        Text(dream.title)
                            .font(DesignSystem.title2)
                            .foregroundStyle(.primary)
                    }
                    
                    Spacer()
                    
                    StatusBadge(status: dream.status)
                }
                
                // Description
                Text(dream.description)
                    .font(DesignSystem.body)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
                
                // Analysis Preview
                if let analysis = dream.analysis {
                    VStack(alignment: .leading, spacing: 12) {
                        if !analysis.keywords.isEmpty {
                            HStack(spacing: 8) {
                                Image(systemName: "tag.fill")
                                    .font(.system(size: 12))
                                    .foregroundStyle(.secondary)
                                Text("\(analysis.keywords.count) keywords")
                                    .font(DesignSystem.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        
                        if !analysis.emotions.isEmpty {
                            HStack(spacing: 8) {
                                Image(systemName: "heart.fill")
                                    .font(.system(size: 12))
                                    .foregroundStyle(.pink)
                                Text("\(analysis.emotions.count) emotions")
                                    .font(DesignSystem.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                
                // Keywords - 使用组件
                if !dream.keywords.isEmpty {
                    FlowLayout(spacing: 8) {
                        ForEach(dream.keywords.prefix(5), id: \.self) { keyword in
                            LiquidGlassTag(keyword, icon: "tag.fill")
                        }
                    }
                }
                
                // Generate Model Button (仅当已分析但未生成模型时显示)
                if dream.status == .analyzed && dream.modelURL == nil {
                    LiquidGlassButton(
                        "Generate 3D Model",
                        icon: "cube.transparent.fill",
                        style: .primary,
                        isEnabled: !dreamStore.isLoading
                    ) {
                        showProcessingView = true
                        Task {
                            await dreamStore.generateModel(for: dream)
                        }
                    }
                    .padding(.top, 8)
                }
                
                // View Model Buttons (当模型已生成时显示)
                if dream.modelURL != nil {
                    HStack(spacing: 12) {
                        // 沉浸式空间按钮
                        LiquidGlassButton(
                            "Immersive",
                            icon: "cube.transparent.fill",
                            style: .primary,
                            isEnabled: appModel.immersiveSpaceState != .inTransition
                        ) {
                        Task { @MainActor in
                            // 防止重复操作：如果正在过渡中，直接返回
                            guard appModel.immersiveSpaceState != .inTransition else {
                                print("⚠️ Immersive space is already in transition, ignoring request")
                                return
                            }
                            
                            // 如果选中的是同一个梦境且空间已打开，不需要重新打开
                            if appModel.selectedDream?.id == dream.id && appModel.immersiveSpaceState == .open {
                                print("✅ Same dream already in immersive space, no action needed")
                                return
                            }
                            
                            // 如果空间已打开，先关闭（无论是否同一个梦境）
                            if appModel.immersiveSpaceState == .open {
                                print("🔄 Closing existing immersive space...")
                                appModel.immersiveSpaceState = .inTransition
                                await dismissImmersiveSpace()
                                // 等待空间完全关闭（增加等待时间确保完全关闭）
                                try? await Task.sleep(nanoseconds: 1_200_000_000) // 1.2秒
                                appModel.immersiveSpaceState = .closed
                                print("✅ Immersive space closed")
                            }
                            
                            // 设置选中的梦境
                            appModel.selectedDream = dream
                            
                            // 打开沉浸式空间
                            print("🔄 Opening immersive space for dream: \(dream.title)")
                            appModel.immersiveSpaceState = .inTransition
                            
                            let result = await openImmersiveSpace(id: appModel.immersiveSpaceID)
                            switch result {
                            case .opened:
                                print("✅ Immersive space opened successfully")
                                // 状态会在 ImmersiveView.onAppear 中更新为 .open
                                break
                            case .userCancelled:
                                print("⚠️ User cancelled immersive space opening")
                                appModel.immersiveSpaceState = .closed
                            case .error:
                                print("❌ Error opening immersive space")
                                appModel.immersiveSpaceState = .closed
                            @unknown default:
                                print("⚠️ Unknown result from openImmersiveSpace")
                                appModel.immersiveSpaceState = .closed
                            }
                        }
                        }
                        
                        // AR Quick Look 预览按钮（推荐用于 USDZ 格式）
                        LiquidGlassButton(
                            "AR Preview",
                            icon: "arkit",
                            style: .secondary,
                            isEnabled: true
                        ) {
                            if let modelURLString = dream.modelURL {
                                Task {
                                    do {
                                        let localURL = try await ModelPreviewCoordinator.shared.downloadModelForPreview(urlString: modelURLString)
                                        await MainActor.run {
                                            appModel.arQuickLookURL = localURL
                                            appModel.showARQuickLook = true
                                            print("🔍 Opening AR Quick Look for: \(dream.title)")
                                        }
                                    } catch {
                                        print("❌ Failed to prepare model for AR Quick Look: \(error.localizedDescription)")
                                        // 如果 AR Quick Look 失败，回退到窗口预览
                                        await MainActor.run {
                                            appModel.previewModelURL = modelURLString
                                            appModel.previewDreamTitle = dream.title
                                            appModel.showModelPreview = true
                                        }
                                    }
                                }
                            }
                        }
                        
                        // 窗口预览按钮（特别适用于 GLB 格式）
                        LiquidGlassButton(
                            "Window Preview",
                            icon: "rectangle.inset.filled.and.person.filled",
                            style: .secondary,
                            isEnabled: true
                        ) {
                            if let modelURL = dream.modelURL {
                                appModel.previewModelURL = modelURL
                                appModel.previewDreamTitle = dream.title
                                appModel.showModelPreview = true
                                print("🪟 Opening window preview for: \(dream.title)")
                            }
                        }
                        
                        // 导出模型按钮（保存到 Documents 目录）
                        LiquidGlassButton(
                            "Export Model",
                            icon: "square.and.arrow.down",
                            style: .secondary,
                            isEnabled: true
                        ) {
                            if let modelURL = dream.modelURL {
                                Task {
                                    do {
                                        let exportedURL = try await ModelExporter.shared.exportModelToDocuments(
                                            modelURL: modelURL,
                                            dreamTitle: dream.title
                                        )
                                        print("✅ Model exported successfully to: \(exportedURL.path)")
                                        print("📁 You can find it in: Documents/ExportedModels/")
                                        
                                        // 显示成功提示
                                        await MainActor.run {
                                            // 可以在这里添加一个 toast 提示
                                        }
                                    } catch {
                                        print("❌ Failed to export model: \(error.localizedDescription)")
                                    }
                                }
                            }
                        }
                    }
                    .padding(.top, 8)
                }
                
                // Footer
                HStack {
                    HStack(spacing: 6) {
                        Image(systemName: "clock")
                            .font(.system(size: 12))
                        Text(dream.createdAt, style: .relative)
                            .font(DesignSystem.caption)
                    }
                    .foregroundStyle(.tertiary)
                    
                    Spacer()
                    
                    if dream.modelURL != nil {
                        HStack(spacing: 6) {
                            Image(systemName: "cube.transparent.fill")
                                .font(.system(size: 14))
                            Text("3D Model")
                                .font(DesignSystem.caption)
                        }
                        .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .fullScreenCover(isPresented: $showProcessingView) {
            DreamProcessingView(dream: dream)
                .environment(dreamStore)
                .onChange(of: dreamStore.dreams.first(where: { $0.id == dream.id })?.status) { oldValue, newValue in
                    // 如果生成完成，关闭处理界面
                    if newValue == .completed || newValue == .failed {
                        showProcessingView = false
                    }
                }
        }
    }
    
    func statusIcon(for status: DreamStatus) -> String {
        switch status {
        case .draft: return "doc.text"
        case .analyzing: return "brain.head.profile"
        case .analyzed: return "checkmark.circle"
        case .generating: return "sparkles"
        case .completed: return "checkmark.circle.fill"
        case .failed: return "exclamationmark.triangle.fill"
        }
    }
    
    func statusColor(for status: DreamStatus) -> Color {
        switch status {
        case .draft: return .secondary
        case .analyzing, .generating: return .blue
        case .analyzed: return .orange
        case .completed: return .green
        case .failed: return .red
        }
    }
}

struct StatusBadge: View {
    let status: DreamStatus
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: statusIcon)
                .font(.system(size: 11))
            Text(status.rawValue)
                .font(DesignSystem.caption)
                .fontWeight(.medium)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(statusColor.opacity(0.15))
        .foregroundStyle(statusColor)
        .cornerRadius(8)
    }
    
    private var statusIcon: String {
        switch status {
        case .draft: return "doc.text"
        case .analyzing: return "brain.head.profile"
        case .analyzed: return "checkmark.circle"
        case .generating: return "sparkles"
        case .completed: return "checkmark.circle.fill"
        case .failed: return "exclamationmark.triangle.fill"
        }
    }
    
    private var statusColor: Color {
        switch status {
        case .draft: return .secondary
        case .analyzing, .generating: return .blue
        case .analyzed: return .orange
        case .completed: return .green
        case .failed: return .red
        }
    }
}

// Flow layout for tags
struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(
            in: proposal.replacingUnspecifiedDimensions().width,
            subviews: subviews,
            spacing: spacing
        )
        return result.size
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(
            in: bounds.width,
            subviews: subviews,
            spacing: spacing
        )
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + result.frames[index].minX,
                                     y: bounds.minY + result.frames[index].minY),
                         proposal: .unspecified)
        }
    }
    
    struct FlowResult {
        var size: CGSize = .zero
        var frames: [CGRect] = []
        
        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var currentX: CGFloat = 0
            var currentY: CGFloat = 0
            var lineHeight: CGFloat = 0
            
            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)
                
                if currentX + size.width > maxWidth && currentX > 0 {
                    currentX = 0
                    currentY += lineHeight + spacing
                    lineHeight = 0
                }
                
                frames.append(CGRect(x: currentX, y: currentY, width: size.width, height: size.height))
                lineHeight = max(lineHeight, size.height)
                currentX += size.width + spacing
            }
            
            self.size = CGSize(width: maxWidth, height: currentY + lineHeight)
        }
    }
}

#Preview {
    DreamListView()
        .environment(DreamStore())
        .environment(AppModel())
}
