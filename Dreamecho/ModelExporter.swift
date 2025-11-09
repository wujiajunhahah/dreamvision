//
//  ModelExporter.swift
//  Dreamecho
//
//  Created by sztu on 2025/11/9.
//

import SwiftUI
import UniformTypeIdentifiers

/// 模型导出器 - 用于导出模型文件到用户可以访问的位置
@MainActor
class ModelExporter {
    static let shared = ModelExporter()
    
    private init() {}
    
    /// 导出模型文件到 Documents 目录
    func exportModelToDocuments(modelURL: String, dreamTitle: String) async throws -> URL {
        // 下载模型文件
        guard let url = URL(string: modelURL) else {
            throw NSError(domain: "ModelExporter", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid model URL"])
        }
        
        print("📥 Downloading model for export: \(modelURL)")
        let (data, _) = try await URLSession.shared.data(from: url)
        
        // 获取 Documents 目录
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        
        // 创建 Models 子目录
        let modelsDirectory = documentsURL.appendingPathComponent("ExportedModels", isDirectory: true)
        try? FileManager.default.createDirectory(at: modelsDirectory, withIntermediateDirectories: true)
        
        // 生成文件名（使用梦境标题和时间戳）
        let sanitizedTitle = dreamTitle
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "\\", with: "_")
            .replacingOccurrences(of: ":", with: "_")
            .replacingOccurrences(of: "*", with: "_")
            .replacingOccurrences(of: "?", with: "_")
            .replacingOccurrences(of: "\"", with: "_")
            .replacingOccurrences(of: "<", with: "_")
            .replacingOccurrences(of: ">", with: "_")
            .replacingOccurrences(of: "|", with: "_")
        
        let timestamp = Int(Date().timeIntervalSince1970)
        let fileName = "\(sanitizedTitle)_\(timestamp).glb"
        let fileURL = modelsDirectory.appendingPathComponent(fileName)
        
        // 保存文件
        try data.write(to: fileURL)
        print("✅ Model exported to: \(fileURL.path)")
        
        return fileURL
    }
    
    /// 获取所有导出的模型文件
    func getExportedModels() -> [URL] {
        guard let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return []
        }
        
        let modelsDirectory = documentsURL.appendingPathComponent("ExportedModels", isDirectory: true)
        
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: modelsDirectory,
            includingPropertiesForKeys: [.creationDateKey],
            options: .skipsHiddenFiles
        ) else {
            return []
        }
        
        return files.filter { $0.pathExtension.lowercased() == "glb" || $0.pathExtension.lowercased() == "usdz" }
            .sorted { url1, url2 in
                let date1 = (try? url1.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? Date.distantPast
                let date2 = (try? url2.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? Date.distantPast
                return date1 > date2
            }
    }
}

/// 分享模型文件的视图控制器包装器
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    let applicationActivities: [UIActivity]?
    
    init(items: [Any], applicationActivities: [UIActivity]? = nil) {
        self.items = items
        self.applicationActivities = applicationActivities
    }
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(
            activityItems: items,
            applicationActivities: applicationActivities
        )
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {
        // No update needed
    }
}

