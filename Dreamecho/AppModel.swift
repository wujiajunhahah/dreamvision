//
//  AppModel.swift
//  Dreamecho
//
//  Created by sztu on 2025/11/9.
//

import SwiftUI

/// Maintains app-wide state
@MainActor
@Observable
class AppModel {
    let immersiveSpaceID = "ImmersiveSpace"
    enum ImmersiveSpaceState {
        case closed
        case inTransition
        case open
    }
    var immersiveSpaceState = ImmersiveSpaceState.closed
    
    // 梦境数据存储
    var dreamStore = DreamStore()
    
    // 当前选中的梦境（用于3D展示）
    var selectedDream: Dream?
    
    // 窗口预览模式
    var showModelPreview = false
    var previewModelURL: String?
    var previewDreamTitle: String?
    
    // AR Quick Look 预览模式（推荐用于 USDZ 格式）
    var showARQuickLook = false
    var arQuickLookURL: URL?
}
