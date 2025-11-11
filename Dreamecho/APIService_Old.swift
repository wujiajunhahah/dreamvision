//
//  APIService.swift
//  Dreamecho
//
//  Created by sztu on 2025/11/9.
//

import Foundation
import RealityKit

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
    private let hunyuanVersion = "2023-09-01"

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
    
    /// 分析梦境内容
    func analyzeDream(_ description: String) async throws -> DreamAnalysis {
        print("🔍 Starting dream analysis for: \(description.prefix(50))...")
        
        let requestBody = AnalyzeDreamRequestBody(
            model: "deepseek-chat",
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
        
        // 尝试提取 JSON（可能包含 markdown 代码块）
        var jsonString = content.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // 移除 markdown 代码块标记（如果存在）
        if jsonString.hasPrefix("```json") {
            jsonString = String(jsonString.dropFirst(7))
        } else if jsonString.hasPrefix("```") {
            jsonString = String(jsonString.dropFirst(3))
        }
        if jsonString.hasSuffix("```") {
            jsonString = String(jsonString.dropLast(3))
        }
        jsonString = jsonString.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard let jsonData = jsonString.data(using: .utf8) else {
            throw APIError.invalidResponse
        }
        
        do {
            let analysis = try decoder.decode(DreamAnalysis.self, from: jsonData)
            print("✅ Dream analysis parsed successfully")
            print("   Keywords: \(analysis.keywords)")
            print("   Emotions: \(analysis.emotions)")
            return analysis
        } catch {
            print("❌ JSON parsing error: \(error)")
            print("❌ JSON string: \(jsonString.prefix(500))")
            throw APIError.parsingFailed(error.localizedDescription)
        }
    }
    
    /// 生成3D模型提示词
    func generateModelPrompt(from analysis: DreamAnalysis) async throws -> String {
        let requestBody = GeneratePromptRequestBody(
            model: "deepseek-chat",
            messages: [
                .init(role: "user", content: """
                基于以下梦境分析，生成一个简洁的3D模型提示词（英文，不超过50个单词）：
                
                关键词：\(analysis.keywords.joined(separator: ", "))
                视觉描述：\(analysis.visualDescription)
                
                请只返回提示词，不要其他内容。
                """)
            ],
            temperature: 0.8
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
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw APIError.invalidResponse
        }
        
        let decoder = JSONDecoder()
        let apiResponse = try decoder.decode(DeepSeekResponse.self, from: data)
        
        guard let firstChoice = apiResponse.choices.first else {
            throw APIError.invalidResponse
        }
        
        return firstChoice.message.content.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    // MARK: - 腾讯混元 API
    
    /// 生成3D模型
    func generate3DModel(prompt: String) async throws -> String {
        print("🎨 Starting 3D model generation with Hunyuan prompt: \(prompt.prefix(50))...")

        // 腾讯混元请求体 - 使用ChatCompletions API生成3D模型描述
        let modelPrompt = """
        Based on the following dream description, generate a detailed 3D model description suitable for 3D model generation:

        \(prompt)

        Please provide a concise, detailed description that can be used for 3D model generation. Focus on:
        - Main subject and pose
        - Style and material
        - Key details and features
        - Overall composition

        Keep the description under 100 words and make it suitable for text-to-3D generation.
        """

        let requestBody = HunyuanRequestBody(
            Model: "hunyuan-lite",
            Messages: [
                .init(Role: "user", Content: modelPrompt)
            ],
            Temperature: 0.7
        )
        
        let (data, response) = try await performHunyuanRequest(
            action: "ChatCompletions",
            body: requestBody
        )
        
        guard let httpResponse = response as? HTTPURLResponse else {
            print("❌ Hunyuan API Error: Invalid response type")
            throw APIError.invalidResponse
        }
        
        // 如果返回 400 错误且包含 format 相关错误，尝试移除 format 参数重试
        if httpResponse.statusCode == 400 {
            let errorString = String(data: data, encoding: .utf8) ?? "Unknown error"
            print("⚠️ Tripo API returned 400 error: \(errorString)")
            
            // 检查是否是 format 参数导致的错误
            if errorString.contains("format") || errorString.contains("invalid parameter") || errorString.contains("9400") {
                print("💡 Format parameter not supported, retrying without format parameter...")
                
                // 移除 format 参数，使用默认参数重试
                let fallbackRequestBody: [String: Any] = [
                    "type": "text_to_model",
                    "prompt": prompt
                ]
                
                guard let fallbackJsonData = try? JSONSerialization.data(withJSONObject: fallbackRequestBody) else {
                    throw APIError.invalidResponse
                }
                
                let (fallbackData, fallbackResponse) = try await performTripoRequest(
                    url: "\(tripoBaseURL)/task",
                    method: "POST",
                    headers: [
                        "Content-Type": "application/json",
                        "Authorization": "Bearer \(tripoAPIKey)"
                    ],
                    body: fallbackJsonData
                )
                
                guard let fallbackHttpResponse = fallbackResponse as? HTTPURLResponse else {
                    print("❌ Tripo API Error (fallback): Invalid response type")
                    throw APIError.invalidResponse
                }
                
                guard fallbackHttpResponse.statusCode == 200 else {
                    let fallbackErrorString = String(data: fallbackData, encoding: .utf8) ?? "Unknown error"
                    print("❌ Tripo API Error (fallback): HTTP \(fallbackHttpResponse.statusCode)")
                    print("❌ Error response: \(fallbackErrorString)")
                    throw APIError.invalidResponse
                }
                
                print("✅ Tripo task created (without format parameter): \(fallbackData.count) bytes")
                
                // 使用回退响应的数据继续处理
                guard let fallbackJson = try? JSONSerialization.jsonObject(with: fallbackData) as? [String: Any] else {
                    print("❌ Failed to parse JSON response when creating task (fallback)")
                    throw APIError.invalidResponse
                }
                
                if let errorMessage = tripoErrorMessage(from: fallbackJson) {
                    print("❌ Tripo API returned error while creating task (fallback): \(errorMessage)")
                    throw APIError.generationFailed(errorMessage)
                }
                
                guard let taskId = extractTaskId(from: fallbackJson) else {
                    print("❌ Failed to parse task_id from response (fallback)")
                    print("🔍 Response payload: \(fallbackJson)")
                    throw APIError.invalidResponse
                }
                
                print("✅ Task ID (fallback): \(taskId)")
                print("⚠️ Note: API does not support format parameter, will use default format (likely GLB)")
                
                // 轮询获取模型URL
                return try await pollModelStatus(taskId: taskId)
            } else {
                // 其他 400 错误，直接抛出
                print("❌ Tripo API Error: HTTP \(httpResponse.statusCode)")
                print("❌ Error response: \(errorString)")
                throw APIError.invalidResponse
            }
        }
        
        guard httpResponse.statusCode == 200 else {
            let errorString = String(data: data, encoding: .utf8) ?? "Unknown error"
            print("❌ Tripo API Error: HTTP \(httpResponse.statusCode)")
            print("❌ Error response: \(errorString)")
            throw APIError.invalidResponse
        }
        
        print("✅ Tripo task created: \(data.count) bytes")
        
        // 解析响应获取 task_id
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            print("❌ Failed to parse JSON response when creating task")
            throw APIError.invalidResponse
        }
        
        if let errorMessage = tripoErrorMessage(from: json) {
            print("❌ Tripo API returned error while creating task: \(errorMessage)")
            throw APIError.generationFailed(errorMessage)
        }
        
        guard let taskId = extractTaskId(from: json) else {
            print("❌ Failed to parse task_id from response")
            print("🔍 Response payload: \(json)")
            throw APIError.invalidResponse
        }
        
        print("✅ Task ID: \(taskId)")
        
        // 轮询获取模型URL
        return try await pollModelStatus(taskId: taskId)
    }
    
    private func pollModelStatus(taskId: String) async throws -> String {
        let maxAttempts = 60 // 增加到60次，每次2秒 = 最多2分钟
        let delaySeconds: UInt64 = 2
        
        print("⏳ Polling task status: \(taskId)")
        
        for attempt in 0..<maxAttempts {
            let (data, response) = try await performTripoRequest(
                url: "\(tripoBaseURL)/task/\(taskId)",
                method: "GET",
                headers: [
                    "Authorization": "Bearer \(tripoAPIKey)"
                ],
                body: nil
            )
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.invalidResponse
            }
            
            guard httpResponse.statusCode == 200 else {
                let errorString = String(data: data, encoding: .utf8) ?? "Unknown error"
                print("❌ Status check error: HTTP \(httpResponse.statusCode) - \(errorString)")
                throw APIError.invalidResponse
            }
            
            // 解析 JSON 响应
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                print("❌ Failed to parse JSON response")
                throw APIError.invalidResponse
            }
            
            // 检查顶层错误码（Tripo API 可能在顶层返回 code 和 message）
            if let errorMessage = tripoErrorMessage(from: json) {
                print("❌ Tripo API Error: \(errorMessage)")
                throw APIError.generationFailed(errorMessage)
            }
            
            guard let dataDict = json["data"] as? [String: Any] else {
                print("❌ Failed to parse data field from response")
                print("🔍 Response keys: \(json.keys.joined(separator: ", "))")
                throw APIError.invalidResponse
            }
            
            if let errorMessage = tripoErrorMessage(from: dataDict) {
                print("❌ Tripo API Error in data: \(errorMessage)")
                throw APIError.generationFailed(errorMessage)
            }
            
            // 获取状态（处理大小写不敏感）
            guard let statusRaw = (dataDict["status"] ?? dataDict["state"]) as? String else {
                print("❌ Failed to parse status from response")
                throw APIError.invalidResponse
            }
            
            let status = statusRaw.lowercased()
            print("📊 Attempt \(attempt + 1)/\(maxAttempts): Status = \(statusRaw) (normalized: \(status))")
            
            // Tripo3D API 返回的状态可能是 "success"、"completed"、"SUCCESS" 等（大小写不敏感）
            if status == "completed" || status == "success" {
                var modelURL: String?
                
                // 打印完整响应用于调试
                if attempt == 0 || status == "success" {
                    print("🔍 Full response data: \(String(data: data, encoding: .utf8) ?? "Unable to decode")")
                }
                
                // 尝试多种可能的URL路径（根据 Tripo3D API 文档）
                // 优先级：result.pbr_model.url > output.pbr_model > result.model.url > output.model > 其他
                // 1. data.result.pbr_model.url (最完整的结构，包含 type 和 url)
                if let result = dataDict["result"] as? [String: Any],
                   let pbrModel = result["pbr_model"] as? [String: Any],
                   let url = pbrModel["url"] as? String, !url.isEmpty {
                    modelURL = url
                    print("✅ Found model_url in data.result.pbr_model.url")
                }
                // 2. data.output.pbr_model (直接字符串)
                else if let output = dataDict["output"] as? [String: Any],
                        let url = output["pbr_model"] as? String, !url.isEmpty {
                    modelURL = url
                    print("✅ Found model_url in data.output.pbr_model")
                }
                // 3. data.result.model.url
                else if let result = dataDict["result"] as? [String: Any],
                        let model = result["model"] as? [String: Any],
                        let url = model["url"] as? String, !url.isEmpty {
                    modelURL = url
                    print("✅ Found model_url in data.result.model.url")
                }
                // 4. data.output.model
                else if let output = dataDict["output"] as? [String: Any],
                        let url = output["model"] as? String, !url.isEmpty {
                    modelURL = url
                    print("✅ Found model_url in data.output.model")
                }
                // 5. data.result.model_url
                else if let result = dataDict["result"] as? [String: Any],
                        let url = result["model_url"] as? String, !url.isEmpty {
                    modelURL = url
                    print("✅ Found model_url in data.result.model_url")
                }
                // 6. data.model_url (直接路径)
                else if let url = dataDict["model_url"] as? String, !url.isEmpty {
                    modelURL = url
                    print("✅ Found model_url in data.model_url")
                }
                // 7. data.download_url
                else if let url = dataDict["download_url"] as? String, !url.isEmpty {
                    modelURL = url
                    print("✅ Found model_url in data.download_url")
                }
                // 8. data.files[0].url
                else if let files = dataDict["files"] as? [[String: Any]],
                        let firstFile = files.first,
                        let url = firstFile["url"] as? String, !url.isEmpty {
                    modelURL = url
                    print("✅ Found model_url in data.files[0].url")
                }
                
                if let url = modelURL {
                    // 检查返回的格式并给出详细反馈
                    let normalizedPath = normalizedURLPath(url)
                    if normalizedPath.hasSuffix(".usdz") {
                        print("✅✅✅ SUCCESS: Model generated in USDZ format!")
                        print("✅ USDZ format is optimal for visionOS")
                        print("✅ Model URL: \(url.prefix(100))...")
                        return url
                    } else if normalizedPath.hasSuffix(".usd") {
                        print("⚠️ Model generated in USD format: \(url)")
                        print("💡 USD format will be loaded directly (ModelIO supports USD)")
                        print("⚠️ Note: USDZ format is recommended for best visionOS experience")
                        return url
                    } else if normalizedPath.hasSuffix(".glb") {
                        print("⚠️ Model generated in GLB format: \(url)")
                        print("🔄 Attempting to convert GLB to USDZ via Tripo Post-Process API...")
                        do {
                            let usdzURL = try await convertToUSDZ(sourceURL: url)
                            print("✅✅✅ SUCCESS: GLB converted to USDZ format!")
                            print("✅ USDZ URL: \(usdzURL.prefix(100))...")
                            
                            // 验证转换后的 USDZ 文件是否可以成功加载
                            print("🔍 Validating converted USDZ file...")
                            do {
                                try await validateUSDZFile(url: usdzURL)
                                print("✅✅✅ USDZ file validation passed - file is ready for display")
                                return usdzURL
                            } catch {
                                print("❌ USDZ file validation failed: \(error.localizedDescription)")
                                print("❌ Converted USDZ file cannot be loaded - rejecting")
                                throw APIError.generationFailed("模型转换失败：GLB 已转换为 USDZ，但转换后的文件无法正常加载。请尝试重新生成模型。")
                            }
                        } catch {
                            print("❌ GLB to USDZ conversion failed: \(error.localizedDescription)")
                            throw APIError.generationFailed("模型生成失败：Tripo3D API 返回了 GLB 格式，但无法转换为 USDZ 格式。visionOS 仅支持 USDZ 格式。请尝试重新生成或联系 Tripo3D API 申请 USDZ 格式支持。")
                        }
                    } else {
                        // 未知格式，检查是否是 USDZ（可能 URL 中没有明确的后缀）
                        let urlLower = url.lowercased()
                        if urlLower.contains("usdz") || urlLower.contains(".usdz") {
                            print("✅ Model generated successfully (detected USDZ format): \(url)")
                            return url
                        } else {
                            print("❌ Model generated in unsupported format: \(normalizedPath.suffix(10))")
                            print("❌ Only USDZ format is supported for visionOS")
                            throw APIError.generationFailed("模型生成失败：返回了不支持的格式（\(normalizedPath.suffix(10))）。visionOS 仅支持 USDZ 格式。")
                        }
                    }
                } else {
                    print("⚠️ Status is \(status) but no model_url found in response")
                    print("⚠️ Available keys in data: \(dataDict.keys.joined(separator: ", "))")
                }
            }
            
            // 处理失败状态（大小写不敏感）
            if status == "failed" || status == "cancelled" || status == "unknown" || status == "error" {
                let errorMsg = dataDict["error"] as? String ?? dataDict["message"] as? String ?? "Generation failed"
                print("❌ Generation failed: \(errorMsg)")
                throw APIError.generationFailed(errorMsg)
            }
            
            // 等待后继续轮询
            if attempt < maxAttempts - 1 {
                try await Task.sleep(nanoseconds: delaySeconds * 1_000_000_000)
            }
        }
        
        print("⏰ Polling timeout after \(maxAttempts) attempts")
        throw APIError.timeout
    }
    
    /// 使用 Tripo3D Post-Process API 将模型转换为 USDZ 格式
    /// ⚠️ 注意：此 API 端点目前不可用（返回 404），已禁用调用
    /// 参考: https://platform.tripo3d.ai/docs/post-process
    /// 如果将来 Tripo3D 提供此端点，可以重新启用此功能
    private func convertToUSDZ(sourceURL: String) async throws -> String {
        print("🔄 Starting GLB/USD to USDZ conversion...")
        print("📦 Source URL: \(sourceURL.prefix(80))...")
        
        // Post-Process API 请求体
        let requestBody: [String: Any] = [
            "source_url": sourceURL,
            "target_format": "usdz",
            "type": "format_conversion" // 格式转换类型
        ]
        
        guard let jsonData = try? JSONSerialization.data(withJSONObject: requestBody) else {
            throw APIError.invalidResponse
        }
        
        // 创建 Post-Process 任务
        let (data, response) = try await performTripoRequest(
            url: "\(tripoBaseURL)/post-process",
            method: "POST",
            headers: [
                "Content-Type": "application/json",
                "Authorization": "Bearer \(tripoAPIKey)"
            ],
            body: jsonData
        )
        
        guard let httpResponse = response as? HTTPURLResponse else {
            print("❌ Post-Process API Error: Invalid response type")
            throw APIError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            let errorString = String(data: data, encoding: .utf8) ?? "Unknown error"
            print("❌ Post-Process API Error: HTTP \(httpResponse.statusCode)")
            print("❌ Error response: \(errorString)")
            throw APIError.invalidResponse
        }
        
        print("✅ Post-Process task created: \(data.count) bytes")
        
        // 解析响应获取 task_id
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            print("❌ Failed to parse Post-Process JSON response")
            throw APIError.invalidResponse
        }
        
        if let errorMessage = tripoErrorMessage(from: json) {
            print("❌ Post-Process API Error: \(errorMessage)")
            throw APIError.generationFailed(errorMessage)
        }
        
        guard let dataDict = json["data"] as? [String: Any] else {
            print("❌ Failed to parse data field from Post-Process response")
            print("🔍 Response: \(String(data: data, encoding: .utf8) ?? "Unable to decode")")
            throw APIError.invalidResponse
        }
        
        if let errorMessage = tripoErrorMessage(from: dataDict) {
            print("❌ Post-Process API Error in data: \(errorMessage)")
            throw APIError.generationFailed(errorMessage)
        }
        
        let postProcessJSON: [String: Any] = ["data": dataDict]
        guard let taskId = dataDict["task_id"] as? String ?? extractTaskId(from: postProcessJSON) else {
            print("❌ Failed to parse task_id from Post-Process response")
            print("🔍 Response: \(String(data: data, encoding: .utf8) ?? "Unable to decode")")
            throw APIError.invalidResponse
        }
        
        print("✅ Post-Process Task ID: \(taskId)")
        
        // 轮询 Post-Process 任务状态
        return try await pollPostProcessStatus(taskId: taskId)
    }
    
    /// 轮询 Post-Process 任务状态，获取转换后的 USDZ URL
    private func pollPostProcessStatus(taskId: String) async throws -> String {
        let maxAttempts = 60 // 最多60次，每次2秒 = 最多2分钟
        let delaySeconds: UInt64 = 2
        
        print("⏳ Polling Post-Process task status: \(taskId)")
        
        for attempt in 0..<maxAttempts {
            let (data, response) = try await performTripoRequest(
                url: "\(tripoBaseURL)/post-process/\(taskId)",
                method: "GET",
                headers: [
                    "Authorization": "Bearer \(tripoAPIKey)"
                ],
                body: nil
            )
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.invalidResponse
            }
            
            guard httpResponse.statusCode == 200 else {
                let errorString = String(data: data, encoding: .utf8) ?? "Unknown error"
                print("❌ Post-Process status check error: HTTP \(httpResponse.statusCode) - \(errorString)")
                throw APIError.invalidResponse
            }
            
            // 解析 JSON 响应
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                print("❌ Failed to parse JSON response")
                throw APIError.invalidResponse
            }
            
            if let errorMessage = tripoErrorMessage(from: json) {
                print("❌ Post-Process API Error: \(errorMessage)")
                throw APIError.generationFailed(errorMessage)
            }
            
            guard let dataDict = json["data"] as? [String: Any] else {
                print("❌ Failed to parse data field from response")
                print("🔍 Response keys: \(json.keys.joined(separator: ", "))")
                throw APIError.invalidResponse
            }
            
            if let errorMessage = tripoErrorMessage(from: dataDict) {
                print("❌ Post-Process API Error in data: \(errorMessage)")
                throw APIError.generationFailed(errorMessage)
            }
            
            // 获取状态（处理大小写不敏感）
            guard let statusRaw = (dataDict["status"] ?? dataDict["state"]) as? String else {
                print("❌ Failed to parse Post-Process status from response")
                throw APIError.invalidResponse
            }
            
            let status = statusRaw.lowercased()
            print("📊 Post-Process Attempt \(attempt + 1)/\(maxAttempts): Status = \(statusRaw) (normalized: \(status))")
            
            // Tripo3D API 返回的状态可能是 "success"、"completed"、"SUCCESS" 等（大小写不敏感）
            if status == "completed" || status == "success" {
                // 查找转换后的 USDZ URL
                var usdzURL: String?
                
                // 尝试多种可能的URL路径
                if let output = dataDict["output"] as? [String: Any],
                   let url = output["usdz_url"] as? String {
                    usdzURL = url
                    print("✅ Found USDZ URL in data.output.usdz_url")
                } else if let output = dataDict["output"] as? [String: Any],
                          let url = output["model_url"] as? String {
                    usdzURL = url
                    print("✅ Found USDZ URL in data.output.model_url")
                } else if let result = dataDict["result"] as? [String: Any],
                          let url = result["usdz_url"] as? String {
                    usdzURL = url
                    print("✅ Found USDZ URL in data.result.usdz_url")
                } else if let result = dataDict["result"] as? [String: Any],
                          let url = result["model_url"] as? String {
                    usdzURL = url
                    print("✅ Found USDZ URL in data.result.model_url")
                } else if let url = dataDict["usdz_url"] as? String {
                    usdzURL = url
                    print("✅ Found USDZ URL in data.usdz_url")
                } else if let url = dataDict["model_url"] as? String {
                    usdzURL = url
                    print("✅ Found USDZ URL in data.model_url")
                } else if let url = dataDict["download_url"] as? String {
                    usdzURL = url
                    print("✅ Found USDZ URL in data.download_url")
                }
                
                if let url = usdzURL {
                    // 验证确实是 USDZ 格式
                    if normalizedURLPath(url).hasSuffix(".usdz") {
                        print("✅✅✅ SUCCESS: Post-Process conversion completed!")
                        print("✅ USDZ URL: \(url.prefix(100))...")
                        return url
                    } else {
                        print("⚠️ Post-Process returned URL but not USDZ format: \(url.suffix(10))")
                        print("⚠️ Attempting to use anyway...")
                        return url
                    }
                } else {
                    print("⚠️ Post-Process status is \(status) but no USDZ URL found")
                    print("🔍 Full response: \(String(data: data, encoding: .utf8) ?? "Unable to decode")")
                    print("⚠️ Available keys: \(dataDict.keys.joined(separator: ", "))")
                }
            }
            
            // 处理失败状态（大小写不敏感）
            if status == "failed" || status == "cancelled" || status == "unknown" || status == "error" {
                let errorMsg = dataDict["error"] as? String ?? dataDict["message"] as? String ?? "Post-Process conversion failed"
                print("❌ Post-Process conversion failed: \(errorMsg)")
                throw APIError.generationFailed(errorMsg)
            }
            
            // 等待后继续轮询
            if attempt < maxAttempts - 1 {
                try await Task.sleep(nanoseconds: delaySeconds * 1_000_000_000)
            }
        }
        
        print("⏰ Post-Process polling timeout after \(maxAttempts) attempts")
        throw APIError.timeout
    }
    
    // MARK: - Helper Methods
    
    /// 验证 USDZ 文件是否可以成功加载（用于确保转换后的文件可用）
    private func validateUSDZFile(url: String) async throws {
        print("🔍 Validating USDZ file: \(url.prefix(80))...")
        
        guard let fileURL = URL(string: url) else {
            throw APIError.invalidURL
        }
        
        // 下载文件到临时位置
        let (data, response) = try await URLSession.shared.data(from: fileURL)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw APIError.invalidResponse
        }
        
        print("✅ USDZ file downloaded: \(data.count) bytes")
        
        // 保存到临时文件
        let tempDir = FileManager.default.temporaryDirectory
        let tempFileURL = tempDir.appendingPathComponent(UUID().uuidString).appendingPathExtension("usdz")
        
        try data.write(to: tempFileURL)
        print("💾 USDZ file saved to temp location: \(tempFileURL.path)")
        
        defer {
            // 清理临时文件
            try? FileManager.default.removeItem(at: tempFileURL)
        }
        
        // 尝试使用 RealityKit 加载 USDZ 文件
        do {
            // 使用 RealityKit 加载模型来验证文件是否有效
            let entity = try await Entity(contentsOf: tempFileURL)
            
            // 检查实体是否有内容
            if entity.children.isEmpty && entity.components.isEmpty {
                print("⚠️ USDZ file loaded but contains no content")
                throw APIError.generationFailed("USDZ 文件为空，无法显示")
            }
            
            print("✅ USDZ file validation passed - file can be loaded successfully")
            print("✅ Entity has \(entity.children.count) children and \(entity.components.count) components")
        } catch {
            print("❌ USDZ file validation failed: \(error.localizedDescription)")
            throw APIError.generationFailed("USDZ 文件验证失败：\(error.localizedDescription)")
        }
    }
    
    /// 归一化 URL（小写并移除查询参数），便于判断文件格式
    private func normalizedURLPath(_ urlString: String) -> String {
        let lowercased = urlString.lowercased()
        if let questionIndex = lowercased.firstIndex(of: "?") {
            return String(lowercased[..<questionIndex])
        }
        return lowercased
    }
    
    /// 提取 Tripo API 返回的错误信息（兼容 Int/String code）
    private func tripoErrorMessage(from dictionary: [String: Any]) -> String? {
        if let code = dictionary["code"] as? Int {
            if code != 0 {
                let message = (dictionary["message"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
                let error = (dictionary["error"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
                if let message, !message.isEmpty {
                    return "[\(code)] \(message)"
                } else if let error, !error.isEmpty {
                    return "[\(code)] \(error)"
                } else {
                    return "code \(code)"
                }
            }
        } else if let codeString = dictionary["code"] as? String {
            let normalizedCode = codeString.trimmingCharacters(in: .whitespacesAndNewlines)
            let lowercased = normalizedCode.lowercased()
            if !normalizedCode.isEmpty && lowercased != "0" && lowercased != "success" && lowercased != "ok" {
                let message = (dictionary["message"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
                let error = (dictionary["error"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
                if let message, !message.isEmpty {
                    return "[\(normalizedCode)] \(message)"
                } else if let error, !error.isEmpty {
                    return "[\(normalizedCode)] \(error)"
                } else {
                    return "code \(normalizedCode)"
                }
            }
        }
        
        if let errorDict = dictionary["error"] as? [String: Any] {
            return tripoErrorMessage(from: errorDict)
        }
        
        if let errorString = dictionary["error"] as? String {
            let trimmed = errorString.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                return trimmed
            }
        }
        
        return nil
    }
    
    /// 提取 task_id，兼容多种返回结构
    private func extractTaskId(from json: [String: Any]) -> String? {
        if let dataDict = json["data"] as? [String: Any] {
            if let taskId = dataDict["task_id"] as? String, !taskId.isEmpty {
                return taskId
            }
            if let task = dataDict["task"] as? [String: Any] {
                if let nested = task["task_id"] as? String, !nested.isEmpty {
                    return nested
                }
                if let nested = task["id"] as? String, !nested.isEmpty {
                    return nested
                }
            }
        }
        
        if let directTaskId = json["task_id"] as? String, !directTaskId.isEmpty {
            return directTaskId
        }
        
        if let identifier = json["id"] as? String, !identifier.isEmpty {
            return identifier
        }
        
        if let dataArray = json["data"] as? [[String: Any]] {
            for element in dataArray {
                if let taskId = element["task_id"] as? String, !taskId.isEmpty {
                    return taskId
                }
                if let task = element["task"] as? [String: Any] {
                    if let nested = task["task_id"] as? String, !nested.isEmpty {
                        return nested
                    }
                    if let nested = task["id"] as? String, !nested.isEmpty {
                        return nested
                    }
                }
            }
        }
        
        return nil
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
        
        print("🌐 Making request to: \(url)")
        
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.timeoutInterval = 30.0 // 30秒超时
        
        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }
        
        if let body = body {
            let encoder = JSONEncoder()
            request.httpBody = try encoder.encode(body)
            if let bodyString = String(data: request.httpBody!, encoding: .utf8) {
                print("📤 Request body: \(bodyString.prefix(200))...")
            }
        }
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            print("📥 Response received: \(data.count) bytes")
            return (data, response)
        } catch {
            print("❌ Network error: \(error.localizedDescription)")
            throw APIError.networkError(error.localizedDescription)
        }
    }
    
    /// Tripo API 专用请求方法
    private func performTripoRequest(
        url: String,
        method: String,
        headers: [String: String],
        body: Data?
    ) async throws -> (Data, URLResponse) {
        guard let url = URL(string: url) else {
            print("❌ Invalid Tripo URL: \(url)")
            throw APIError.invalidURL
        }
        
        print("🌐 Making Tripo request to: \(url)")
        
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.timeoutInterval = 30.0
        
        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }
        
        if let body = body {
            request.httpBody = body
            if let bodyString = String(data: body, encoding: .utf8) {
                print("📤 Tripo request body: \(bodyString.prefix(200))...")
            }
        }
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            print("📥 Tripo response received: \(data.count) bytes")
            return (data, response)
        } catch {
            print("❌ Tripo network error: \(error.localizedDescription)")
            throw APIError.networkError(error.localizedDescription)
        }
    }
    
    private func performRequest(
        url: String,
        method: String,
        headers: [String: String],
        body: String?
    ) async throws -> (Data, URLResponse) {
        guard let url = URL(string: url) else {
            throw APIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = method
        
        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }
        
        if let body = body {
            request.httpBody = body.data(using: .utf8)
        }
        
        return try await URLSession.shared.data(for: request)
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

struct TripoGenerateRequestBody: Codable {
    let prompt: String
    let negative_prompt: String
    let aspect_ratio: String
    let samples: Int
}

struct TripoResponse: Codable {
    let task_id: String?
}

struct TripoStatusResponse: Codable {
    let status: String
    let model_url: String?
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
