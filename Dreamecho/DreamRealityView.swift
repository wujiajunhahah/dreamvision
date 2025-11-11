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

        // 创建世界锚点，放置在用户前方1.4米处
        if let cameraTransform = content.cameraTransform {
            // 计算锚点位置：前方1.4米
            let translation = simd_float4x4(translation: [0, 0, -1.4])
            let anchorMatrix = cameraTransform.matrix * translation

            // 创建锚点实体
            let anchor = AnchorEntity(world: Transform(matrix: anchorMatrix))

            // 将模型添加到锚点
            anchor.addChild(modelEntity)

            // 添加到场景
            content.add(anchor)

            print("✅ 模型已放置在用户前方1.4米处")
        } else {
            // 备选方案：使用固定位置的锚点
            let anchor = AnchorEntity()
            anchor.addChild(modelEntity)
            content.add(anchor)
            print("⚠️ 使用固定锚点位置")
        }

        // 添加环境光
        setupLighting(content: content)
    }

    private func setupLighting(content: RealityViewContent) {
        // 环境光
        let ambientLight = Entity()
        var ambientComponent = AmbientLightComponent()
        ambientComponent.color = .white
        ambientComponent.intensity = 0.6
        ambientLight.components.set(ambientComponent)
        content.add(ambientLight)

        // 方向光
        let directionalLight = Entity()
        var directionalComponent = DirectionalLightComponent()
        directionalComponent.color = .white
        directionalComponent.intensity = 1000
        directionalComponent.shadow = DirectionalLightComponent.Shadow()
        directionalLight.components.set(directionalComponent)

        // 设置光源位置和方向
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
            simd_quatf(angle: rotation.x * rotationSpeed, axis: [0, 1, 0]),
            currentRotation
        )

        modelEntity.transform.rotation = newRotation
    }

    private func resetModelPosition() {
        guard let modelEntity = modelEntity else { return }

        // 重置到初始位置和大小
        modelEntity.transform.scale = [1, 1, 1]
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
        let targetScaleVector = [targetScale, targetScale, targetScale]

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

            // 首先尝试从Bundle加载.reality文件（构建期转换的文件）
            if let bundleURL = Bundle.main.url(forResource: "dreamecho_model", withExtension: "reality") {
                print("📦 从Bundle加载.reality文件")
                let loadedEntity = try await Entity(contentsOf: bundleURL)

                await MainActor.run {
                    self.entity = loadedEntity
                    self.modelEntity = findModelEntity(in: loadedEntity)
                    self.isLoading = false
                }

                print("✅ .reality文件加载成功")
                return
            }

            // 备选方案：尝试从Bundle加载USDZ文件
            if let bundleURL = Bundle.main.url(forResource: "dreamecho_model", withExtension: "usdz") {
                print("📦 从Bundle加载USDZ文件")
                let loadedEntity = try await Entity(contentsOf: bundleURL)

                await MainActor.run {
                    self.entity = loadedEntity
                    self.modelEntity = findModelEntity(in: loadedEntity)
                    self.isLoading = false
                }

                print("✅ USDZ文件加载成功")
                return
            }

            // 最后备选：从网络下载GLB文件
            print("🌐 从网络下载GLB文件")
            guard let url = URL(string: modelURL) else {
                throw ModelLoadError.invalidURL
            }

            let (data, response) = try await URLSession.shared.data(from: url)

            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                throw ModelLoadError.downloadFailed
            }

            print("✅ GLB文件下载成功: \(data.count) bytes")

            // 保存到临时文件
            let tempURL = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)
                .appendingPathExtension("glb")

            try data.write(to: tempURL)

            // 加载GLB文件
            let loadedEntity = try await Entity(contentsOf: tempURL)

            await MainActor.run {
                self.entity = loadedEntity
                self.modelEntity = findModelEntity(in: loadedEntity)
                self.isLoading = false
            }

            print("✅ GLB文件加载成功")

            // 清理临时文件
            try? FileManager.default.removeItem(at: tempURL)

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

enum ModelLoadError: LocalizedError {
    case invalidURL
    case downloadFailed
    case corruptedFile

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "无效的模型文件URL"
        case .downloadFailed:
            return "下载模型文件失败，请检查网络连接"
        case .corruptedFile:
            return "模型文件已损坏或格式不支持"
        }
    }
}

#Preview(windowStyle: .automatic) {
    DreamRealityView(
        modelURL: "https://example.com/model.glb",
        dreamTitle: "测试梦境"
    )
}