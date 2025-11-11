//
//  BackendAPIService.swift
//  Dreamecho
//
//  Created by AI on 2025/11/11.
//

import Foundation

/// 后端代理服务 - 处理3D模型生成（后端代签名/代调用）
class BackendAPIService {
    static let shared = BackendAPIService()

    // 后端服务配置（这些应该放在环境变量或配置文件中）
    private let baseURL: String
    private let apiKey: String

    private init() {
        // 从配置中读取后端服务地址和API密钥
        // 注意：这些应该通过环境变量或安全的配置方式管理
        self.baseURL = "https://your-backend-api.com" // 替换为实际的后端地址
        self.apiKey = Bundle.main.object(forInfoDictionaryKey: "BackendAPIKey") as? String ?? ""

        print("✅ Backend API Service initialized")
    }

    // MARK: - 后端接口实现

    /// 提交3D模型生成任务
    /// POST /dreams/3d
    /// 返回：{ "taskId": "task_id_string" }
    func submit3DGeneration(dreamDescription: String, analysis: DreamAnalysis? = nil) async throws -> String {
        print("🎨 Submitting 3D generation task...")

        let requestBody = [
            "description": dreamDescription,
            "analysis": [
                "keywords": analysis?.keywords ?? [],
                "emotions": analysis?.emotions ?? [],
                "visualDescription": analysis?.visualDescription ?? ""
            ],
            "quality": "high", // high/standard
            "format": "glb" // glb/usdz，优先usdz
        ] as [String: Any]

        guard let jsonData = try? JSONSerialization.data(withJSONObject: requestBody) else {
            throw BackendError.invalidRequest
        }

        var request = URLRequest(url: URL(string: "\(baseURL)/dreams/3d")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = jsonData
        request.timeoutInterval = 30.0

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw BackendError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            let errorString = String(data: data, encoding: .utf8) ?? "Unknown error"
            print("❌ Backend API Error: HTTP \(httpResponse.statusCode)")
            print("❌ Error response: \(errorString)")
            throw BackendError.apiError(errorString)
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let taskId = json["taskId"] as? String else {
            print("❌ Failed to parse taskId from backend response")
            throw BackendError.invalidResponse
        }

        print("✅ Task submitted successfully: \(taskId)")
        return taskId
    }

    /// 查询3D生成任务状态
    /// GET /dreams/3d/:taskId
    /// 返回：{ "status": "pending|processing|completed|failed", "downloadUrl": "url", "format": "glb|usdz" }
    func poll3DGenerationStatus(taskId: String) async throws -> BackendTaskStatus {
        let url = URL(string: "\(baseURL)/dreams/3d/\(taskId)")!

        var request = URLRequest(url: url)
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 10.0

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw BackendError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            let errorString = String(data: data, encoding: .utf8) ?? "Unknown error"
            print("❌ Backend API Error: HTTP \(httpResponse.statusCode)")
            throw BackendError.apiError(errorString)
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let statusString = json["status"] as? String else {
            print("❌ Failed to parse status from backend response")
            throw BackendError.invalidResponse
        }

        let status = BackendStatus(rawValue: statusString.lowercased()) ?? .unknown
        let downloadUrl = json["downloadUrl"] as? String
        let format = json["format"] as? String

        print("📊 Task status: \(status.rawValue), Download URL: \(downloadUrl?.prefix(50) ?? "N/A")")

        return BackendTaskStatus(
            status: status,
            downloadUrl: downloadUrl,
            format: format
        )
    }

    /// 轮询任务直到完成
    func pollUntilCompletion(taskId: String, maxAttempts: Int = 60, interval: TimeInterval = 2.0) async throws -> BackendTaskStatus {
        print("⏳ Starting task polling: \(taskId)")

        for attempt in 0..<maxAttempts {
            let status = try await poll3DGenerationStatus(taskId: taskId)

            switch status.status {
            case .completed:
                print("✅ Task completed successfully!")
                return status
            case .failed:
                print("❌ Task failed")
                throw BackendError.taskFailed
            case .unknown:
                print("⚠️ Unknown status, continuing...")
            case .pending, .processing:
                print("🔄 Still processing... (Attempt \(attempt + 1)/\(maxAttempts))")
            }

            if attempt < maxAttempts - 1 {
                try await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
            }
        }

        print("⏰ Polling timeout after \(maxAttempts) attempts")
        throw BackendError.timeout
    }

    /// 完整的3D生成流程（提交→轮询→返回下载URL）
    func generate3DModel(dreamDescription: String, analysis: DreamAnalysis? = nil) async throws -> String {
        print("🚀 Starting complete 3D generation pipeline...")

        // 1. 提交任务
        let taskId = try await submit3DGeneration(dreamDescription: dreamDescription, analysis: analysis)

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