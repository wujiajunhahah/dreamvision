//
//  ModelPreviewView.swift
//  Dreamecho
//
//  Created by sztu on 2025/11/9.
//

import SwiftUI
import SceneKit
import ModelIO

/// 窗口预览视图 - 用于 GLB 格式模型的备选预览方案
struct ModelPreviewView: View {
    let modelURL: String
    let dreamTitle: String
    @Environment(\.dismiss) private var dismiss
    @State private var scene: SCNScene?
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var cameraNode: SCNNode?
    @State private var modelNode: SCNNode?
    
    var body: some View {
        NavigationStack {
            ZStack {
                // 背景
                Color.black.opacity(0.1)
                    .ignoresSafeArea()
                
                if isLoading {
                    // 加载指示器
                    VStack(spacing: 20) {
                        ProgressView()
                            .scaleEffect(1.5)
                        Text("Loading model...")
                            .font(.system(size: 18))
                            .foregroundStyle(.secondary)
                    }
                } else if let errorMessage = errorMessage {
                    // 错误信息
                    VStack(spacing: 24) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 64))
                            .foregroundStyle(.orange)
                        
                        Text("Failed to Load Model")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundStyle(.primary)
                        
                        Text(errorMessage)
                            .font(.system(size: 18))
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                    }
                } else if let scene = scene {
                    // SceneKit 视图
                    SceneKitView(scene: scene, cameraNode: cameraNode, modelNode: modelNode)
                        .edgesIgnoringSafeArea(.all)
                }
            }
            .navigationTitle(dreamTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
        .task {
            await loadModel()
        }
    }
    
    private func loadModel() async {
        isLoading = true
        errorMessage = nil
        
        do {
            // 下载模型文件
            guard let url = URL(string: modelURL) else {
                throw ModelLoadError.invalidURL
            }
            
            print("📥 Downloading model for preview: \(modelURL)")
            let (data, response) = try await URLSession.shared.data(from: url)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                throw ModelLoadError.downloadFailed
            }
            
            print("✅ Model downloaded: \(data.count) bytes")
            
            // 保存到临时文件
            let tempURL = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)
                .appendingPathExtension("glb")
            
            try data.write(to: tempURL)
            print("💾 Saved to temp file: \(tempURL.path)")
            
            // 添加文件验证和调试信息
            let fileManager = FileManager.default
            if fileManager.fileExists(atPath: tempURL.path) {
                if let attributes = try? fileManager.attributesOfItem(atPath: tempURL.path),
                   let fileSize = attributes[.size] as? Int64 {
                    print("📁 Preview file exists: \(tempURL.path)")
                    print("📏 Preview file size: \(fileSize) bytes (\(Double(fileSize) / 1024 / 1024) MB)")
                    
                    // 读取文件头部信息
                    if let fileHandle = FileHandle(forReadingAtPath: tempURL.path) {
                        defer { fileHandle.closeFile() }
                        fileHandle.seek(toFileOffset: 0)
                        let headerData = fileHandle.readData(ofLength: 12)
                        if headerData.count >= 4 {
                            let magic = String(data: headerData.prefix(4), encoding: .ascii) ?? "unknown"
                            print("🔍 Preview file magic: \(magic)")
                            if magic == "glTF" {
                                print("✅ Valid GLB file header detected in preview")
                            } else {
                                print("⚠️ Unexpected preview file header: \(magic)")
                            }
                        }
                    }
                }
            } else {
                print("❌ Preview file does not exist at: \(tempURL.path)")
            }
            
            var scnScene: SCNScene?
            
            // 方法 1: 尝试使用 SCNScene 直接加载
            print("🔧 Method 1: Trying SCNScene(url:) directly...")
            if let scene = try? SCNScene(url: tempURL, options: nil) {
                print("✅ Method 1 succeeded: SCNScene loaded directly")
                scnScene = scene
            } else {
                print("❌ Method 1 failed: SCNScene direct load failed")
                
                // 方法 2: 尝试使用 SCNSceneSource 加载
                print("🔧 Method 2: Trying SCNSceneSource...")
                if let sceneSource = SCNSceneSource(url: tempURL, options: nil) {
                    print("📊 SCNSceneSource created successfully")
                    if let scene = sceneSource.scene(options: nil) {
                        print("✅ Method 2 succeeded: SCNSceneSource loaded scene")
                        scnScene = scene
                    } else {
                        print("❌ Method 2 failed: SCNSceneSource.scene() returned nil")
                        
                        // 尝试使用不同的选项
                        let options: [SCNSceneSource.LoadingOption: Any] = [
                            .createNormalsIfAbsent: true,
                            .checkConsistency: false
                        ]
                        if let scene = sceneSource.scene(options: options) {
                            print("✅ Method 2 (with options) succeeded")
                            scnScene = scene
                        } else {
                            print("❌ Method 2 (with options) also failed")
                        }
                    }
                } else {
                    print("❌ Method 2 failed: Could not create SCNSceneSource")
                }
            }
            
            // 如果所有方法都失败，尝试使用 ModelIO
            if scnScene == nil {
                print("🔧 Method 3: Trying ModelIO MDLAsset...")
                let asset = MDLAsset(url: tempURL)
                
                print("📊 Preview MDLAsset created, object count: \(asset.count)")
                
                if asset.count > 0 {
                    print("✅ Method 3: MDLAsset has \(asset.count) objects")
                    
                    // 尝试将 MDLAsset 转换为 SCNScene
                    let newScene = SCNScene()
                    
                    // 添加环境光
                    let ambientLight = SCNLight()
                    ambientLight.type = .ambient
                    ambientLight.color = UIColor.white.withAlphaComponent(0.6)
                    let ambientNode = SCNNode()
                    ambientNode.light = ambientLight
                    newScene.rootNode.addChildNode(ambientNode)
                    
                    // 添加方向光
                    let directionalLight = SCNLight()
                    directionalLight.type = .directional
                    directionalLight.color = UIColor.white
                    directionalLight.intensity = 1000
                    let directionalNode = SCNNode()
                    directionalNode.light = directionalLight
                    directionalNode.position = SCNVector3(0, 5, 5)
                    directionalNode.look(at: SCNVector3(0, 0, 0))
                    newScene.rootNode.addChildNode(directionalNode)
                    
                    // 尝试从 MDLAsset 创建 SCNNode
                    // 注意：ModelIO 到 SceneKit 的转换在 visionOS 上可能不可用
                    // 如果 MDLAsset 有对象但无法转换，我们至少显示一个占位符
                    for i in 0..<asset.count {
                        let mdlObject = asset.object(at: i)
                        print("📦 Processing MDLObject \(i): \(type(of: mdlObject)) - \(mdlObject.name)")
                        
                        if let mdlMesh = mdlObject as? MDLMesh {
                            // 尝试使用 SCNScene 的 MDLAsset 支持
                            // 注意：直接转换可能不可用，所以我们创建一个占位符节点
                            let placeholderGeometry = SCNBox(width: 1, height: 1, length: 1, chamferRadius: 0.1)
                            let scnMaterial = SCNMaterial()
                            
                            // 尝试从材质获取颜色
                            if let submesh = mdlMesh.submeshes?.firstObject as? MDLSubmesh,
                               let material = submesh.material,
                               let baseColor = material.property(with: .baseColor) {
                                let color = baseColor.float3Value
                                scnMaterial.diffuse.contents = UIColor(
                                    red: CGFloat(color.x),
                                    green: CGFloat(color.y),
                                    blue: CGFloat(color.z),
                                    alpha: 1.0
                                )
                            } else {
                                scnMaterial.diffuse.contents = UIColor.blue.withAlphaComponent(0.7)
                            }
                            
                            placeholderGeometry.materials = [scnMaterial]
                            let node = SCNNode(geometry: placeholderGeometry)
                            node.name = mdlMesh.name.isEmpty ? "Mesh_\(i)" : mdlMesh.name
                            newScene.rootNode.addChildNode(node)
                            print("✅ Created placeholder SCNNode for MDLMesh \(i): \(node.name ?? "unnamed")")
                        }
                    }
                    
                    if !newScene.rootNode.childNodes.isEmpty {
                        scnScene = newScene
                        print("✅ Method 3 succeeded: Created scene from MDLAsset")
                    } else {
                        print("❌ Method 3 failed: No nodes created from MDLAsset")
                    }
                } else {
                    print("❌ Method 3 failed: MDLAsset contains no objects")
                    print("💡 This is a known limitation: ModelIO on visionOS may not fully support GLB parsing")
                    print("💡 File path: \(tempURL.path)")
                    print("💡 File URL: \(tempURL.absoluteString)")
                }
            }
            
            // 如果所有方法都失败，显示错误
            guard let finalScene = scnScene else {
                throw NSError(
                    domain: "ModelPreview",
                    code: -1,
                    userInfo: [NSLocalizedDescriptionKey: "无法加载 GLB 模型。visionOS 上的 SceneKit 和 ModelIO 对 GLB 格式的支持有限。建议联系 Tripo3D API 申请 USDZ 格式支持。"]
                )
            }
            
            print("✅ GLB model loaded successfully using one of the methods")
            
            // 添加环境光（如果场景中没有）
            if finalScene.rootNode.childNodes.filter({ $0.light != nil }).isEmpty {
                let ambientLight = SCNLight()
                ambientLight.type = .ambient
                ambientLight.color = UIColor.white.withAlphaComponent(0.6)
                let ambientNode = SCNNode()
                ambientNode.light = ambientLight
                finalScene.rootNode.addChildNode(ambientNode)
                
                let directionalLight = SCNLight()
                directionalLight.type = .directional
                directionalLight.color = UIColor.white
                directionalLight.intensity = 1000
                let directionalNode = SCNNode()
                directionalNode.light = directionalLight
                directionalNode.position = SCNVector3(0, 5, 5)
                directionalNode.look(at: SCNVector3(0, 0, 0))
                finalScene.rootNode.addChildNode(directionalNode)
            }
            
            // 查找第一个模型节点
            finalScene.rootNode.enumerateChildNodes { node, _ in
                if node.geometry != nil && modelNode == nil {
                    modelNode = node
                }
            }
            
            // 创建相机（如果场景中没有）
            if finalScene.rootNode.childNodes.filter({ $0.camera != nil }).isEmpty {
                let camera = SCNCamera()
                camera.fieldOfView = 60
                let cameraNode = SCNNode()
                cameraNode.camera = camera
                cameraNode.position = SCNVector3(0, 0, 5)
                finalScene.rootNode.addChildNode(cameraNode)
                self.cameraNode = cameraNode
            } else {
                // 使用现有的相机
                finalScene.rootNode.enumerateChildNodes { node, _ in
                    if node.camera != nil && cameraNode == nil {
                        cameraNode = node
                    }
                }
            }
            
            await MainActor.run {
                self.scene = finalScene
                self.isLoading = false
            }
            
            // 清理临时文件
            try? FileManager.default.removeItem(at: tempURL)
            
        } catch {
            print("❌ Failed to load model for preview: \(error.localizedDescription)")
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
        }
    }
}

/// SceneKit 视图包装器
struct SceneKitView: UIViewRepresentable {
    let scene: SCNScene
    let cameraNode: SCNNode?
    let modelNode: SCNNode?
    
    func makeUIView(context: Context) -> SCNView {
        let scnView = SCNView()
        scnView.scene = scene
        scnView.allowsCameraControl = true
        scnView.autoenablesDefaultLighting = false
        scnView.backgroundColor = UIColor.black.withAlphaComponent(0.05)
        scnView.antialiasingMode = .multisampling4X
        
        // 添加旋转动画
        if let modelNode = modelNode {
            let rotation = SCNAction.rotateBy(x: 0, y: CGFloat.pi * 2, z: 0, duration: 20)
            let repeatRotation = SCNAction.repeatForever(rotation)
            modelNode.runAction(repeatRotation)
        }
        
        return scnView
    }
    
    func updateUIView(_ uiView: SCNView, context: Context) {
        // 更新视图
    }
}

