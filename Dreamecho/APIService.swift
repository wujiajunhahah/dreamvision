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
    func generate3DModel(prompt: String, analysis: DreamAnalysis? = nil) async throws -> String {
        print("🎨 Starting 3D model generation with backend service...")

        // 使用后端代理服务进行3D生成
        let downloadURL = try await BackendAPIService.shared.generate3DModel(
            dreamDescription: prompt,
            analysis: analysis
        )

        // 写入 AppAssets/models.json 供构建期转换使用
        try await writeToModelsJSON(downloadURL: downloadURL, dreamDescription: prompt)

        return downloadURL
    }

    /// 写入 models.json 供构建期脚本使用
    private func writeToModelsJSON(downloadURL: String, dreamDescription: String) async throws {
        let modelsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            .appendingPathComponent("AppAssets")
        let modelsFile = modelsDir.appendingPathComponent("models.json")

        let modelsData: [String: Any] = [
            "models": [
                [
                    "name": "dreamecho_model",
                    "url": downloadURL,
                    "description": dreamDescription,
                    "timestamp": ISO8601DateFormatter().string(from: Date())
                ]
            ]
        ]

        // 确保目录存在
        try FileManager.default.createDirectory(at: modelsDir, withIntermediateDirectories: true)

        // 写入文件
        let jsonData = try JSONSerialization.data(withJSONObject: modelsData, options: .prettyPrinted)
        try jsonData.write(to: modelsFile)

        print("✅ Written to models.json: \(modelsFile.path)")
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
        let secretService = hmacSha256(data: service, key: secretDate)
        let secretSigning = hmacSha256(data: "tc3_request", key: secretService)
        let signature = hmacSha256Hex(data: stringToSign, key: secretSigning)

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

    /// HMAC-SHA256 (Hex)
    private func hmacSha256Hex(data: String, key: String) -> String {
        let hmacData = hmacSha256(data: data, key: key)
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