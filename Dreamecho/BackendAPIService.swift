//
//  BackendAPIService.swift
//  Dreamecho
//
//  Created by AI on 2025/11/11.
//

import Foundation
import CryptoKit

/// 腾讯混元生3D API 服务 - 直接调用腾讯混元生3D API
class BackendAPIService {
    static let shared = BackendAPIService()

    // 腾讯混元生3D API 配置
    private let secretId: String
    private let secretKey: String
    private let endpoint = "https://ai3d.tencentcloudapi.com/"
    private let region = "ap-guangzhou" // 根据官方文档，使用 ap-guangzhou
    private let service = "ai3d"
    private let version = "2025-05-13" // 根据官方文档

    private init() {
        // 从 Info.plist 读取腾讯云 API 密钥
        guard let secretId = Bundle.main.object(forInfoDictionaryKey: "TencentSecretId") as? String,
              let secretKey = Bundle.main.object(forInfoDictionaryKey: "TencentSecretKey") as? String else {
            fatalError("❌ Tencent API keys not found in Info.plist. Please add TencentSecretId and TencentSecretKey to Info.plist")
        }

        self.secretId = secretId
        self.secretKey = secretKey

        // 调试：打印 SecretId 的前几个字符（不完整显示，保护隐私）
        let maskedSecretId = secretId.prefix(8) + "..." + secretId.suffix(4)
        print("✅ Tencent Hunyuan To3D API Service initialized")
        print("🔑 SecretId: \(maskedSecretId)")
        print("🔑 SecretKey: \(secretKey.prefix(4))...\(secretKey.suffix(4))")
    }

    // MARK: - 腾讯混元生3D API 实现

    /// 提交3D模型生成任务（直接使用中文视觉指示词）
    /// 使用 SubmitHunyuanTo3DJob 接口（标准版，支持 ResultFormat 参数指定USDZ格式）
    /// 专业版（Pro）不支持格式参数，标准版支持 ResultFormat 参数
    /// 参考：https://cloud.tencent.com/document/product/1804/120826
    func submit3DGeneration(prompt: String) async throws -> String {
        print("🎨 Submitting 3D generation task to Tencent Hunyuan To3D API...")
        print("📝 Using Chinese visual prompt (direct from DeepSeek): \(prompt.prefix(100))...")

        // 构建请求体（根据腾讯混元生3D API官方文档）
        // 原生Swift实现，使用 ResultFormat 参数指定USDZ格式
        // 根据官方文档，可选值：OBJ/GLB/STL/USDZ/FBX/MP4
        // 注意：如果 USDZ 不被支持，可以尝试 GLB 然后转换
        var requestBody: [String: Any] = [
            "Prompt": prompt
        ]
        
        // 尝试使用 USDZ 格式（visionOS 原生格式）
        // 如果 API 不支持 USDZ，会返回错误，我们可以回退到 GLB
        requestBody["ResultFormat"] = "USDZ"
        requestBody["EnablePBR"] = true // 开启PBR材质生成，确保材质质量
        
        // 可选参数（根据API文档）
        // requestBody["GenerateType"] = "Normal" // Normal/LowPoly/Geometry/Sketch
        // requestBody["FaceCount"] = 500000 // 生成面数，范围40000-1500000
        
        print("📤 Requesting USDZ format (visionOS native format) using ResultFormat parameter")
        print("📤 Request body: \(requestBody)")

        guard let jsonData = try? JSONSerialization.data(withJSONObject: requestBody, options: []) else {
            throw BackendError.invalidRequest
        }

        let jsonString = String(data: jsonData, encoding: .utf8) ?? "{}"

        // 生成腾讯云API签名
        let timestamp = String(Int(Date().timeIntervalSince1970))
        let headers = try generateTencentHeaders(
            action: "SubmitHunyuanTo3DJob", // 使用标准版接口（支持 ResultFormat 参数）
            timestamp: timestamp,
            payload: jsonString
        )

        var request = URLRequest(url: URL(string: endpoint)!)
        request.httpMethod = "POST"
        request.timeoutInterval = 30.0

        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }

        request.httpBody = jsonData

        print("🌐 Making request to: \(endpoint)")
        print("📤 Action: SubmitHunyuanTo3DJob (Standard version - supports ResultFormat)")
        print("📤 Request body: \(jsonString.prefix(200))...")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw BackendError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            let errorString = String(data: data, encoding: .utf8) ?? "Unknown error"
            print("❌ Tencent API Error: HTTP \(httpResponse.statusCode)")
            print("❌ Error response: \(errorString)")
            throw BackendError.apiError(errorString)
        }

        print("📥 Response received: \(data.count) bytes")

        // 解析响应
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            print("❌ Failed to parse JSON response")
            throw BackendError.invalidResponse
        }

        // 检查是否有错误
        if let responseData = json["Response"] as? [String: Any],
           let error = responseData["Error"] as? [String: Any] {
            let errorCode = error["Code"] as? String ?? "Unknown"
            let errorMessage = error["Message"] as? String ?? "Unknown error"
            print("❌ API Error: [\(errorCode)] \(errorMessage)")
            
            // 针对 SecretId 错误的特殊提示
            if errorCode.contains("SecretId") || errorCode.contains("AuthFailure") {
                print("💡 SecretId 错误解决方案：")
                print("   1. 登录腾讯云控制台：https://console.cloud.tencent.com/")
                print("   2. 访问：访问管理 → API 密钥管理")
                print("   3. 检查 SecretId 是否存在且已启用")
                print("   4. 确认 SecretId 已开通混元生3D服务权限")
                print("   5. 如果不存在，创建新的 API 密钥并更新 Info.plist")
                print("   6. 当前使用的 SecretId: \(secretId.prefix(8))...\(secretId.suffix(4))")
            }
            
            // 针对格式参数错误的特殊提示
            if errorCode.contains("Format") || errorCode.contains("InvalidParameter") || 
               errorMessage.lowercased().contains("format") || errorMessage.lowercased().contains("格式") {
                print("💡 Format 参数错误解决方案：")
                print("   1. 检查 ResultFormat 参数值是否正确")
                print("   2. 根据官方文档，可选值：OBJ/GLB/STL/USDZ/FBX/MP4")
                print("   3. 当前使用的格式：USDZ")
                print("   4. 如果 USDZ 不被支持，可以尝试：GLB（然后转换为USDZ）")
                print("   5. 检查参数名是否正确：ResultFormat（不是 OutputFormat）")
            }
            
            throw BackendError.apiError("\(errorCode): \(errorMessage)")
        }

        // 提取任务ID（根据API文档，返回的是JobId）
        guard let responseData = json["Response"] as? [String: Any],
              let jobId = responseData["JobId"] as? String else {
            print("❌ Failed to parse JobId from response")
            print("🔍 Response: \(json)")
            throw BackendError.invalidResponse
        }

        print("✅ Task submitted successfully: \(jobId)")
        print("📋 Requested format: USDZ (visionOS native)")
        return jobId
    }

    /// 查询3D生成任务状态
    /// 使用 QueryHunyuanTo3DJob 接口（标准版，对应标准版提交接口）
    /// 参考：https://cloud.tencent.com/document/product/1804/120827
    /// 状态值：WAIT/RUN/FAIL/DONE（无官方剩余时间字段）
    func poll3DGenerationStatus(taskId: String) async throws -> BackendTaskStatus {
        print("📊 Querying task status: \(taskId)")

        // 构建请求体（根据API文档，使用JobId查询）
        let requestBody: [String: Any] = [
            "JobId": taskId
        ]

        guard let jsonData = try? JSONSerialization.data(withJSONObject: requestBody, options: []) else {
            throw BackendError.invalidRequest
        }

        let jsonString = String(data: jsonData, encoding: .utf8) ?? "{}"

        // 生成腾讯云API签名
        let timestamp = String(Int(Date().timeIntervalSince1970))
        let headers = try generateTencentHeaders(
            action: "QueryHunyuanTo3DJob", // 使用标准版查询接口（对应标准版提交接口）
            timestamp: timestamp,
            payload: jsonString
        )

        var request = URLRequest(url: URL(string: endpoint)!)
        request.httpMethod = "POST"
        request.timeoutInterval = 10.0

        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }

        request.httpBody = jsonData

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw BackendError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            let errorString = String(data: data, encoding: .utf8) ?? "Unknown error"
            print("❌ Tencent API Error: HTTP \(httpResponse.statusCode)")
            throw BackendError.apiError(errorString)
        }

        // 解析响应
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            print("❌ Failed to parse status response")
            throw BackendError.invalidResponse
        }

        // 检查是否有错误
        if let responseData = json["Response"] as? [String: Any],
           let error = responseData["Error"] as? [String: Any] {
            let errorCode = error["Code"] as? String ?? "Unknown"
            let errorMessage = error["Message"] as? String ?? "Unknown error"
            print("❌ API Error: [\(errorCode)] \(errorMessage)")
            throw BackendError.apiError("\(errorCode): \(errorMessage)")
        }

        // 解析任务状态（根据官方文档）
        guard let responseData = json["Response"] as? [String: Any] else {
            print("❌ Failed to parse status from response")
            print("🔍 Full response: \(json)")
            throw BackendError.invalidResponse
        }

        // 打印完整响应用于调试
        if let responseString = String(data: data, encoding: .utf8) {
            print("📥 Query response: \(responseString.prefix(500))")
        }

        // 映射状态（尝试多种可能的状态字段名）
        var statusString: String? = nil
        
        // 尝试不同的状态字段名
        if let status = responseData["Status"] as? String {
            statusString = status
        } else if let status = responseData["JobStatus"] as? String {
            statusString = status
        } else if let status = responseData["TaskStatus"] as? String {
            statusString = status
        } else if let status = responseData["state"] as? String {
            statusString = status
        }
        
        // 如果还是找不到，打印所有字段
        if statusString == nil {
            print("⚠️ Status field not found. Available fields: \(responseData.keys.joined(separator: ", "))")
            statusString = "unknown"
        }
        
        // 根据官方文档，状态值为：WAIT/RUN/FAIL/DONE
        let status: BackendStatus
        switch statusString!.uppercased() {
        case "WAIT", "PENDING", "QUEUED", "SUBMITTED":
            status = .pending
        case "RUN", "RUNNING", "PROCESSING", "GENERATING", "IN_PROGRESS":
            status = .processing
        case "DONE", "COMPLETED", "SUCCESS", "SUCCEEDED", "FINISHED":
            status = .completed
        case "FAIL", "FAILED", "ERROR", "FAILURE":
            status = .failed
        default:
            status = .unknown
            print("⚠️ Unknown status value: '\(statusString!)' (Expected: WAIT/RUN/FAIL/DONE)")
        }

        // 从 ResultFile3Ds 数组中提取 USDZ 下载URL（根据官方文档）
        var downloadUrl: String? = nil
        var format: String = "usdz" // 默认USDZ
        
        if let resultFiles = responseData["ResultFile3Ds"] as? [[String: Any]] {
            // 查找 USDZ 格式的文件
            for file in resultFiles {
                if let fileType = file["Type"] as? String,
                   fileType.uppercased() == "USDZ",
                   let fileUrl = file["Url"] as? String {
                    downloadUrl = fileUrl
                    format = "usdz"
                    print("✅ Found USDZ file in ResultFile3Ds")
                    break
                }
            }
            
            // 如果没有找到USDZ，尝试其他格式
            if downloadUrl == nil, let firstFile = resultFiles.first {
                downloadUrl = firstFile["Url"] as? String
                format = (firstFile["Type"] as? String)?.lowercased() ?? "usdz"
                print("⚠️ USDZ not found, using first available format: \(format)")
            }
        } else {
            // 回退：尝试从旧字段提取（兼容性）
            downloadUrl = responseData["OutputUrl"] as? String ?? responseData["DownloadUrl"] as? String
            if downloadUrl != nil {
                // 从URL推断格式
                let urlLower = downloadUrl!.lowercased()
                if urlLower.contains(".usdz") {
                    format = "usdz"
                } else if urlLower.contains(".glb") {
                    format = "glb"
                }
            }
        }

        print("📊 Task status: \(status.rawValue), Format: \(format), Download URL: \(downloadUrl?.prefix(50) ?? "N/A")")

        return BackendTaskStatus(
            status: status,
            downloadUrl: downloadUrl,
            format: format
        )
    }

    /// 指数回退轮询器（避免频繁请求）
    private struct Backoff {
        private var attempt: Int = 0
        private let maxAttempt: Int = 6
        
        mutating func nextDelaySeconds() -> TimeInterval {
            attempt = min(attempt + 1, maxAttempt)
            let seconds = pow(1.6, Double(attempt)) // 1.6, 2.6, 4.1, 6.6, 10.5, 16.8秒
            return max(seconds, 1.0) // 最少1秒
        }
        
        mutating func reset() {
            attempt = 0
        }
    }
    
    /// 轮询任务直到完成（使用指数回退，适应3D生成的实际耗时）
    /// 根据官方文档，状态值为 WAIT/RUN/FAIL/DONE，无官方剩余时间字段
    /// 设置较长的超时时间（1小时），避免过早强制停止，给任务充足的完成时间
    func pollUntilCompletion(taskId: String, maxTotalTime: TimeInterval = 3600.0) async throws -> BackendTaskStatus {
        print("⏳ Starting task polling: \(taskId)")
        print("⏱️ Max total time: \(Int(maxTotalTime))s = \(Int(maxTotalTime) / 60) minutes")
        print("💡 Using exponential backoff (1.6s → 2.6s → 4.1s → ...)")
        print("💡 Note: No official ETA field, using client-side estimation")

        let startTime = Date()
        var backoff = Backoff()
        
        while Date().timeIntervalSince(startTime) < maxTotalTime {
            let elapsed = Int(Date().timeIntervalSince(startTime))
            let status = try await poll3DGenerationStatus(taskId: taskId)

            switch status.status {
            case .completed:
                print("✅ Task completed successfully! (Elapsed: \(elapsed)s)")
                return status
            case .failed:
                print("❌ Task failed (Elapsed: \(elapsed)s)")
                throw BackendError.taskFailed
            case .unknown:
                print("⚠️ Unknown status, continuing... (Elapsed: \(elapsed)s)")
                // 未知状态按处理中处理
            case .pending, .processing:
                let minutes = elapsed / 60
                let seconds = elapsed % 60
                let delay = backoff.nextDelaySeconds()
                print("🔄 Still processing... (Elapsed: \(minutes)m \(seconds)s, Next check in \(Int(delay))s)")
            }

            // 检查是否超时
            if Date().timeIntervalSince(startTime) >= maxTotalTime {
                break
            }
            
            // 使用指数回退延迟
            let delay = backoff.nextDelaySeconds()
            try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        }

        let totalElapsed = Int(Date().timeIntervalSince(startTime))
        print("⏰ Polling timeout after \(totalElapsed)s = \(totalElapsed / 60) minutes")
        throw BackendError.timeout
    }

    /// 完整的3D生成流程（提交→轮询→返回下载URL）
    /// 直接使用中文视觉指示词（由DeepSeek生成）
    func generate3DModel(prompt: String) async throws -> String {
        print("🚀 Starting complete 3D generation pipeline with Tencent Hunyuan To3D...")
        print("📝 Using Chinese visual prompt: \(prompt.prefix(150))...")

        // 1. 提交任务（直接使用中文提示词）
        let taskId = try await submit3DGeneration(prompt: prompt)

        // 2. 轮询直到完成
        let finalStatus = try await pollUntilCompletion(taskId: taskId)

        // 3. 返回下载URL
        guard let downloadUrl = finalStatus.downloadUrl else {
            throw BackendError.noDownloadUrl
        }

        print("✅ 3D model generation pipeline completed!")
        print("📦 Download URL: \(downloadUrl)")

        return downloadUrl
    }

    // MARK: - Helper Methods

    /// 构建提示词（已废弃 - 现在直接使用DeepSeek生成的中文视觉指示词）
    /// 保留此函数仅用于向后兼容，实际不再使用
    @available(*, deprecated, message: "Use DeepSeek-generated Chinese visual prompt directly")
    private func buildPrompt(from description: String, analysis: DreamAnalysis?) -> String {
        // 基础梦境描述
        var prompt = description

        if let analysis = analysis {
            // 添加关键词
            if !analysis.keywords.isEmpty {
                prompt += " Keywords: \(analysis.keywords.joined(separator: ", "))."
            }

            // 添加视觉描述
            if !analysis.visualDescription.isEmpty {
                prompt += " Visual description: \(analysis.visualDescription)."
            }
        }

        // 添加可打印性和稳定性约束（确保模型质量）
        // 这些约束确保生成的3D模型：
        // 1. 单一体网格，无悬空部件
        // 2. 低重心，稳定放置
        // 3. 圆底座，适合展示
        // 4. 细节适度，适合visionOS渲染
        let constraints = """
        
        Requirements for 3D model generation:
        - Single solid mesh structure, no floating parts
        - Low center of gravity for stability
        - Round base integrated with main structure
        - Minimal overhangs (max 45 degrees)
        - Matte finish, no glowing materials
        - Optimized for 3D printing and AR display
        - Dimensions approximately 12x12x16 cm
        - Realistic style with moderate detail level
        """
        
        prompt += constraints

        return prompt
    }

    /// 生成腾讯云API签名
    private func generateTencentHeaders(action: String, timestamp: String, payload: String) throws -> [String: String] {
        let host = "ai3d.tencentcloudapi.com"
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
        // 重要：credentialScope 中的日期必须是 YYYY-MM-DD 格式，不是时间戳
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        dateFormatter.timeZone = TimeZone(identifier: "UTC")
        let date = dateFormatter.string(from: Date())
        
        let credentialScope = "\(date)/\(service)/tc3_request"
        let hashedCanonicalRequest = sha256Hex(canonicalRequest)
        let stringToSign = """
        \(algorithm)\n\(timestamp)\n\(credentialScope)\n\(hashedCanonicalRequest)
        """

        // 3. 计算签名
        // secretDate 使用日期（YYYY-MM-DD），不是时间戳
        let secretDate = hmacSha256(data: date, key: "TC3" + secretKey)
        let secretService = hmacSha256(data: service, keyData: secretDate)
        let secretSigning = hmacSha256(data: "tc3_request", keyData: secretService)
        let signature = hmacSha256Hex(data: stringToSign, keyData: secretSigning)

        // 4. 拼接 Authorization
        let authorization = "\(algorithm) Credential=\(secretId)/\(credentialScope), SignedHeaders=\(signedHeaders), Signature=\(signature)"

        // 调试：打印签名信息（不完整显示，保护隐私）
        print("🔐 Signature details:")
        print("   Date: \(date)")
        print("   CredentialScope: \(credentialScope)")
        print("   SecretId (masked): \(secretId.prefix(8))...\(secretId.suffix(4))")
        print("   Authorization (masked): \(authorization.prefix(80))...")

        return [
            "Authorization": authorization,
            "Content-Type": "application/json",
            "Host": host,
            "X-TC-Action": action,
            "X-TC-Timestamp": timestamp,
            "X-TC-Version": version,
            "X-TC-Region": region
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
}

// MARK: - 数据模型

enum BackendStatus: String {
    case pending = "pending"
    case processing = "processing"
    case completed = "completed"
    case failed = "failed"
    case unknown = "unknown"
}

struct BackendTaskStatus {
    let status: BackendStatus
    let downloadUrl: String?
    let format: String? // "glb" or "usdz"
}

enum BackendError: LocalizedError {
    case invalidRequest
    case invalidResponse
    case apiError(String)
    case taskFailed
    case timeout
    case noDownloadUrl

    var errorDescription: String? {
        switch self {
        case .invalidRequest:
            return "Invalid request format"
        case .invalidResponse:
            return "Invalid server response"
        case .apiError(let message):
            return "Backend API error: \(message)"
        case .taskFailed:
            return "3D generation task failed"
        case .timeout:
            return "Request timeout"
        case .noDownloadUrl:
            return "No download URL available"
        }
    }
}
