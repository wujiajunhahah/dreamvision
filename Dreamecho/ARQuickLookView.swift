//
//  ARQuickLookView.swift
//  Dreamecho
//
//  Created by sztu on 2025/11/9.
//

import SwiftUI
import QuickLook
import ARKit

/// AR Quick Look 预览视图 - 使用系统原生预览（推荐用于 USDZ 格式）
/// 参考: https://developer.apple.com/documentation/ARKit/previewing-a-model-with-ar-quick-look
struct ARQuickLookView: UIViewControllerRepresentable {
    let modelURL: URL
    let allowsContentScaling: Bool
    let onDismiss: () -> Void
    
    init(modelURL: URL, allowsContentScaling: Bool = true, onDismiss: @escaping () -> Void = {}) {
        self.modelURL = modelURL
        self.allowsContentScaling = allowsContentScaling
        self.onDismiss = onDismiss
    }
    
    func makeUIViewController(context: Context) -> UIViewController {
        let controller = QLPreviewController()
        controller.dataSource = context.coordinator
        controller.delegate = context.coordinator
        
        // 创建导航控制器，添加返回按钮
        let navController = UINavigationController(rootViewController: controller)
        
        // 添加返回按钮
        let closeButton = UIBarButtonItem(
            barButtonSystemItem: .close,
            target: context.coordinator,
            action: #selector(Coordinator.close)
        )
        controller.navigationItem.leftBarButtonItem = closeButton
        controller.navigationItem.title = "3D Model Preview"
        
        // 设置 coordinator 的 dismiss 回调
        context.coordinator.dismiss = onDismiss
        
        return navController
    }
    
    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        // 更新预览控制器
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(modelURL: modelURL)
    }
    
    class Coordinator: NSObject, QLPreviewControllerDataSource, QLPreviewControllerDelegate {
        let modelURL: URL
        var dismiss: (() -> Void)?
        
        init(modelURL: URL) {
            self.modelURL = modelURL
        }
        
        @objc func close() {
            dismiss?()
        }
        
        func numberOfPreviewItems(in controller: QLPreviewController) -> Int {
            return 1
        }
        
        func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem {
            return modelURL as QLPreviewItem
        }
        
        // 当用户点击完成按钮时也关闭
        func previewControllerWillDismiss(_ controller: QLPreviewController) {
            dismiss?()
        }
    }
}

/// 模型预览协调器 - 处理下载和本地文件管理
@MainActor
class ModelPreviewCoordinator {
    static let shared = ModelPreviewCoordinator()
    
    private var cachedFiles: [String: URL] = [:]
    
    private init() {}
    
    /// 下载模型并返回本地 URL（用于 AR Quick Look）
    func downloadModelForPreview(urlString: String) async throws -> URL {
        // 检查缓存
        if let cachedURL = cachedFiles[urlString],
           FileManager.default.fileExists(atPath: cachedURL.path) {
            print("📦 Using cached model for AR Quick Look: \(cachedURL.lastPathComponent)")
            return cachedURL
        }
        
        guard let url = URL(string: urlString) else {
            throw ModelLoadError.invalidURL
        }
        
        print("📥 Downloading model for AR Quick Look: \(urlString.prefix(80))...")
        
        let (data, response) = try await URLSession.shared.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw ModelLoadError.downloadFailed
        }
        
        print("✅ Model downloaded: \(data.count) bytes")
        
        // 确定文件扩展名
        let fileExtension: String
        let urlLower = urlString.lowercased()
        if urlLower.contains(".usdz") {
            fileExtension = "usdz"
        } else if urlLower.contains(".glb") {
            fileExtension = "glb"
        } else if urlLower.contains(".usd") {
            fileExtension = "usd"
        } else {
            // 尝试从 Content-Type 判断
            if let contentType = httpResponse.value(forHTTPHeaderField: "Content-Type")?.lowercased() {
                if contentType.contains("usdz") || contentType.contains("model/vnd.usdz") {
                    fileExtension = "usdz"
                } else if contentType.contains("glb") || contentType.contains("model/gltf-binary") {
                    fileExtension = "glb"
                } else {
                    fileExtension = "usdz" // 默认尝试 USDZ
                }
            } else {
                fileExtension = "usdz"
            }
        }
        
        // 保存到临时目录
        let tempDir = FileManager.default.temporaryDirectory
        let fileName = "\(UUID().uuidString).\(fileExtension)"
        let tempURL = tempDir.appendingPathComponent(fileName)
        
        try data.write(to: tempURL)
        cachedFiles[urlString] = tempURL
        
        print("💾 Model saved for AR Quick Look: \(tempURL.path)")
        print("📦 Format: \(fileExtension.uppercased())")
        
        return tempURL
    }
    
    /// 清理缓存
    func clearCache() {
        for (_, url) in cachedFiles {
            try? FileManager.default.removeItem(at: url)
        }
        cachedFiles.removeAll()
    }
}

