//
//  SpeechRecognitionService.swift
//  Dreamecho
//
//  Created by sztu on 2025/11/9.
//

import Foundation
import Speech
import AVFoundation

/// 语音识别服务，用于聆听和转录梦境
@MainActor
@Observable
class SpeechRecognitionService {
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "zh-CN"))
    private let audioEngine = AVAudioEngine()
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var isTapInstalled = false // 跟踪 tap 是否已安装
    
    var isListening = false
    var transcribedText = ""
    var authorizationStatus: SFSpeechRecognizerAuthorizationStatus = .notDetermined
    
    init() {
        checkAuthorization()
    }
    
    /// 检查语音识别权限
    func checkAuthorization() {
        SFSpeechRecognizer.requestAuthorization { [weak self] status in
            Task { @MainActor in
                self?.authorizationStatus = status
            }
        }
    }
    
    /// 开始聆听
    func startListening() async throws {
        // 先确保完全停止之前的任务
        await MainActor.run {
            stopListeningSync()
        }
        
        // 等待一小段时间确保资源完全释放
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1秒
        
        // 检查状态 - 在主线程
        let (isAvailable, isAuthorized) = await MainActor.run {
            let available = speechRecognizer?.isAvailable ?? false
            let authorized = authorizationStatus == .authorized
            return (available, authorized)
        }
        
        guard isAvailable else {
            throw SpeechError.recognizerUnavailable
        }
        
        guard isAuthorized else {
            throw SpeechError.notAuthorized
        }
        
        guard let speechRecognizer = speechRecognizer else {
            throw SpeechError.recognizerUnavailable
        }
        
        // 配置音频会话（在后台线程）- 优化 visionOS 支持
        let audioSession = AVAudioSession.sharedInstance()
        do {
            // 使用正确的音频会话配置（.record 类别不支持 .defaultToSpeaker）
            try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            print("Audio session configuration error: \(error.localizedDescription)")
            // 尝试备用配置
            do {
                try audioSession.setCategory(.record, mode: .default)
                try audioSession.setActive(true)
            } catch {
                throw SpeechError.requestCreationFailed
            }
        }
        
        // 创建识别请求
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        
        // 配置音频输入 - 确保没有已存在的 tap
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        
        // 确保音频引擎未运行
        if audioEngine.isRunning {
            audioEngine.stop()
        }
        
        // 如果已有 tap，先移除（安全处理）
        if isTapInstalled {
            inputNode.removeTap(onBus: 0)
            isTapInstalled = false
        }
        
        // 使用弱引用避免循环引用
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak request] buffer, _ in
            request?.append(buffer)
        }
        isTapInstalled = true
        
        // 启动音频引擎
        audioEngine.prepare()
        try audioEngine.start()
        
        // 更新状态 - 在主线程
        await MainActor.run {
            recognitionRequest = request
            isListening = true
            transcribedText = ""
        }
        
        // 开始识别任务
        recognitionTask = speechRecognizer.recognitionTask(with: request) { [weak self] result, error in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                
                if let result = result {
                    self.transcribedText = result.bestTranscription.formattedString
                    
                    // 如果识别完成，自动停止
                    if result.isFinal {
                        self.stopListening()
                    }
                }
                
                if let error = error {
                    let nsError = error as NSError
                    // 忽略一些系统级别的错误（这些是正常的）
                    if nsError.domain != "kAFAssistantErrorDomain" || nsError.code != 216 {
                        print("Speech recognition error: \(error.localizedDescription)")
                    }
                    self.stopListening()
                }
            }
        }
    }
    
    /// 停止聆听（同步版本，用于内部调用）
    private func stopListeningSync() {
        // 取消识别任务
        recognitionTask?.cancel()
        recognitionTask = nil
        
        // 结束音频请求
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        
        // 安全地停止音频引擎并移除 tap
        if audioEngine.isRunning {
            audioEngine.stop()
        }
        
        // 安全地移除 tap（只有在已安装时才移除）
        if isTapInstalled {
            audioEngine.inputNode.removeTap(onBus: 0)
            isTapInstalled = false
        }
        
        isListening = false
    }
    
    /// 停止聆听（异步版本，用于外部调用）
    func stopListening() {
        stopListeningSync()
        
        // 延迟停用音频会话，避免冲突
        Task { @MainActor in
            do {
                let audioSession = AVAudioSession.sharedInstance()
                try audioSession.setActive(false, options: .notifyOthersOnDeactivation)
            } catch {
                // 忽略停用错误，这些通常是正常的
            }
        }
    }
}

enum SpeechError: LocalizedError {
    case recognizerUnavailable
    case notAuthorized
    case requestCreationFailed
    
    var errorDescription: String? {
        switch self {
        case .recognizerUnavailable:
            return "语音识别器不可用"
        case .notAuthorized:
            return "未授权语音识别权限"
        case .requestCreationFailed:
            return "创建识别请求失败"
        }
    }
}

