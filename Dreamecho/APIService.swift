//
//  APIService.swift
//  Dreamecho
//
//  Created by AI on 2025/11/11.
//

import Foundation
import RealityKit
import CryptoKit

/// API服务，处理与DeepSeek和腾讯混元的通信
class APIService {
    static let shared = APIService()

    // 从 Info.plist 读取 API 密钥（避免硬编码）
    private let deepSeekAPIKey: String
    private let hunyuanSecretId: String
    private let hunyuanSecretKey: String

    private let deepSeekBaseURL = "https://api.deepseek.com/v1/chat/completions"
    private let hunyuanEndpoint = "https://hunyuan.tencentcloudapi.com/"
    private let hunyuanRegion = "ap-beijing"
    private let hunyuanService = "hunyuan"
    private let hunyuanVersion = "2024-05-15"

    private init() {
        // 从 Info.plist 读取 API 密钥
        guard let deepSeekKey = Bundle.main.object(forInfoDictionaryKey: "DeepSeekAPIKey") as? String,
              let secretId = Bundle.main.object(forInfoDictionaryKey: "TencentSecretId") as? String,
              let secretKey = Bundle.main.object(forInfoDictionaryKey: "TencentSecretKey") as? String else {
            fatalError("❌ API keys not found in Info.plist. Please add DeepSeekAPIKey, TencentSecretId and TencentSecretKey to Info.plist")
        }

        self.deepSeekAPIKey = deepSeekKey
        self.hunyuanSecretId = secretId
        self.hunyuanSecretKey = secretKey

        print("✅ API keys loaded from Info.plist")
    }

    // MARK: - DeepSeek API

    /// 3D生成模式
    enum GenerationMode: String {
        case visionOS = "visionOS"  // visionOS场景模式：强调空间、光影、雾化、体积光
        case printSafe = "printSafe"  // 打印安全模式：强调单体封闭网格、底座、重心
    }
    
    /// 分析梦境内容
    func analyzeDream(_ description: String) async throws -> DreamAnalysis {
        print("🔍 Analyzing dream...")

        let requestBody = AnalyzeDreamRequestBody(
            model: "deepseek-chat", // 使用标准模型（reasoner可能超时）
            messages: [
                .init(role: "user", content: """
                请分析以下梦境描述，并返回JSON格式的分析结果：

                \(description)

                请返回以下格式的JSON：
                {
                    "keywords": ["关键词1", "关键词2", ...],
                    "emotions": ["情感1", "情感2", ...],
                    "symbols": ["象征1", "象征2", ...],
                    "visual_description": "视觉描述",
                    "interpretation": "梦境解读"
                }
                """)
            ],
            temperature: 0.7
        )

        let (data, response) = try await performRequest(
            url: deepSeekBaseURL,
            method: "POST",
            headers: [
                "Content-Type": "application/json",
                "Authorization": "Bearer \(deepSeekAPIKey)"
            ],
            body: requestBody
        )

        guard let httpResponse = response as? HTTPURLResponse else {
            print("❌ API Error: Invalid response type")
            throw APIError.invalidResponse
        }

        // 详细的错误处理
        guard httpResponse.statusCode == 200 else {
            let errorString = String(data: data, encoding: .utf8) ?? "Unknown error"
            print("❌ API Error: HTTP \(httpResponse.statusCode)")
            print("❌ Error response: \(errorString)")

            // 尝试解析错误详情
            if let errorJson = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let error = errorJson["error"] as? [String: Any],
               let errorMessage = error["message"] as? String {
                print("❌ Error message: \(errorMessage)")
            }

            switch httpResponse.statusCode {
            case 401:
                throw APIError.authenticationFailed
            case 402:
                throw APIError.insufficientBalance
            case 429:
                throw APIError.rateLimited
            case 500...599:
                throw APIError.serverError
            default:
                throw APIError.invalidResponse
            }
        }

        print("✅ API Response received: \(data.count) bytes")

        let decoder = JSONDecoder()
        let apiResponse = try decoder.decode(DeepSeekResponse.self, from: data)

        // 解析返回的JSON内容
        guard let firstChoice = apiResponse.choices.first else {
            throw APIError.invalidResponse
        }

        let content = firstChoice.message.content

        // 智能提取JSON（处理多种格式）
        let jsonString = extractJSON(from: content)
        
        print("📝 Extracted JSON string length: \(jsonString.count)")
        
        guard let jsonData = jsonString.data(using: .utf8) else {
            print("❌ Failed to convert JSON string to data")
            throw APIError.invalidResponse
        }

        do {
            let analysis = try decoder.decode(DreamAnalysis.self, from: jsonData)
            print("✅ Dream analysis parsed successfully")
            print("   Keywords (\(analysis.keywords.count)): \(analysis.keywords.prefix(5).joined(separator: ", "))\(analysis.keywords.count > 5 ? "..." : "")")
            print("   Emotions (\(analysis.emotions.count)): \(analysis.emotions.prefix(3).joined(separator: ", "))\(analysis.emotions.count > 3 ? "..." : "")")
            print("   Symbols (\(analysis.symbols.count)): \(analysis.symbols.prefix(3).joined(separator: ", "))\(analysis.symbols.count > 3 ? "..." : "")")
            return analysis
        } catch let decodeError {
            print("❌ JSON parsing error: \(decodeError)")
            print("❌ JSON string (first 500 chars): \(String(jsonString.prefix(500)))")
            
            // 尝试修复常见的JSON格式问题
            if let fixedJSON = tryFixJSON(jsonString) {
                print("🔧 Attempting to fix JSON format...")
                if let fixedData = fixedJSON.data(using: .utf8),
                   let fixedAnalysis = try? decoder.decode(DreamAnalysis.self, from: fixedData) {
                    print("✅ Successfully fixed and parsed JSON")
                    return fixedAnalysis
                }
            }
            
            throw APIError.parsingFailed(decodeError.localizedDescription)
        }
    }

    /// 生成3D模型提示词（中文视觉指示词，专业版）
    /// 按照12维度规范生成可直接用于混元To3D的中文视觉指示词
    func generateModelPrompt(from analysis: DreamAnalysis, mode: GenerationMode = .visionOS) async throws -> String {
        print("🎨 Generating 3D visual prompt (Mode: \(mode.rawValue))...")
        
        let systemPrompt = """
        你是一名"梦境到3D视觉指示词"的翻译器。输出一段中文场景描述（60–120字），仅描述可见空间、光照、材质、构图、尺度与几何，不要心理分析。若模式为打印安全，则必须包含：单体封闭网格、厚度≥2mm、无悬空、圆形底座一体成型、重心约束。禁止文字与Logo。
        """
        
        let userPrompt = """
        【模式】\(mode.rawValue)
        
        【关键词】\(analysis.keywords.joined(separator: "，"))
        
        【视觉线索】\(analysis.visualDescription)
        
        【情绪】\(analysis.emotions.joined(separator: "，"))
        
        
        请按以下顺序编写一段可直接用于3D生成的中文视觉指示词：场景与空间→主体与叙事→构图与透视→光照与氛围→色彩与材质→动态暗示→\(mode == .printSafe ? "打印约束与底座与重心→" : "")禁止项。
        
        长度控制在60–120字，完整句式，不要列表，不要出现"情绪、关键词"等提示词字样。
        """
        
        let requestBody = GeneratePromptRequestBody(
            model: "deepseek-chat", // 使用标准模型（reasoner可能超时）
            messages: [
                .init(role: "system", content: systemPrompt),
                .init(role: "user", content: userPrompt)
            ],
            temperature: 0.7
        )

        let (data, response) = try await performRequest(
            url: deepSeekBaseURL,
            method: "POST",
            headers: [
                "Content-Type": "application/json",
                "Authorization": "Bearer \(deepSeekAPIKey)"
            ],
            body: requestBody
        )

        guard let httpResponse = response as? HTTPURLResponse else {
            print("❌ Invalid response type")
            throw APIError.invalidResponse
        }

        // 详细的错误处理
        guard httpResponse.statusCode == 200 else {
            let errorString = String(data: data, encoding: .utf8) ?? "Unknown error"
            print("❌ DeepSeek API Error: HTTP \(httpResponse.statusCode)")
            print("❌ Error response: \(errorString)")
            
            // 尝试解析错误详情
            if let errorJson = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let error = errorJson["error"] as? [String: Any],
               let errorMessage = error["message"] as? String {
                print("❌ Error message: \(errorMessage)")
            }
            
            switch httpResponse.statusCode {
            case 401:
                throw APIError.authenticationFailed
            case 402, 429:
                throw APIError.invalidResponse // 速率限制或配额不足
            default:
                throw APIError.invalidResponse
            }
        }

        // 打印响应内容用于调试
        if let responseString = String(data: data, encoding: .utf8) {
            print("📥 DeepSeek response: \(responseString.prefix(500))")
        }

        let decoder = JSONDecoder()
        do {
            let apiResponse = try decoder.decode(DeepSeekResponse.self, from: data)
            
            guard let firstChoice = apiResponse.choices.first else {
                print("❌ No choices in response")
                throw APIError.invalidResponse
            }
            
            let rawContent = firstChoice.message.content
            
            // 智能提取和清理中文视觉指示词
            let cleanedPrompt = extractVisualPrompt(from: rawContent)
            
            // 验证提示词质量
            let validatedPrompt = validateVisualPrompt(cleanedPrompt)
            
            print("✅ Generated Chinese visual prompt: \(validatedPrompt.prefix(150))")
            print("📝 Prompt length: \(validatedPrompt.count) characters")
            print("📊 Prompt quality check: \(validatedPrompt.count >= 60 && validatedPrompt.count <= 200 ? "✅ Good" : "⚠️ Length may be outside optimal range")")
            return validatedPrompt
        } catch {
            print("❌ Failed to decode DeepSeek response: \(error)")
            if let responseString = String(data: data, encoding: .utf8) {
                print("❌ Raw response: \(responseString)")
            }
            throw APIError.invalidResponse
        }
    }

    // MARK: - 腾讯混元 API

    /// 测试腾讯混元API连接
    func testHunyuanConnection() async throws -> Bool {
        print("🧪 Testing Hunyuan API connection...")

        let testPrompt = "你好，这是一个测试请求。请回复确认连接正常。"

        let requestBody = HunyuanRequestBody(
            Model: "hunyuan-lite",
            Messages: [
                .init(Role: "user", Content: testPrompt, Name: nil)
            ],
            Temperature: 0.7,
            Stream: false,
            TopP: nil,
            MaxTokens: 100
        )

        do {
            let (data, response) = try await performHunyuanRequest(
                action: "ChatCompletions",
                body: requestBody
            )

            guard let httpResponse = response as? HTTPURLResponse else {
                print("❌ Test failed: Invalid response type")
                return false
            }

            if httpResponse.statusCode == 200 {
                let hunyuanResponse = try JSONDecoder().decode(HunyuanResponse.self, from: data)

                if let error = hunyuanResponse.Response.Error {
                    print("❌ Test failed: API error [\(error.Code)]: \(error.Message)")
                    return false
                }

                if let choices = hunyuanResponse.Response.Choices,
                   let firstChoice = choices.first {
                    let content = firstChoice.Message.Content
                    print("✅ Hunyuan API connection test successful!")
                    print("📝 Test response: \(content.prefix(100))...")
                    return true
                } else {
                    print("❌ Test failed: No response content")
                    return false
                }
            } else {
                print("❌ Test failed: HTTP \(httpResponse.statusCode)")
                return false
            }
        } catch {
            print("❌ Test failed with error: \(error)")
            return false
        }
    }

    /// 生成3D模型（使用后端代理服务）
    /// prompt: 中文视觉指示词（由DeepSeek生成）
    func generate3DModel(prompt: String) async throws -> String {
        print("🎨 Starting 3D model generation with backend service...")
        print("📝 Chinese visual prompt: \(prompt.prefix(150))...")

        // 使用后端代理服务进行3D生成（直接传递中文提示词）
        let downloadURL = try await BackendAPIService.shared.generate3DModel(prompt: prompt)

        // 尝试写入 AppAssets/models.json 供构建期转换使用（可选，失败不影响主流程）
        // 注意：在运行时（visionOS设备）可能没有权限写入项目目录，这是正常的
        Task {
            do {
                try await writeToModelsJSON(downloadURL: downloadURL, dreamDescription: prompt)
            } catch {
                // 静默失败，不影响主流程（运行时不需要这个功能）
                print("⚠️ Failed to write models.json (this is normal in runtime): \(error.localizedDescription)")
            }
        }

        return downloadURL
    }

    /// 写入 models.json 供构建期脚本使用（Reality Composer Pro 工作流）
    /// 将下载的USDZ URL写入配置文件，Xcode Build Phase会自动下载并转换为.reality
    private func writeToModelsJSON(downloadURL: String, dreamDescription: String) async throws {
        // 使用项目根目录的 AppAssets（构建期可访问）
        guard let projectRoot = Bundle.main.bundlePath.components(separatedBy: "/").prefix(while: { $0 != "Build" }).joined(separator: "/").isEmpty ? 
            FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first :
            URL(fileURLWithPath: "/\(Bundle.main.bundlePath.components(separatedBy: "/").prefix(while: { $0 != "Build" }).joined(separator: "/"))") else {
            // 回退到Documents目录
            let modelsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
                .appendingPathComponent("AppAssets")
            let modelsFile = modelsDir.appendingPathComponent("models.json")
            return try await writeToModelsJSONFallback(downloadURL: downloadURL, dreamDescription: dreamDescription, modelsFile: modelsFile)
        }
        
        // 尝试写入项目根目录的 AppAssets（构建期可访问）
        let projectAppAssets = projectRoot.appendingPathComponent("AppAssets")
        let modelsFile = projectAppAssets.appendingPathComponent("models.json")
        
        // 如果项目目录不可写，回退到Documents目录
        if !FileManager.default.isWritableFile(atPath: projectAppAssets.path) {
            return try await writeToModelsJSONFallback(downloadURL: downloadURL, dreamDescription: dreamDescription, modelsFile: modelsFile)
        }
        
        try await writeToModelsJSONFallback(downloadURL: downloadURL, dreamDescription: dreamDescription, modelsFile: modelsFile)
    }
    
    /// 实际写入 models.json 的实现
    private func writeToModelsJSONFallback(downloadURL: String, dreamDescription: String, modelsFile: URL) async throws {

        // 读取现有配置（如果存在）
        var existingModels: [[String: Any]] = []
        if let existingData = try? Data(contentsOf: modelsFile),
           let existingJson = try? JSONSerialization.jsonObject(with: existingData) as? [String: Any],
           let models = existingJson["models"] as? [[String: Any]] {
            existingModels = models
        }
        
        // 添加新模型（或更新同名模型）
        let newModel: [String: Any] = [
            "name": "dreamecho_model",
            "url": downloadURL,
            "description": dreamDescription,
            "timestamp": ISO8601DateFormatter().string(from: Date())
        ]
        
        // 移除同名旧模型（如果存在）
        existingModels.removeAll { $0["name"] as? String == "dreamecho_model" }
        existingModels.append(newModel)
        
        let modelsData: [String: Any] = [
            "models": existingModels
        ]

        // 确保目录存在
        try FileManager.default.createDirectory(at: modelsFile.deletingLastPathComponent(), withIntermediateDirectories: true)

        // 写入文件
        let jsonData = try JSONSerialization.data(withJSONObject: modelsData, options: .prettyPrinted)
        try jsonData.write(to: modelsFile)

        print("✅ Written to models.json: \(modelsFile.path)")
        print("💡 Xcode Build Phase will automatically convert USDZ to .reality using Reality Composer Pro tools")
    }

    // MARK: - Helper Methods

    /// 腾讯云API请求方法
    private func performHunyuanRequest<T: Encodable>(
        action: String,
        body: T
    ) async throws -> (Data, URLResponse) {
        let url = URL(string: hunyuanEndpoint)!

        // 编码请求体
        let encoder = JSONEncoder()
        let requestData = try encoder.encode(body)
        let jsonString = String(data: requestData, encoding: .utf8) ?? "{}"

        // 生成腾讯云API签名
        let timestamp = String(Int(Date().timeIntervalSince1970))
        let headers = try generateHunyuanHeaders(
            action: action,
            timestamp: timestamp,
            payload: jsonString
        )

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 30.0

        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }

        request.httpBody = requestData

        print("🌐 Making Hunyuan request to: \(url)")
        print("📤 Request action: \(action)")
        print("📤 Request body: \(jsonString.prefix(200))...")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            print("📥 Hunyuan response received: \(data.count) bytes")
            return (data, response)
        } catch {
            print("❌ Hunyuan network error: \(error.localizedDescription)")
            throw APIError.networkError(error.localizedDescription)
        }
    }

    /// 生成腾讯云API签名
    private func generateHunyuanHeaders(action: String, timestamp: String, payload: String) throws -> [String: String] {
        let service = hunyuanService
        let version = hunyuanVersion
        let host = "hunyuan.tencentcloudapi.com"
        let algorithm = "TC3-HMAC-SHA256"

        // 1. 拼接规范请求串
        let httpRequestMethod = "POST"
        let canonicalUri = "/"
        let canonicalQueryString = ""
        let canonicalHeaders = "content-type:application/json\nhost:\(host)\n"
        let signedHeaders = "content-type;host"
        let hashedRequestPayload = sha256Hex(payload)
        let canonicalRequest = """
        \(httpRequestMethod)\n\(canonicalUri)\n\(canonicalQueryString)\n\(canonicalHeaders)\n\(signedHeaders)\n\(hashedRequestPayload)
        """

        // 2. 拼接待签名字符串
        let credentialScope = "\(timestamp)/\(service)/tc3_request"
        let hashedCanonicalRequest = sha256Hex(canonicalRequest)
        let stringToSign = """
        \(algorithm)\n\(timestamp)\n\(credentialScope)\n\(hashedCanonicalRequest)
        """

        // 3. 计算签名
        let secretDate = hmacSha256(data: timestamp, key: "TC3" + hunyuanSecretKey)
        let secretService = hmacSha256(data: service, keyData: secretDate)
        let secretSigning = hmacSha256(data: "tc3_request", keyData: secretService)
        let signature = hmacSha256Hex(data: stringToSign, keyData: secretSigning)

        // 4. 拼接 Authorization
        let authorization = "\(algorithm) Credential=\(hunyuanSecretId)/\(credentialScope), SignedHeaders=\(signedHeaders), Signature=\(signature)"

        return [
            "Authorization": authorization,
            "Content-Type": "application/json",
            "Host": host,
            "X-TC-Action": action,
            "X-TC-Timestamp": timestamp,
            "X-TC-Version": version,
            "X-TC-Region": hunyuanRegion
        ]
    }

    /// SHA256 哈希
    private func sha256Hex(_ input: String) -> String {
        let data = Data(input.utf8)
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }

    /// HMAC-SHA256
    private func hmacSha256(data: String, key: String) -> Data {
        let keyData = Data(key.utf8)
        let dataData = Data(data.utf8)

        let symmetricKey = SymmetricKey(data: keyData)
        let hmac = HMAC<SHA256>.authenticationCode(for: dataData, using: symmetricKey)
        return Data(hmac)
    }
    
    /// HMAC-SHA256 (with Data key)
    private func hmacSha256(data: String, keyData: Data) -> Data {
        let dataData = Data(data.utf8)
        let symmetricKey = SymmetricKey(data: keyData)
        let hmac = HMAC<SHA256>.authenticationCode(for: dataData, using: symmetricKey)
        return Data(hmac)
    }

    /// HMAC-SHA256 (Hex)
    private func hmacSha256Hex(data: String, key: String) -> String {
        let hmacData = hmacSha256(data: data, key: key)
        return hmacData.map { String(format: "%02x", $0) }.joined()
    }
    
    /// HMAC-SHA256 (Hex, with Data key)
    private func hmacSha256Hex(data: String, keyData: Data) -> String {
        let hmacData = hmacSha256(data: data, keyData: keyData)
        return hmacData.map { String(format: "%02x", $0) }.joined()
    }

    private func performRequest<T: Encodable>(
        url: String,
        method: String,
        headers: [String: String],
        body: T?
    ) async throws -> (Data, URLResponse) {
        guard let url = URL(string: url) else {
            print("❌ Invalid URL: \(url)")
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.timeoutInterval = 120.0 // 120秒超时（DeepSeek API可能需要更长时间）

        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }

        if let body = body {
            let encoder = JSONEncoder()
            request.httpBody = try encoder.encode(body)
        }

        // 添加重试机制（最多重试2次）
        var lastError: Error?
        for attempt in 1...3 {
            do {
                let (data, response) = try await URLSession.shared.data(for: request)
                return (data, response)
            } catch {
                lastError = error
                if attempt < 3 {
                    let delay = Double(attempt) * 2.0 // 2秒、4秒延迟
                    print("⚠️ Request failed (attempt \(attempt)/3), retrying in \(Int(delay))s...")
                    try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                }
            }
        }
        
        // 所有重试都失败
        if let error = lastError {
            print("❌ Network error after 3 attempts: \(error.localizedDescription)")
            throw APIError.networkError(error.localizedDescription)
        }
        throw APIError.networkError("Unknown network error")
    }
    
    // MARK: - 智能解析辅助函数
    
    /// 智能提取JSON（简化版 - 只处理基本格式，快速）
    private func extractJSON(from content: String) -> String {
        var jsonString = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !jsonString.isEmpty else { return jsonString }
        
        // 只移除markdown代码块标记（最常见的格式）
        if jsonString.hasPrefix("```json") && jsonString.count >= 7 {
            jsonString = String(jsonString.dropFirst(7))
        } else if jsonString.hasPrefix("```") && jsonString.count >= 3 {
            jsonString = String(jsonString.dropFirst(3))
        }
        if jsonString.hasSuffix("```") && jsonString.count >= 3 {
            jsonString = String(jsonString.dropLast(3))
        }
        jsonString = jsonString.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // 提取第一个JSON对象（简单快速，避免复杂的索引操作）
        // 如果字符串已经是JSON格式，直接返回
        if jsonString.hasPrefix("{") && jsonString.hasSuffix("}") {
            return jsonString
        }
        
        // 否则尝试提取JSON对象
        if let jsonStart = jsonString.firstIndex(of: "{"),
           let jsonEnd = jsonString.lastIndex(of: "}"),
           jsonStart <= jsonEnd {
            return String(jsonString[jsonStart...jsonEnd]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        return jsonString.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    /// 尝试修复JSON（简化版 - 只修复最常见的问题）
    private func tryFixJSON(_ jsonString: String) -> String? {
        var fixed = jsonString
        
        // 只修复末尾多余的逗号（最常见的问题）
        fixed = fixed.replacingOccurrences(of: ",}", with: "}")
        fixed = fixed.replacingOccurrences(of: ",]", with: "]")
        
        // 验证修复后的JSON是否有效
        if let jsonData = fixed.data(using: .utf8),
           let _ = try? JSONSerialization.jsonObject(with: jsonData, options: []) {
            return fixed
        }
        
        return nil
    }
    
    /// 智能提取中文视觉指示词（简化版 - 只移除基本标记）
    private func extractVisualPrompt(from content: String) -> String {
        var prompt = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !prompt.isEmpty else { return prompt }
        
        // 只移除markdown代码块（最常见的格式）
        if prompt.hasPrefix("```") {
            let lines = prompt.components(separatedBy: .newlines)
            if lines.count > 2 {
                prompt = lines.dropFirst().dropLast().joined(separator: "\n")
            } else if lines.count == 1 {
                prompt = prompt.replacingOccurrences(of: "```", with: "")
            }
            prompt = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        // 只移除最常见的前缀（减少循环次数）
        let commonPrefixes = ["提示词：", "视觉指示词：", "Prompt：", "Prompt:"]
        for prefix in commonPrefixes {
            if prompt.count >= prefix.count && prompt.hasPrefix(prefix) {
                prompt = String(prompt.dropFirst(prefix.count)).trimmingCharacters(in: .whitespacesAndNewlines)
                break // 只处理第一个匹配的
            }
        }
        
        return prompt.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    /// 验证和优化视觉指示词（简化版）
    private func validateVisualPrompt(_ prompt: String) -> String {
        var validated = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // 只检查长度，如果太长就截断（不尝试在句号处截断，太慢）
        if validated.count > 200 {
            validated = String(validated.prefix(200))
        }
        
        // 确保以句号结尾（如果内容完整）
        if !validated.hasSuffix("。") && !validated.hasSuffix(".") && validated.count > 10 {
            validated += "。"
        }
        
        return validated
    }
}

// MARK: - Request/Response Models

struct AnalyzeDreamRequestBody: Codable {
    let model: String
    let messages: [Message]
    let temperature: Double
}

struct GeneratePromptRequestBody: Codable {
    let model: String
    let messages: [Message]
    let temperature: Double
}

struct Message: Codable {
    let role: String
    let content: String
}

struct DeepSeekResponse: Codable {
    let choices: [Choice]
}

struct Choice: Codable {
    let message: Message
}

// 腾讯混元API相关模型
struct HunyuanRequestBody: Codable {
    let Model: String
    let Messages: [HunyuanMessage]
    let Temperature: Double?
    let Stream: Bool?
    let TopP: Double?
    let MaxTokens: Int?
}

struct HunyuanMessage: Codable {
    let Role: String
    let Content: String
    let Name: String?
}

// 腾讯混元API响应模型
struct HunyuanResponse: Codable {
    let Response: HunyuanResponseData
}

struct HunyuanResponseData: Codable {
    let RequestId: String
    let Usage: HunyuanUsage?
    let Choices: [HunyuanChoice]?
    let Error: HunyuanError?
}

struct HunyuanUsage: Codable {
    let PromptTokens: Int
    let CompletionTokens: Int
    let TotalTokens: Int
}

struct HunyuanChoice: Codable {
    let Message: HunyuanResponseMessage
    let FinishReason: String?
    let Index: Int?
}

struct HunyuanResponseMessage: Codable {
    let Role: String
    let Content: String
}

struct HunyuanError: Codable {
    let Code: String
    let Message: String
}

enum APIError: LocalizedError {
    case invalidURL
    case invalidResponse
    case authenticationFailed
    case insufficientBalance
    case rateLimited
    case serverError
    case generationFailed(String) // 支持传递错误消息
    case timeout
    case parsingFailed(String)
    case networkError(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid API URL"
        case .invalidResponse:
            return "Invalid API response. Please check your network connection."
        case .authenticationFailed:
            return "API authentication failed. Please check API keys."
        case .insufficientBalance:
            return "API account balance insufficient. Please recharge your DeepSeek account."
        case .rateLimited:
            return "API rate limit exceeded. Please try again later."
        case .serverError:
            return "Server error. Please try again later."
        case .generationFailed(let message):
            return "3D model generation failed: \(message)"
        case .timeout:
            return "Request timeout. Please check your network connection."
        case .parsingFailed(let details):
            return "Failed to parse response: \(details)"
        case .networkError(let details):
            return "Network error: \(details)"
        }
    }
}