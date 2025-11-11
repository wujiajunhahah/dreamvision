//
//  DreamRealityView.swift
//  Dreamecho
//
//  Created by AI on 2025/11/11.
//

import SwiftUI
import RealityKit
import RealityKitContent

struct DreamRealityView: View {
    let modelURL: String
    let dreamTitle: String
    @Environment(\.dismiss) private var dismiss
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var entity: Entity?
    @State private var modelEntity: ModelEntity?

    var body: some View {
        NavigationStack {
            ZStack {
                // 半透明背景
                Color.black.opacity(0.1)
                    .ignoresSafeArea()

                if isLoading {
                    // 加载指示器
                    VStack(spacing: 24) {
                        ProgressView()
                            .scaleEffect(1.5)

                        Text("正在加载3D模型...")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundStyle(.secondary)

                        Text("梦境: \(dreamTitle)")
                            .font(.system(size: 16))
                            .foregroundStyle(.tertiary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }
                } else if let errorMessage = errorMessage {
                    // 错误状态
                    VStack(spacing: 24) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 64))
                            .foregroundStyle(.orange)

                        Text("模型加载失败")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundStyle(.primary)

                        Text(errorMessage)
                            .font(.system(size: 18))
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)

                        Button("重试") {
                            Task {
                                await loadModel()
                            }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                } else {
                    // RealityKit 3D视图
                    if let modelEntity = modelEntity {
                        RealityView { content in
                            await setupScene(content: content)
                        }
                        .edgesIgnoringSafeArea(.all)
                        .gesture(
                            DragGesture()
                                .targetedToEntity(modelEntity)
                                .onChanged { value in
                                    handleModelRotation(value: value)
                                }
                        )
                    } else {
                        // 如果模型实体未加载，显示加载中
                        VStack(spacing: 24) {
                            ProgressView()
                                .scaleEffect(1.5)
                            Text("正在加载3D模型...")
                                .font(.system(size: 18))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle(dreamTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") {
                        dismiss()
                    }
                }

                if modelEntity != nil {
                    ToolbarItem(placement: .primaryAction) {
                        Menu {
                            Button("重置位置") {
                                resetModelPosition()
                            }
                            Button("自动调整") {
                                autoAdjustModel()
                            }
                        } label: {
                            Image(systemName: "slider.horizontal.3")
                        }
                    }
                }
            }
        }
        .task {
            await loadModel()
        }
    }

    @MainActor
    private func setupScene(content: RealityViewContent) async {
        guard let modelEntity = modelEntity else { return }

        // 原生实现：使用固定位置锚点（visionOS窗口视图的标准方式）
        // 在visionOS中，窗口视图使用固定世界坐标系统
        // 位置 [0, 0, -1.4] 表示在用户前方约1.4米处（原生RealityKit方式）
        let anchor = AnchorEntity()
        anchor.position = SIMD3<Float>(0, 0, -1.4) // 放置在用户前方1.4米处
        anchor.addChild(modelEntity)
        content.add(anchor)
        
        print("✅ 模型已使用原生固定位置放置在用户前方1.4米处")

        // 添加环境光
        setupLighting(content: content)
    }
    

    private func setupLighting(content: RealityViewContent) {
        // 方向光（visionOS RealityKit 使用 DirectionalLight）
        let directionalLight = DirectionalLight()
        directionalLight.light.intensity = 1000
        directionalLight.position = [0, 5, 5]
        directionalLight.look(at: [0, 0, 0], from: directionalLight.position, relativeTo: nil)
        content.add(directionalLight)
    }

    private func handleModelRotation(value: EntityTargetValue<DragGesture.Value>) {
        guard let modelEntity = modelEntity else { return }

        let rotation = value.gestureValue.translation
        let rotationSpeed: Float = 0.01

        // 基于拖拽距离旋转模型
        let currentRotation = modelEntity.transform.rotation
        let newRotation = simd_mul(
            simd_quatf(angle: Float(rotation.width) * rotationSpeed, axis: [0, 1, 0]),
            currentRotation
        )

        modelEntity.transform.rotation = newRotation
    }

    private func resetModelPosition() {
        guard let modelEntity = modelEntity else { return }

        // 重置到初始位置和大小
        modelEntity.transform.scale = SIMD3<Float>(1, 1, 1)
        modelEntity.transform.rotation = simd_quatf(angle: 0, axis: [0, 1, 0])

        print("🔄 模型位置已重置")
    }

    private func autoAdjustModel() {
        guard let modelEntity = modelEntity else { return }

        // 自动调整模型大小以适应视野
        let bounds = modelEntity.visualBounds(relativeTo: nil)
        let size = bounds.extents

        // 计算合适的缩放比例（目标大小约为0.5米）
        let maxDimension = max(size.x, size.y, size.z)
        let targetScale: Float = 0.5 / max(maxDimension, 0.1)

        // 平滑缩放动画
        let currentScale = modelEntity.transform.scale
        let targetScaleVector = SIMD3<Float>(targetScale, targetScale, targetScale)

        // 创建缩放动画
        let scaleAnimation = FromToByAnimation<Transform>(
            name: "autoScale",
            from: Transform(scale: currentScale, rotation: modelEntity.transform.rotation, translation: modelEntity.transform.translation),
            to: Transform(scale: targetScaleVector, rotation: modelEntity.transform.rotation, translation: modelEntity.transform.translation),
            duration: 1.0,
            timing: .easeInOut,
            bindTarget: .transform
        )

        let animationResource = try! AnimationResource.generate(with: scaleAnimation)
        modelEntity.playAnimation(animationResource)

        print("🎯 模型已自动调整大小: \(targetScale)")
    }

    private func loadModel() async {
        isLoading = true
        errorMessage = nil

        do {
            print("🎨 开始加载3D模型: \(modelURL)")

            // 优先尝试从 RealityKitContent 包加载 .reality 文件（Reality Composer Pro 优化后的格式）
            // 这是构建期通过 realitytool 转换的优化格式，性能最佳
            if let realityURL = realityKitContentBundle.url(forResource: "dreamecho_model", withExtension: "reality") {
                print("📦 从 RealityKitContent 包加载 .reality 文件（Reality Composer Pro 优化格式）")
                let loadedEntity = try await Entity(contentsOf: realityURL)
                
                await MainActor.run {
                    self.entity = loadedEntity
                    self.modelEntity = findModelEntity(in: loadedEntity)
                    self.isLoading = false
                }
                
                print("✅ .reality 文件加载成功（Reality Composer Pro 优化格式）")
                return
            }
            
            // 备选方案：从主 Bundle 加载 .reality 文件
            if let bundleURL = Bundle.main.url(forResource: "dreamecho_model", withExtension: "reality") {
                print("📦 从主 Bundle 加载 .reality 文件")
                let loadedEntity = try await Entity(contentsOf: bundleURL)
                
                await MainActor.run {
                    self.entity = loadedEntity
                    self.modelEntity = findModelEntity(in: loadedEntity)
                    self.isLoading = false
                }
                
                print("✅ .reality 文件加载成功")
                return
            }

            // 最后备选：运行时下载USDZ（原生实现）
            print("🌐 运行时下载USDZ文件（原生实现）")
            let loadedEntity = try await ModelLoader.shared.loadModel(from: modelURL)

            await MainActor.run {
                self.entity = loadedEntity
                self.modelEntity = findModelEntity(in: loadedEntity)
                self.isLoading = false
            }

            print("✅ 3D模型加载成功（运行时USDZ格式）")

        } catch {
            print("❌ 模型加载失败: \(error.localizedDescription)")

            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
        }
    }

    private func findModelEntity(in entity: Entity) -> ModelEntity? {
        // 递归查找ModelEntity
        if let modelEntity = entity as? ModelEntity {
            return modelEntity
        }

        for child in entity.children {
            if let found = findModelEntity(in: child) {
                return found
            }
        }

        return nil
    }
}

#Preview(windowStyle: .automatic) {
    DreamRealityView(
        modelURL: "https://example.com/model.glb",
        dreamTitle: "测试梦境"
    )
}