//
//  ImmersiveView.swift
//  Dreamecho
//
//  Created by sztu on 2025/11/9.
//

import SwiftUI
import RealityKit
import RealityKitContent
import ARKit
import ModelIO
import SceneKit

/// 沉浸式视图 - 符合 visionOS HIG 和空间计算最佳实践
/// 参考: https://developer.apple.com/cn/visionos/
struct ImmersiveView: View {
    @Environment(AppModel.self) private var appModel
    @State private var modelEntity: Entity?
    @State private var scale: Float = 1.0
    @State private var rotation: Float = 0.0
    @State private var position: SIMD3<Float> = [0, 0, -1.5] // 初始位置
    @State private var isModelLoaded = false
    @State private var isPlacingMode = false // 放置模式
    @State private var dragOffset: CGSize = .zero // 拖拽偏移
    @State private var showGLBError = false // 显示 GLB 加载错误
    @State private var glbScene: SCNScene? // GLB 场景（使用 SceneKit 显示）
    @State private var glbCacheURL: URL? // GLB 缓存文件路径
    
    // 错误提示框位置和移动
    @State private var errorPanelPosition: SIMD3<Float> = [0, 0, -0.8] // 在用户前方 0.8 米
    @State private var isDraggingErrorPanel = false // 是否正在拖拽错误面板
    @State private var errorPanelDragOffset: SIMD3<Float> = [0, 0, 0] // 拖拽偏移量

    var body: some View {
        RealityView { content in
            // 创建沉浸式场景
            let scene = await createImmersiveScene()
            content.add(scene)
        }
        .gesture(
            // 拖拽手势 - 移动模型位置
            DragGesture()
                .onChanged { value in
                    if isPlacingMode {
                        // 在放置模式下，根据拖拽更新位置
                        // 将屏幕坐标转换为3D空间坐标
                        let sensitivity: Float = 0.01 // 灵敏度
                        let deltaX = Float(value.translation.width) * sensitivity
                        let deltaY = Float(-value.translation.height) * sensitivity // Y轴反转
                        
                        position.x += deltaX
                        position.y += deltaY
                        position.z = -1.5 // 保持Z轴距离
                        
                        if let entity = modelEntity {
                            entity.position = position
                        }
                    }
                }
        )
        .gesture(
            // 捏合手势 - 缩放（Vision Pro 原生支持，0.3x - 5x）
            MagnifyGesture()
                .onChanged { value in
                    let newScale = scale * Float(value.magnification)
                    scale = min(max(newScale, 0.3), 5.0)
                    if let entity = modelEntity {
                        entity.scale = [scale, scale, scale]
                    }
                }
                .onEnded { _ in
                    // 手势结束，保持当前缩放
                }
        )
        .gesture(
            // 旋转手势
            RotateGesture()
                .onChanged { value in
                    rotation += Float(value.rotation.radians)
                    if let entity = modelEntity {
                        let quat = simd_quatf(angle: rotation, axis: [0, 1, 0])
                        entity.orientation = quat
                    }
                }
        )
        .overlay(alignment: .bottom) {
            // 控制面板 - 使用液态玻璃效果
            VStack(spacing: 20) {
                if let dream = appModel.selectedDream {
                    // 梦境信息卡片
                    LiquidGlassCard(padding: 20) {
                        VStack(spacing: 16) {
                            // Title
                            Text(dream.title)
                                .font(.system(size: 28, weight: .bold))
                                .foregroundStyle(.primary)
                                .accessibilityAddTraits(.isHeader)
                            
                            // Analysis Summary
                            if let analysis = dream.analysis {
                                VStack(spacing: 12) {
                                    // Keywords
                                    if !analysis.keywords.isEmpty {
                                        HStack(spacing: 8) {
                                            Image(systemName: "tag.fill")
                                                .font(.system(size: 14))
                                                .accessibilityHidden(true)
                                            Text(analysis.keywords.joined(separator: ", "))
                                                .font(.system(size: 18))
                                        }
                                        .foregroundStyle(.secondary)
                                        .accessibilityLabel("Keywords: \(analysis.keywords.joined(separator: ", "))")
                                    }
                                    
                                    // Interpretation
                                    if !analysis.interpretation.isEmpty {
                                        Text(analysis.interpretation)
                                            .font(.system(size: 18))
                                            .foregroundStyle(.secondary)
                                            .multilineTextAlignment(.center)
                                            .lineLimit(3)
                                            .accessibilityLabel("Interpretation: \(analysis.interpretation)")
                                    }
                                }
                            }
                            
                            // Controls
                            VStack(spacing: 12) {
                                // 放置模式切换
                                Button {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                        isPlacingMode.toggle()
                                    }
                                } label: {
                                    Label(
                                        isPlacingMode ? "Exit Placement" : "Place Model",
                                        systemImage: isPlacingMode ? "hand.raised.fill" : "hand.raised"
                                    )
                                    .font(.system(size: 20, weight: .semibold))
                                    .padding(.horizontal, 24)
                                    .padding(.vertical, 16)
                                    .background(
                                        Group {
                                            if isPlacingMode {
                                                RoundedRectangle(cornerRadius: 8)
                                                    .fill(Color.blue.opacity(0.3))
                                            } else {
                                                RoundedRectangle(cornerRadius: 8)
                                                    .fill(.ultraThinMaterial)
                                            }
                                        }
                                    )
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel(isPlacingMode ? "Exit placement mode" : "Enter placement mode to move model")
                                
                                if isPlacingMode {
                                    Text("Drag to move model")
                                        .font(.system(size: 18))
                                        .foregroundStyle(.secondary)
                                }
                                
                                HStack(spacing: 16) {
                                    // Reset Position & Scale
                                    Button {
                                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                            scale = 1.0
                                            rotation = 0.0
                                            position = [0, 0, -1.5]
                                            if let entity = modelEntity {
                                                entity.scale = [1.0, 1.0, 1.0]
                                                entity.orientation = simd_quatf(angle: 0, axis: [0, 1, 0])
                                                entity.position = position
                                            }
                                        }
                                    } label: {
                                        Label("Reset", systemImage: "arrow.counterclockwise")
                                            .font(.system(size: 20, weight: .semibold))
                                            .padding(.horizontal, 24)
                                            .padding(.vertical, 16)
                                            .background(.ultraThinMaterial)
                                            .cornerRadius(8)
                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityLabel("Reset model position, rotation and scale")
                                    
                                    // Rotate
                                    Button {
                                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                            rotation += .pi / 2
                                            if let entity = modelEntity {
                                                let quat = simd_quatf(angle: rotation, axis: [0, 1, 0])
                                                entity.move(
                                                    to: Transform(rotation: quat),
                                                    relativeTo: entity.parent,
                                                    duration: 0.5,
                                                    timingFunction: .easeInOut
                                                )
                                            }
                                        }
                                    } label: {
                                        Label("Rotate", systemImage: "arrow.triangle.2.circlepath")
                                            .font(.system(size: 20, weight: .semibold))
                                            .padding(.horizontal, 24)
                                            .padding(.vertical, 16)
                                            .background(.ultraThinMaterial)
                                            .cornerRadius(8)
                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityLabel("Rotate model 90 degrees")
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 60)
                }
                
                ToggleImmersiveSpaceButton()
                    .font(.system(size: 20, weight: .semibold))
                    .padding(.horizontal, 24)
                    .padding(.vertical, 16)
                    .padding(.bottom, 60)
            }
            .frame(maxWidth: 800) // 限制最大宽度，确保可读性
        }
        .onAppear {
            // 更新沉浸式空间状态为已打开
            appModel.immersiveSpaceState = .open
            
            // 重置模型加载状态，以便重新加载
            isModelLoaded = false
            
            // 当视图出现时，如果有选中的梦境，加载模型
            if let dream = appModel.selectedDream,
               let modelURL = dream.modelURL {
                Task {
                    await loadDreamModelIfNeeded(url: modelURL)
                }
            }
        }
        .onDisappear {
            // 更新沉浸式空间状态为已关闭
            appModel.immersiveSpaceState = .closed
            // 重置模型加载状态
            isModelLoaded = false
            modelEntity = nil
            glbScene = nil // 清除 GLB 场景
        }
        .onChange(of: appModel.selectedDream?.id) { oldValue, newValue in
            // 当选中的梦境改变时，重新加载模型
            if let dream = appModel.selectedDream,
               let modelURL = dream.modelURL {
                isModelLoaded = false
                glbScene = nil // 清除旧的 GLB 场景
                Task {
                    await loadDreamModelIfNeeded(url: modelURL)
                }
            }
        }
    }
    
    private func createImmersiveScene() async -> Entity {
        let rootEntity = Entity()
        
        // 添加环境光 - 符合 RealityKit 最佳实践
        let directionalLight = DirectionalLight()
        directionalLight.light.intensity = 1000
        directionalLight.light.color = .white
        directionalLight.position = [0, 2, 2]
        rootEntity.addChild(directionalLight)
        
        // 添加环境光（补充光照）
        let ambientLight = DirectionalLight()
        ambientLight.light.intensity = 500
        ambientLight.light.color = .init(red: 0.2, green: 0.5, blue: 0.9, alpha: 1.0)
        ambientLight.position = [0, -1, 0]
        rootEntity.addChild(ambientLight)

        // 如果有选中的梦境且已生成模型，加载3D模型
        // 支持所有格式：USDZ（推荐）、GLB（通过 SceneKit 转换）、以及其他格式
        if let dream = appModel.selectedDream,
           let modelURL = dream.modelURL {
            print("📦 Loading model for dream: \(dream.title)")
            print("📦 Model URL: \(modelURL)")
            print("📦 Model format: \(inferModelFormat(from: modelURL))")
            
            // 所有格式都通过统一的 loadDreamModel 方法加载
            // ModelLoader 会自动处理格式检测和转换：
            // - USDZ: 直接加载（最佳支持）
            // - GLB: 使用 SceneKit 加载并转换为 RealityKit Entity
            // - 其他格式: 尝试直接加载
            await loadDreamModel(url: modelURL, parent: rootEntity)
        } else {
            // 默认场景（占位符）
            print("⚠️ No model URL found, showing placeholder")
            await createDefaultScene(parent: rootEntity)
        }
        
        return rootEntity
    }
    
    private func loadDreamModelIfNeeded(url: String) async {
        guard !isModelLoaded else { return }
        isModelLoaded = true
        
        // 清除旧的模型实体
        if let oldEntity = modelEntity {
            oldEntity.removeFromParent()
            modelEntity = nil
        }
        
        // 重新加载场景以加载新模型
        // 注意：这里我们需要重新创建场景，因为 RealityView 的 update 闭包可能不够
        // 实际加载会在 createImmersiveScene 中进行
    }
    
    private func loadDreamModel(url: String, parent: Entity) async {
        do {
            print("📦 Loading 3D model from: \(url)")
            
            // 确保 URL 是 USDZ 格式
            let modelURL = url
            if !normalizedURLPath(modelURL).hasSuffix(".usdz") {
                print("⚠️ Model URL doesn't end with .usdz, attempting to load anyway")
            }
            
            let entity = try await ModelLoader.shared.loadModel(from: modelURL)
            
            // 设置初始位置和大小（在用户前方 1.5 米，适合 Vision Pro 交互）
            // 符合 visionOS HIG 的空间布局建议
            // 确保模型在正中心（X=0, Y=0）
            let centeredPosition: SIMD3<Float> = [0, 0, -1.5]
            entity.position = centeredPosition
            position = centeredPosition // 同步更新状态
            entity.scale = [scale, scale, scale]
            
            // 计算模型边界框，确保模型居中并添加碰撞体
            let bounds = entity.visualBounds(relativeTo: nil)
            if bounds.extents.x > 0 && bounds.extents.y > 0 && bounds.extents.z > 0 {
                // 获取模型中心点偏移
                let centerOffset = bounds.center
                // 调整位置，使模型视觉中心在原点
                entity.position = centeredPosition - centerOffset
                
                // 使用边界框大小作为碰撞体
                let size = bounds.extents
                let collisionShape = ShapeResource.generateBox(size: size)
                let collisionComponent = CollisionComponent(shapes: [collisionShape])
                entity.components.set(collisionComponent)
            } else {
                // 如果无法获取边界，使用默认大小
                let size: SIMD3<Float> = [2, 2, 2]
                let collisionShape = ShapeResource.generateBox(size: size)
                let collisionComponent = CollisionComponent(shapes: [collisionShape])
                entity.components.set(collisionComponent)
            }
            
            // 添加交互组件（用于 Vision Pro 的手势交互）
            // InputTargetComponent 允许实体接收输入事件
            let inputComponent = InputTargetComponent()
            entity.components.set(inputComponent)
            
            // 添加 HoverEffect 组件（视觉反馈）
            let hoverComponent = HoverEffectComponent()
            entity.components.set(hoverComponent)
            
            parent.addChild(entity)
            modelEntity = entity
            
            print("✅ Model loaded successfully")
            
            // 不自动旋转，让用户可以手动控制
        } catch {
            print("❌ Failed to load model: \(error.localizedDescription)")
            
            // 检查是否是格式不支持的错误，或者URL是GLB格式
            let isGLBFormat = normalizedURLPath(url).hasSuffix(".glb")
            if case ModelLoadError.unsupportedFormat(let format) = error {
                print("⚠️ Unsupported format: \(format)")
                await MainActor.run {
                    showGLBError = true
                    // 如果是 GLB 格式，自动打开窗口预览
                    if format.uppercased() == "GLB" {
                        openWindowPreview(for: url)
                    }
                }
            } else if isGLBFormat {
                // GLB格式加载失败，显示错误提示并自动打开窗口预览
                print("⚠️ GLB format loading failed, opening window preview")
                await MainActor.run {
                    showGLBError = true
                    openWindowPreview(for: url)
                }
            }
            
            // 如果加载失败，使用占位符
            await createDefaultScene(parent: parent)
        }
    }

    private func inferModelFormat(from url: String) -> String {
        let normalized = normalizedURLPath(url)
        if normalized.hasSuffix(".usdz") { return "USDZ" }
        if normalized.hasSuffix(".usd") { return "USD" }
        if normalized.hasSuffix(".glb") { return "GLB" }
        return "Unknown"
    }
    
    private func normalizedURLPath(_ url: String) -> String {
        let lowercased = url.lowercased()
        if let questionIndex = lowercased.firstIndex(of: "?") {
            return String(lowercased[..<questionIndex])
        }
        return lowercased
    }
    
    /// 打开窗口预览模式（用于 GLB 格式模型）
    private func openWindowPreview(for modelURL: String) {
        guard let dream = appModel.selectedDream else { return }
        
        appModel.previewModelURL = modelURL
        appModel.previewDreamTitle = dream.title
        appModel.showModelPreview = true
        
        print("🪟 Opening window preview for GLB model: \(modelURL.prefix(80))...")
    }
    
    /// 使用 ModelIO 加载 GLB 文件并转换为 RealityKit Entity
    private func loadGLBWithModelIO(url: String, parent: Entity) async {
        // 检查缓存
        let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        let modelCacheDir = cacheDir.appendingPathComponent("DreamModels", isDirectory: true)
        let cacheFileName = "\(url.hash).glb"
        let cacheURL = modelCacheDir.appendingPathComponent(cacheFileName)
        
        guard FileManager.default.fileExists(atPath: cacheURL.path) else {
            print("❌ GLB cache file not found")
            showGLBError = true
            await createDefaultScene(parent: parent)
            return
        }
        
        do {
            print("📦 Loading GLB with ModelIO...")
            
            // 使用 ModelIO 加载 GLB
            let asset = MDLAsset(url: cacheURL)
            guard asset.count > 0 else {
                throw NSError(domain: "ModelIO", code: -1, userInfo: [NSLocalizedDescriptionKey: "No objects in GLB file"])
            }
            
            // 创建一个容器实体来存放所有网格
            let containerEntity = Entity()
            
            // 遍历所有对象并转换为 RealityKit Entity
            // 注意：RealityKit 在 visionOS 上不支持直接从 MDLMesh 创建 MeshResource
            // 我们需要使用其他方法或接受限制
            print("⚠️ Found \(asset.count) objects in GLB, but RealityKit cannot directly load GLB format")
            print("⚠️ Please use USDZ format for best compatibility")
            
            // 如果无法转换，显示错误并使用占位符
            if containerEntity.children.isEmpty {
                print("⚠️ Cannot convert GLB to RealityKit format")
                showGLBError = true
                
                // 创建一个更明显的占位符
                let placeholder = createLargePlaceholderModel()
                placeholder.position = position
                parent.addChild(placeholder)
                modelEntity = placeholder
            } else {
                containerEntity.position = position
                parent.addChild(containerEntity)
                modelEntity = containerEntity
                print("✅ GLB converted successfully")
            }
            
        } catch {
            print("❌ Failed to load GLB with ModelIO: \(error.localizedDescription)")
            showGLBError = true
            await createDefaultScene(parent: parent)
        }
    }
    
    /// 创建大型占位符模型（更明显，确保居中）
    private func createLargePlaceholderModel() -> Entity {
        // 创建一个更大的、更明显的占位符
        // 使用球体，确保几何中心在原点
        let mesh = MeshResource.generateSphere(radius: 0.5)
        let material = SimpleMaterial(
            color: UIColor(red: 0.3, green: 0.6, blue: 1.0, alpha: 0.9), // 更亮的蓝色
            roughness: 0.2,
            isMetallic: true
        )
        let entity = ModelEntity(mesh: mesh, materials: [material])
        
        // 确保实体本身的位置在原点（相对于父实体）
        // 父实体会设置最终位置为 [0, 0, -1.5]
        entity.position = [0, 0, 0]
        
        // 添加缓慢旋转动画，让用户知道这是占位符
        let rotation = simd_quatf(angle: .pi * 2, axis: [0, 1, 0])
        entity.move(
            to: Transform(rotation: rotation),
            relativeTo: entity.parent,
            duration: 20,
            timingFunction: .linear
        )
        
        return entity
    }
    
    private func createDefaultScene(parent: Entity) async {
        // 创建大型占位符模型（更明显，确保居中）
        let placeholder = createLargePlaceholderModel()
        // 确保占位符在正中心位置（X=0, Y=0, Z=-1.5米）
        // 符合 visionOS HIG：模型应在用户前方 1-2 米，水平居中
        let centeredPosition: SIMD3<Float> = [0, 0, -1.5]
        placeholder.position = centeredPosition
        position = centeredPosition // 同步更新状态
        parent.addChild(placeholder)
        modelEntity = placeholder
        
        // 创建梦幻粒子效果
        let particles = ModelLoader.shared.createDreamParticles()
        parent.addChild(particles)
    }
}

#Preview(immersionStyle: .full) {
    ImmersiveView()
        .environment(AppModel())
}
