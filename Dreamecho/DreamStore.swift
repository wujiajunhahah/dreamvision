//
//  DreamStore.swift
//  Dreamecho
//
//  Created by sztu on 2025/11/9.
//

import Foundation

@MainActor
@Observable
class DreamStore {
    var dreams: [Dream] = []
    var currentDream: Dream?
    var isLoading = false
    var errorMessage: String?
    
    private let apiService = APIService.shared
    private var isSaving = false  // 防止重复保存
    
    // 数据持久化文件路径
    private var dreamsFileURL: URL {
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return documentsDirectory.appendingPathComponent("dreams.json")
    }
    
    init() {
        // 启动时加载保存的梦境
        loadDreams()
    }
    
    /// 保存梦境数据到本地文件
    private func saveDreams() {
        // 防止重复保存
        guard !isSaving else { return }
        isSaving = true
        
        Task { @MainActor in
            defer { isSaving = false }
            
            do {
                let encoder = JSONEncoder()
                encoder.dateEncodingStrategy = .iso8601
                let data = try encoder.encode(dreams)
                try data.write(to: dreamsFileURL)
                print("💾 Saved \(dreams.count) dreams to \(dreamsFileURL.path)")
            } catch {
                print("❌ Failed to save dreams: \(error.localizedDescription)")
            }
        }
    }
    
    private func updateStatus(at index: Int, to status: DreamStatus) {
        dreams[index].status = status
        dreams[index].statusUpdatedAt = Date()
    }
    
    /// 从本地文件加载梦境数据
    private func loadDreams() {
        guard FileManager.default.fileExists(atPath: dreamsFileURL.path) else {
            print("📦 No saved dreams found, starting fresh")
            return
        }
        
        do {
            let data = try Data(contentsOf: dreamsFileURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let loadedDreams = try decoder.decode([Dream].self, from: data)
            
            // 始终加载保存的梦境（应用启动时 dreams 应该是空的）
            dreams = loadedDreams
            print("✅ Loaded \(loadedDreams.count) dreams from disk")
            
            // 打印加载的梦境信息（用于调试）
            for dream in loadedDreams {
                print("📦 Dream '\(dream.title)' - Status: \(dream.status.rawValue)")
                if let modelURL = dream.modelURL {
                    print("   ✅ Has model: \(modelURL.prefix(80))...")
                } else {
                    print("   ⚠️ No model URL")
                }
                if dream.analysis != nil {
                    print("   ✅ Has analysis")
                }
            }
        } catch {
            print("❌ Failed to load dreams: \(error.localizedDescription)")
            print("❌ Error details: \(error)")
            // 如果加载失败，尝试删除损坏的文件
            try? FileManager.default.removeItem(at: dreamsFileURL)
        }
    }
    
    func createDream(title: String, description: String) -> Dream {
        let dream = Dream(
            title: title,
            description: description,
            status: .draft
        )
        dreams.insert(dream, at: 0)
        dreams[0].statusUpdatedAt = Date()
        currentDream = dream
        // 创建后立即保存
        saveDreams()
        return dream
    }
    
    /// 只分析梦境，不生成模型
    func analyzeDream(_ dream: Dream) async {
        guard let index = dreams.firstIndex(where: { $0.id == dream.id }) else { return }
        
        // 更新状态
        updateStatus(at: index, to: .analyzing)
        currentDream = dreams[index]
        isLoading = true
        errorMessage = nil
        
        print("🔄 Dream status updated to: analyzing")
        
        do {
            // 调用 API 分析梦境
            let analysis = try await apiService.analyzeDream(dream.description)
            
            // 更新结果
            guard let currentIndex = dreams.firstIndex(where: { $0.id == dream.id }) else { return }
            dreams[currentIndex].analysis = analysis
            dreams[currentIndex].keywords = analysis.keywords
            dreams[currentIndex].emotions = analysis.emotions
            dreams[currentIndex].symbols = analysis.symbols
            updateStatus(at: currentIndex, to: .analyzed)  // 分析完成，但未生成模型
            currentDream = dreams[currentIndex]
            
            // 立即保存（确保分析结果被持久化）
            saveDreams()
            
            print("✅ Dream analysis completed, status: analyzed")
            isLoading = false
        } catch {
            // 更新错误状态
            guard let errorIndex = dreams.firstIndex(where: { $0.id == dream.id }) else { return }
            updateStatus(at: errorIndex, to: .failed)
            
            let detailedError: String
            if let apiError = error as? APIError {
                detailedError = apiError.localizedDescription
            } else {
                detailedError = error.localizedDescription
            }
            
            errorMessage = detailedError
            isLoading = false
            
            print("❌ Dream analysis failed: \(detailedError)")
        }
    }
    
    /// 为已分析的梦境生成 3D 模型
    func generateModel(for dream: Dream) async {
        guard let index = dreams.firstIndex(where: { $0.id == dream.id }),
              dream.status == .analyzed,
              let analysis = dream.analysis else {
            errorMessage = "Dream must be analyzed before generating model"
            return
        }
        
        // 更新状态
        updateStatus(at: index, to: .generating)
        currentDream = dreams[index]
        isLoading = true
        errorMessage = nil
        
        print("🔄 Dream status updated to: generating")
        
        do {
            let modelPrompt = try await apiService.generateModelPrompt(from: analysis)
            let modelURL = try await apiService.generate3DModel(prompt: modelPrompt)
            
            // 更新最终结果
            guard let finalIndex = dreams.firstIndex(where: { $0.id == dream.id }) else { return }
            dreams[finalIndex].modelURL = modelURL
            updateStatus(at: finalIndex, to: .completed)
            currentDream = dreams[finalIndex]
            
            // 立即保存（确保 modelURL 被持久化）
            saveDreams()
            
            print("✅ Dream model generated, status: completed")
            isLoading = false
        } catch let modelError as APIError {
            guard let modelIndex = dreams.firstIndex(where: { $0.id == dream.id }) else { return }
            updateStatus(at: modelIndex, to: .failed)
            errorMessage = modelError.localizedDescription
            isLoading = false
            print("❌ Model generation failed: \(modelError.localizedDescription)")
        } catch {
            guard let errorIndex = dreams.firstIndex(where: { $0.id == dream.id }) else { return }
            updateStatus(at: errorIndex, to: .failed)
            errorMessage = error.localizedDescription
            isLoading = false
            print("❌ Model generation failed: \(error.localizedDescription)")
        }
    }
    
    /// 取消处理
    func cancelProcessing(_ dream: Dream) async {
        guard let index = dreams.firstIndex(where: { $0.id == dream.id }) else { return }
        updateStatus(at: index, to: .draft)
        if currentDream?.id == dream.id {
            currentDream = nil
        }
        isLoading = false
    }
    
    /// 旧方法保留用于兼容（已废弃）
    @available(*, deprecated, message: "Use analyzeDream and generateModel separately")
    func processDream(_ dream: Dream) async {
        await analyzeDream(dream)
        if let updatedDream = dreams.first(where: { $0.id == dream.id }),
           updatedDream.status == .analyzed {
            await generateModel(for: updatedDream)
        }
    }
    
    func deleteDream(_ dream: Dream) {
        dreams.removeAll { $0.id == dream.id }
        if currentDream?.id == dream.id {
            currentDream = nil
        }
        // 删除后自动保存
        saveDreams()
    }
    
    /// 手动保存梦境数据（用于外部调用）
    func saveDreamsManually() {
        saveDreams()
    }
    
    func loadSampleDreamsIfNeeded() {
        // Only load if dreams list is empty
        guard dreams.isEmpty else { return }
        
        // 检查是否有保存的数据，如果有就不加载示例数据
        if FileManager.default.fileExists(atPath: dreamsFileURL.path) {
            print("📦 Found saved dreams, skipping sample data")
            return
        }
        
        // 如果没有保存的数据，加载示例数据（但不包含 modelURL，因为示例数据没有真实的模型）
        dreams = [
            Dream(
                title: "Flying Dream",
                description: "I was flying freely through the sky, passing through clouds, and saw a floating castle.",
                status: .completed,
                keywords: ["flying", "sky", "castle"],
                emotions: ["freedom", "excitement"],
                symbols: ["wings", "clouds"]
            ),
            Dream(
                title: "Deep Sea Exploration",
                description: "I dived into the deep sea and saw glowing corals and mysterious sea creatures.",
                status: .completed,
                keywords: ["deep sea", "coral", "sea creatures"],
                emotions: ["curiosity", "peace"],
                symbols: ["water", "light"]
            )
        ]
        // 保存示例数据
        saveDreams()
    }
}
