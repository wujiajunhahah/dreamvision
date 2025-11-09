//
//  ModelLoader.swift
//  Dreamecho
//
//  Created by sztu on 2025/11/9.
//

import Foundation
import RealityKit
import UIKit
import ModelIO
import SceneKit

/// 3D模型加载器 - 支持缓存机制
@MainActor
class ModelLoader {
    static let shared = ModelLoader()
    
    // 模型缓存：URL -> 本地文件路径
    private var modelCache: [String: URL] = [:]
    
    // 缓存目录
    private var cacheDirectory: URL {
        let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        let modelCacheDir = cacheDir.appendingPathComponent("DreamModels", isDirectory: true)
        
        // 确保缓存目录存在
        try? FileManager.default.createDirectory(at: modelCacheDir, withIntermediateDirectories: true)
        
        return modelCacheDir
    }
    
    private init() {
        // 加载已缓存的模型列表
        loadCacheIndex()
    }
    
    /// 将 URL 转为小写并移除查询参数，方便判断后缀格式
    private func normalizedURLPath(_ urlString: String) -> String {
        let lowercased = urlString.lowercased()
        if let questionIndex = lowercased.firstIndex(of: "?") {
            return String(lowercased[..<questionIndex])
        }
        return lowercased
    }
    
    /// 从缓存索引加载已缓存的模型
    private func loadCacheIndex() {
        let indexURL = cacheDirectory.appendingPathComponent("cache_index.json")
        guard let data = try? Data(contentsOf: indexURL),
              let index = try? JSONDecoder().decode([String: String].self, from: data) else {
            return
        }
        
        // 恢复缓存映射
        for (urlString, fileName) in index {
            let fileURL = cacheDirectory.appendingPathComponent(fileName)
            if FileManager.default.fileExists(atPath: fileURL.path) {
                modelCache[urlString] = fileURL
            }
        }
        
        print("📦 Loaded \(modelCache.count) cached models")
    }
    
    /// 保存缓存索引
    private func saveCacheIndex() {
        let indexURL = cacheDirectory.appendingPathComponent("cache_index.json")
        var index: [String: String] = [:]
        
        for (urlString, fileURL) in modelCache {
            index[urlString] = fileURL.lastPathComponent
        }
        
        if let data = try? JSONEncoder().encode(index) {
            try? data.write(to: indexURL)
        }
    }
    
    /// 从URL加载3D模型（支持缓存，避免重复下载）
    func loadModel(from urlString: String) async throws -> Entity {
        guard let url = URL(string: urlString) else {
            throw ModelLoadError.invalidURL
        }
        
        // 检查缓存
        if let cachedURL = modelCache[urlString],
           FileManager.default.fileExists(atPath: cachedURL.path) {
            print("📦 Loading model from cache: \(cachedURL.lastPathComponent)")
            
            // 检测缓存文件的格式
            let cachedExtension = cachedURL.pathExtension.lowercased()
            print("📦 Cached file format: \(cachedExtension)")
            
            // 尝试加载缓存文件（无论格式，因为格式检测可能错误）
            do {
                let entity = try await Entity(contentsOf: cachedURL)
                print("✅ Model loaded from cache successfully (format: \(cachedExtension))")
                
                // 如果格式不是 USDZ，给出警告但允许继续
                if cachedExtension != "usdz" {
                    print("⚠️ Warning: Cached file format is \(cachedExtension), but loaded successfully")
                    print("💡 File may have been misidentified - USDZ is the recommended format")
                }
                
                return entity
            } catch {
                // 如果加载失败且格式是 GLB，拒绝并删除
                if cachedExtension == "glb" {
                    print("❌ Cached GLB file failed to load: \(error.localizedDescription)")
                    print("❌ Rejecting cached GLB file - only USDZ format is supported")
                    print("💡 GLB files should be converted to USDZ by the API layer")
                    // 删除 GLB 缓存文件
                    try? FileManager.default.removeItem(at: cachedURL)
                    modelCache.removeValue(forKey: urlString)
                    saveCacheIndex()
                    throw ModelLoadError.unsupportedFormat("GLB")
                } else {
                    print("⚠️ Cached model failed to load, re-downloading: \(error.localizedDescription)")
                    // 缓存文件损坏，删除并重新下载
                    try? FileManager.default.removeItem(at: cachedURL)
                    modelCache.removeValue(forKey: urlString)
                    saveCacheIndex()
                }
            }
        }
        
        // 检查是否是本地文件 URL
        if url.isFileURL {
            print("📁 Loading local file: \(url.path)")
            let data = try Data(contentsOf: url)
            print("✅ Local file loaded: \(data.count) bytes")
            
            // 从文件扩展名确定格式
            let fileExtension = url.pathExtension.lowercased()
            let cacheFileName = "\(urlString.hash).\(fileExtension)"
            let cacheURL = cacheDirectory.appendingPathComponent(cacheFileName)
            
            // 保存到缓存（即使已经是本地文件，也缓存以便统一处理）
            try data.write(to: cacheURL)
            modelCache[urlString] = cacheURL
            saveCacheIndex()
            
            print("💾 Local file cached to: \(cacheURL.path) (format: \(fileExtension))")
            
            // 直接使用下面的加载逻辑（跳转到加载部分）
            // 设置变量以便下面的代码可以使用
            let finalCacheURL = cacheURL
            let finalFileExtension = fileExtension
            
            // 使用RealityKit加载模型
            do {
                // 只接受 USDZ 格式
                if finalFileExtension == "usdz" {
                    print("📦 Loading USDZ format (best support for visionOS)")
                    let entity = try await Entity(contentsOf: finalCacheURL)
                    print("✅ USDZ model loaded successfully")
                    print("💡 USDZ is the recommended format for visionOS immersive experiences")
                    return entity
                } else if finalFileExtension == "glb" {
                    // 拒绝 GLB 格式
                    print("❌ Rejecting GLB format - only USDZ format is supported")
                    print("💡 Please regenerate the model to get USDZ format")
                    // 删除 GLB 文件
                    try? FileManager.default.removeItem(at: finalCacheURL)
                    modelCache.removeValue(forKey: urlString)
                    saveCacheIndex()
                    throw ModelLoadError.unsupportedFormat("GLB")
                } else {
                    // 其他格式也拒绝
                    print("❌ Rejecting unsupported format: \(finalFileExtension)")
                    print("❌ Only USDZ format is supported for visionOS")
                    // 删除不支持格式的文件
                    try? FileManager.default.removeItem(at: finalCacheURL)
                    modelCache.removeValue(forKey: urlString)
                    saveCacheIndex()
                    throw ModelLoadError.unsupportedFormat(finalFileExtension)
                }
                
            } catch {
                print("❌ Failed to load model: \(error.localizedDescription)")
                print("❌ Error type: \(type(of: error))")
                
                // 加载失败，不删除本地测试文件
                if !finalCacheURL.path.contains("test_model") {
                    try? FileManager.default.removeItem(at: finalCacheURL)
                    modelCache.removeValue(forKey: urlString)
                    saveCacheIndex()
                }
                throw ModelLoadError.invalidModel
            }
        }
        
        // 缓存未命中，下载模型
        print("📥 Downloading model from: \(urlString)")
        
        let (data, response) = try await URLSession.shared.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw ModelLoadError.downloadFailed
        }
        
        print("✅ Model downloaded: \(data.count) bytes")
        
        // 从多个来源确定文件格式（优先级：URL后缀 > Content-Type > 默认 USDZ）
        let fileExtension: String
        
        // 1. 优先从 URL 后缀判断
        let urlLower = urlString.lowercased()
        let normalizedURL = normalizedURLPath(urlString)
        if normalizedURL.hasSuffix(".usdz") || urlLower.contains(".usdz") {
            fileExtension = "usdz"
            print("📦 Format detected from URL: USDZ")
        } else if normalizedURL.hasSuffix(".glb") || urlLower.contains(".glb") {
            // 如果明确是 GLB，先下载，但会在加载时拒绝
            fileExtension = "glb"
            print("⚠️ Format detected from URL: GLB (will be rejected)")
        } else {
            // 2. 尝试从 Content-Type 判断
            if let contentType = httpResponse.value(forHTTPHeaderField: "Content-Type")?.lowercased() {
                if contentType.contains("usdz") || contentType.contains("model/vnd.usdz") {
                    fileExtension = "usdz"
                    print("📦 Format detected from Content-Type: USDZ")
                } else if contentType.contains("glb") || contentType.contains("model/gltf-binary") {
                    fileExtension = "glb"
                    print("⚠️ Format detected from Content-Type: GLB (will be rejected)")
                } else {
                    // 3. 默认尝试 USDZ（visionOS 推荐格式）
                    fileExtension = "usdz"
                    print("⚠️ Format not detected, defaulting to USDZ (will verify on load)")
                }
            } else {
                // 4. 如果都无法确定，默认尝试 USDZ
                fileExtension = "usdz"
                print("⚠️ Format not detected, defaulting to USDZ (will verify on load)")
            }
        }
        
        // 生成缓存文件名（使用 URL 的哈希值）
        let cacheFileName = "\(urlString.hash).\(fileExtension)"
        let cacheURL = cacheDirectory.appendingPathComponent(cacheFileName)
        
        // 保存到缓存
        try data.write(to: cacheURL)
        modelCache[urlString] = cacheURL
        saveCacheIndex()
        
        print("💾 Model cached to: \(cacheURL.path) (format: \(fileExtension))")
        
        // 使用RealityKit加载模型
        do {
            // 优先尝试 USDZ 格式
            if fileExtension == "usdz" {
                print("📦 Loading USDZ format (best support for visionOS)")
                let entity = try await Entity(contentsOf: cacheURL)
                print("✅ USDZ model loaded successfully")
                print("💡 USDZ is the recommended format for visionOS immersive experiences")
                return entity
            } else if fileExtension == "glb" {
                // GLB 格式应该已经在 API 层转换为 USDZ
                // 如果这里收到 GLB，说明转换失败或格式检测错误
                // 尝试作为 USDZ 加载（可能格式检测错误）
                print("⚠️ Format detected as GLB, but attempting to load as USDZ (format detection may be incorrect)")
                do {
                    let entity = try await Entity(contentsOf: cacheURL)
                    print("✅ File loaded successfully (was detected as GLB but loaded as USDZ)")
                    return entity
                } catch {
                    print("❌ Failed to load file as USDZ: \(error.localizedDescription)")
                    print("❌ Rejecting GLB format - only USDZ format is supported")
                    print("💡 GLB files should be converted to USDZ by the API layer")
                    // 删除 GLB 文件
                    try? FileManager.default.removeItem(at: cacheURL)
                    modelCache.removeValue(forKey: urlString)
                    saveCacheIndex()
                    throw ModelLoadError.unsupportedFormat("GLB")
                }
            } else {
                // 其他格式：尝试作为 USDZ 加载（可能格式检测错误）
                print("⚠️ Format detected as \(fileExtension), attempting to load as USDZ...")
                do {
                    let entity = try await Entity(contentsOf: cacheURL)
                    print("✅ File loaded successfully (was detected as \(fileExtension) but loaded as USDZ)")
                    return entity
                } catch {
                    print("❌ Failed to load file as USDZ: \(error.localizedDescription)")
                    print("❌ Rejecting unsupported format: \(fileExtension)")
                    print("❌ Only USDZ format is supported for visionOS")
                    // 删除不支持格式的文件
                    try? FileManager.default.removeItem(at: cacheURL)
                    modelCache.removeValue(forKey: urlString)
                    saveCacheIndex()
                    throw ModelLoadError.unsupportedFormat(fileExtension)
                }
            }
            
        } catch {
            print("❌ Failed to load model: \(error.localizedDescription)")
            print("❌ Error type: \(type(of: error))")
            
            // 如果是 GLB 且直接加载失败，已经在上面处理了
            // 这里不需要重试，因为 GLB 的处理逻辑已经在上面
            
            // 加载失败，删除缓存文件（如果是网络下载的）
            if !cacheURL.path.contains("test_model") { // 保留测试文件
                try? FileManager.default.removeItem(at: cacheURL)
            }
            throw ModelLoadError.invalidModel
        }
    }
    
    /// 清除所有缓存
    func clearCache() {
        for (_, fileURL) in modelCache {
            try? FileManager.default.removeItem(at: fileURL)
        }
        modelCache.removeAll()
        
        let indexURL = cacheDirectory.appendingPathComponent("cache_index.json")
        try? FileManager.default.removeItem(at: indexURL)
        
        print("🗑️ Model cache cleared")
    }
    
    /// 获取缓存大小（字节）
    func getCacheSize() -> Int64 {
        var totalSize: Int64 = 0
        for (_, fileURL) in modelCache {
            if let attributes = try? FileManager.default.attributesOfItem(atPath: fileURL.path),
               let size = attributes[.size] as? Int64 {
                totalSize += size
            }
        }
        return totalSize
    }
    
    /// 创建占位符模型（当模型未加载时使用）
    func createPlaceholderModel() -> Entity {
        // 创建一个简单的几何体作为占位符
        let mesh = MeshResource.generateSphere(radius: 0.5)
        let material = SimpleMaterial(
            color: UIColor(
                red: 0.2,
                green: 0.5,
                blue: 0.9,
                alpha: 0.8
            ),
            roughness: 0.3,
            isMetallic: true
        )
        let entity = ModelEntity(mesh: mesh, materials: [material])
        
        // 添加旋转动画
        let rotation = simd_quatf(angle: .pi * 2, axis: [0, 1, 0])
        entity.move(
            to: Transform(rotation: rotation),
            relativeTo: entity.parent,
            duration: 10,
            timingFunction: .linear
        )
        
        return entity
    }
    
    /// 创建梦幻粒子效果
    func createDreamParticles() -> Entity {
        let entity = Entity()
        
        // 创建多个发光粒子
        for i in 0..<50 {
            let particle = createParticle()
            let angle = Float(i) * 2 * .pi / 50
            let radius: Float = 2.0
            particle.position = [
                cos(angle) * radius,
                sin(angle * 2) * 0.5,
                sin(angle) * radius
            ]
            entity.addChild(particle)
        }
        
        return entity
    }
    
    private func createParticle() -> Entity {
        let mesh = MeshResource.generateSphere(radius: 0.05)
        let material = SimpleMaterial(
            color: UIColor(
                red: CGFloat.random(in: 0.3...0.8),
                green: CGFloat.random(in: 0.3...0.8),
                blue: CGFloat.random(in: 0.7...1.0),
                alpha: 0.8
            ),
            roughness: 0.1,
            isMetallic: false
        )
        let entity = ModelEntity(mesh: mesh, materials: [material])
        
        // 添加浮动动画
        entity.move(
            to: Transform(translation: [0, 0.5, 0]),
            relativeTo: entity.parent,
            duration: 3.0,
            timingFunction: .easeInOut
        )
        
        return entity
    }
    
    /// 使用 ModelIO 加载 GLB 文件（SceneKit 在 visionOS 上对 GLB 支持有限）
    private func loadGLBWithModelIO(from url: URL) async throws -> MDLAsset {
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    // 添加文件验证和调试信息
                    let fileManager = FileManager.default
                    if fileManager.fileExists(atPath: url.path) {
                        if let attributes = try? fileManager.attributesOfItem(atPath: url.path),
                           let fileSize = attributes[.size] as? Int64 {
                            print("📁 GLB file exists: \(url.path)")
                            print("📏 GLB file size: \(fileSize) bytes (\(String(format: "%.2f", Double(fileSize) / 1024 / 1024)) MB)")
                            
                            // 读取文件头部信息（GLB 文件应该以 "glTF" 开头）
                            if let fileHandle = FileHandle(forReadingAtPath: url.path) {
                                defer { fileHandle.closeFile() }
                                fileHandle.seek(toFileOffset: 0)
                                let headerData = fileHandle.readData(ofLength: 12)
                                if headerData.count >= 4 {
                                    let magic = String(data: headerData.prefix(4), encoding: .ascii) ?? "unknown"
                                    print("🔍 GLB file magic: \(magic)")
                                    if magic == "glTF" {
                                        print("✅ Valid GLB file header detected")
                                        // 读取版本和长度信息
                                        if headerData.count >= 12 {
                                            let version = headerData[4] | (headerData[5] << 8) | (headerData[6] << 16) | (headerData[7] << 24)
                                            let length = headerData[8] | (headerData[9] << 8) | (headerData[10] << 16) | (headerData[11] << 24)
                                            print("📊 GLB version: \(version), declared length: \(length) bytes")
                                        }
                                    } else {
                                        print("⚠️ Unexpected file header: \(magic) (expected 'glTF')")
                                        print("💡 This might indicate the file is corrupted or not a valid GLB file")
                                    }
                                }
                            }
                        }
                    } else {
                        print("❌ GLB file does not exist at: \(url.path)")
                        throw NSError(
                            domain: "ModelLoader",
                            code: -1,
                            userInfo: [NSLocalizedDescriptionKey: "GLB file does not exist"]
                        )
                    }
                    
                    // 使用 ModelIO 加载 GLB
                    // ModelIO 在 visionOS 上对 GLB 的支持更好
                    let asset = MDLAsset(url: url)
                    
                    print("📊 MDLAsset created, object count: \(asset.count)")
                    if asset.count > 0 {
                        for i in 0..<min(asset.count, 3) {
                            let obj = asset.object(at: i)
                            print("📦 Object \(i): \(type(of: obj)) - \(obj.name)")
                        }
                    }
                    
                    // 确保资源有内容
                    guard asset.count > 0 else {
                        print("❌ ModelIO GLB loading error: GLB file contains no objects")
                        print("💡 This might indicate:")
                        print("   1. The GLB file is corrupted")
                        print("   2. The GLB file uses features not supported by ModelIO")
                        print("   3. The file path contains special characters")
                        print("📁 File path: \(url.path)")
                        print("🔗 File URL: \(url.absoluteString)")
                        throw NSError(
                            domain: "ModelLoader",
                            code: -1,
                            userInfo: [NSLocalizedDescriptionKey: "GLB file contains no objects"]
                        )
                    }
                    
                    print("✅ ModelIO loaded GLB successfully: \(asset.count) objects")
                    continuation.resume(returning: asset)
                } catch {
                    print("❌ ModelIO GLB loading error: \(error.localizedDescription)")
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    /// 将 ModelIO Asset 转换为 RealityKit Entity
    private func convertModelIOToRealityKit(asset: MDLAsset) -> Entity {
        let containerEntity = Entity()
        
        // 遍历所有对象并转换
        for i in 0..<asset.count {
            guard let object = asset.object(at: i) as? MDLMesh else {
                continue
            }
            
            // 尝试从 MDLMesh 创建 MeshResource
            // 注意：这是一个简化的转换，可能不完美
            do {
                let meshResource = try createMeshResource(from: object)
                
                // 创建材质（从 submesh 的材质或使用默认材质）
                let material: Material
                if let submesh = object.submeshes?.firstObject as? MDLSubmesh,
                   let submeshMaterial = submesh.material {
                    material = createMaterial(from: submeshMaterial)
                } else {
                    material = SimpleMaterial(color: .white, roughness: 0.5, isMetallic: false)
                }
                
                let modelEntity = ModelEntity(mesh: meshResource, materials: [material])
                
                // 获取对象的变换
                let transform = object.transform
                if transform != nil {
                    // 应用变换（简化处理）
                    // 注意：MDLTransform 的转换比较复杂，这里先使用默认位置
                }
                
                containerEntity.addChild(modelEntity)
                print("✅ Converted MDL object \(i) to RealityKit Entity")
            } catch {
                print("⚠️ Failed to convert MDL object \(i): \(error.localizedDescription)")
            }
        }
        
        return containerEntity
    }
    
    /// 从 MDLMesh 创建 MeshResource
    private func createMeshResource(from mesh: MDLMesh) throws -> MeshResource {
        // 获取顶点数据
        guard let vertexBuffer = mesh.vertexBuffers.first else {
            throw NSError(domain: "ModelLoader", code: -1, userInfo: [NSLocalizedDescriptionKey: "No vertex buffer"])
        }
        
        // 读取顶点数据
        // MDLMesh 的顶点数据格式可能不同，需要根据实际的 buffer layout 读取
        var vertices: [SIMD3<Float>] = []
        let buffer = vertexBuffer.map()
        let bytes = buffer.bytes
        let bufferLength = vertexBuffer.length
        
        // 计算 stride（每个顶点的字节数）
        let stride = bufferLength / mesh.vertexCount
        
        for i in 0..<mesh.vertexCount {
            let offset = i * stride
            guard offset + 12 <= bufferLength else { break } // 至少需要 3 个 Float (12 字节)
            
            let floatData = bytes.advanced(by: offset).bindMemory(to: Float.self, capacity: 3)
            vertices.append(SIMD3<Float>(
                floatData[0],
                floatData[1],
                floatData[2]
            ))
        }
        
        guard !vertices.isEmpty else {
            throw NSError(domain: "ModelLoader", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to read vertex data"])
        }
        
        // 获取索引数据
        guard let submesh = mesh.submeshes?.firstObject as? MDLSubmesh else {
            throw NSError(domain: "ModelLoader", code: -1, userInfo: [NSLocalizedDescriptionKey: "No submesh"])
        }
        
        let indexBuffer = submesh.indexBuffer
        var indices: [UInt32] = []
        let indexData = indexBuffer.map().bytes
        let indexCount = submesh.indexCount
        
        switch submesh.geometryType {
        case .triangles:
            if submesh.indexType == .uInt32 {
                let uint32Data = indexData.bindMemory(to: UInt32.self, capacity: indexCount)
                indices = Array(UnsafeBufferPointer(start: uint32Data, count: indexCount))
            } else if submesh.indexType == .uInt16 {
                let uint16Data = indexData.bindMemory(to: UInt16.self, capacity: indexCount)
                indices = Array(UnsafeBufferPointer(start: uint16Data, count: indexCount)).map { UInt32($0) }
            }
        default:
            throw NSError(domain: "ModelLoader", code: -1, userInfo: [NSLocalizedDescriptionKey: "Unsupported geometry type"])
        }
        
        // 创建 MeshDescriptor
        var meshDescriptor = MeshDescriptor(name: "GLBModel")
        meshDescriptor.positions = MeshBuffers.Positions(vertices)
        meshDescriptor.primitives = .triangles(indices)
        
        // 创建 MeshResource
        return try MeshResource.generate(from: [meshDescriptor])
    }
    
    /// 从 SceneKit 几何体创建 MeshResource（保留用于兼容性）
    private func createMeshResource(from geometry: SCNGeometry) throws -> MeshResource {
        // 获取顶点数据
        guard let vertexSource = geometry.sources.first(where: { $0.semantic == .vertex }) else {
            throw NSError(domain: "ModelLoader", code: -1, userInfo: [NSLocalizedDescriptionKey: "No vertex data"])
        }
        
        // 获取法线数据（可选）
        let normalSource = geometry.sources.first(where: { $0.semantic == .normal })
        
        // 获取纹理坐标数据（可选）
        let texcoordSource = geometry.sources.first(where: { $0.semantic == .texcoord })
        
        // 读取顶点数据
        let vertexCount = vertexSource.vectorCount
        var vertices: [SIMD3<Float>] = []
        var normals: [SIMD3<Float>] = []
        var texcoords: [SIMD2<Float>] = []
        
        vertexSource.data.withUnsafeBytes { bytes in
            let stride = vertexSource.bytesPerComponent * vertexSource.componentsPerVector
            for i in 0..<vertexCount {
                let offset = i * stride
                let x = bytes.load(fromByteOffset: offset, as: Float.self)
                let y = bytes.load(fromByteOffset: offset + MemoryLayout<Float>.size, as: Float.self)
                let z = bytes.load(fromByteOffset: offset + MemoryLayout<Float>.size * 2, as: Float.self)
                vertices.append(SIMD3<Float>(x, y, z))
            }
        }
        
        // 读取法线数据
        if let normalSource = normalSource {
            normalSource.data.withUnsafeBytes { bytes in
                let stride = normalSource.bytesPerComponent * normalSource.componentsPerVector
                for i in 0..<normalSource.vectorCount {
                    let offset = i * stride
                    let x = bytes.load(fromByteOffset: offset, as: Float.self)
                    let y = bytes.load(fromByteOffset: offset + MemoryLayout<Float>.size, as: Float.self)
                    let z = bytes.load(fromByteOffset: offset + MemoryLayout<Float>.size * 2, as: Float.self)
                    normals.append(SIMD3<Float>(x, y, z))
                }
            }
        }
        
        // 读取纹理坐标数据
        if let texcoordSource = texcoordSource {
            texcoordSource.data.withUnsafeBytes { bytes in
                let stride = texcoordSource.bytesPerComponent * texcoordSource.componentsPerVector
                for i in 0..<texcoordSource.vectorCount {
                    let offset = i * stride
                    let u = bytes.load(fromByteOffset: offset, as: Float.self)
                    let v = bytes.load(fromByteOffset: offset + MemoryLayout<Float>.size, as: Float.self)
                    texcoords.append(SIMD2<Float>(u, v))
                }
            }
        }
        
        // 获取索引数据
        guard let element = geometry.elements.first else {
            throw NSError(domain: "ModelLoader", code: -1, userInfo: [NSLocalizedDescriptionKey: "No index data"])
        }
        
        var indices: [UInt32] = []
        element.data.withUnsafeBytes { bytes in
            // 计算索引数量：对于三角形，每个图元有3个索引
            let indexCount = element.primitiveCount * 3
            let bytesPerIndex = element.bytesPerIndex
            
            for i in 0..<indexCount {
                let offset = i * bytesPerIndex
                guard offset + bytesPerIndex <= element.data.count else { break }
                
                let index: UInt32
                switch bytesPerIndex {
                case 1:
                    index = UInt32(bytes.load(fromByteOffset: offset, as: UInt8.self))
                case 2:
                    index = UInt32(bytes.load(fromByteOffset: offset, as: UInt16.self))
                case 4:
                    index = bytes.load(fromByteOffset: offset, as: UInt32.self)
                default:
                    continue
                }
                indices.append(index)
            }
        }
        
        // 创建 MeshDescriptor
        var meshDescriptor = MeshDescriptor(name: "GLBModel")
        meshDescriptor.positions = MeshBuffers.Positions(vertices)
        if !normals.isEmpty {
            meshDescriptor.normals = MeshBuffers.Normals(normals)
        }
        if !texcoords.isEmpty {
            meshDescriptor.textureCoordinates = MeshBuffers.TextureCoordinates(texcoords)
        }
        meshDescriptor.primitives = .triangles(indices)
        
        // 创建 MeshResource
        return try MeshResource.generate(from: [meshDescriptor])
    }
    
    /// 从 MDL 材质创建 RealityKit 材质
    private func createMaterial(from mdlMaterial: MDLMaterial?) -> Material {
        guard let mdlMaterial = mdlMaterial else {
            return SimpleMaterial(color: .white, roughness: 0.5, isMetallic: false)
        }
        
        // 获取基础颜色
        var color: UIColor = .white
        if let baseColor = mdlMaterial.property(with: .baseColor) {
            let colorValue = baseColor.float3Value
            color = UIColor(
                red: CGFloat(colorValue.x),
                green: CGFloat(colorValue.y),
                blue: CGFloat(colorValue.z),
                alpha: 1.0
            )
        }
        
        // 获取粗糙度
        var roughness: Float = 0.5
        if let roughnessProp = mdlMaterial.property(with: .roughness) {
            roughness = Float(roughnessProp.floatValue)
        }
        
        // 检查是否为金属
        var isMetallic = false
        if let metallicProp = mdlMaterial.property(with: .metallic) {
            isMetallic = metallicProp.floatValue > 0.5
        }
        
        return SimpleMaterial(
            color: color,
            roughness: MaterialScalarParameter(floatLiteral: roughness),
            isMetallic: isMetallic
        )
    }
    
    /// 从 SceneKit 材质创建 RealityKit 材质（保留用于兼容性）
    private func createMaterialFromSceneKit(from scnMaterial: SCNMaterial?) -> Material {
        guard let scnMaterial = scnMaterial else {
            return SimpleMaterial(color: .white, roughness: 0.5, isMetallic: false)
        }
        
        // 获取颜色
        let color: UIColor
        if let diffuseContents = scnMaterial.diffuse.contents as? UIColor {
            color = diffuseContents
        } else {
            color = .white
        }
        
        // 获取粗糙度（SceneKit 的 roughness 属性在 iOS 13+ 可用）
        let roughnessValue: Double
        if let roughnessContents = scnMaterial.roughness.contents as? Double {
            roughnessValue = roughnessContents
        } else {
            roughnessValue = 0.5
        }
        
        // 检查是否为金属材质
        let isMetallic = scnMaterial.metalness.contents != nil
        
        // 创建 SimpleMaterial
        return SimpleMaterial(
            color: color,
            roughness: MaterialScalarParameter(floatLiteral: Float(roughnessValue)),
            isMetallic: isMetallic
        )
    }
}

enum ModelLoadError: LocalizedError {
    case invalidURL
    case invalidModel
    case downloadFailed
    case unsupportedFormat(String) // 新增：不支持的格式
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "无效的模型URL"
        case .invalidModel:
            return "无效的模型文件"
        case .downloadFailed:
            return "模型下载失败"
        case .unsupportedFormat(let format):
            return "不支持的模型格式: \(format)。visionOS 推荐使用 USDZ 格式"
        }
    }
}
