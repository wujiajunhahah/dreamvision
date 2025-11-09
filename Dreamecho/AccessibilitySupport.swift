//
//  AccessibilitySupport.swift
//  Dreamecho
//
//  Created by sztu on 2025/11/9.
//

import SwiftUI

/// 辅助功能支持 - 符合 visionOS HIG 和 Apple 无障碍指南
/// 参考: https://developer.apple.com/cn/visionos/

/// 无障碍修饰符集合 - 尊重用户偏好
struct AccessibilityModifiers: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    func body(content: Content) -> some View {
        content
            .animation(reduceMotion ? nil : .default, value: UUID())
    }
}

extension View {
    func accessibilityModifiers() -> some View {
        modifier(AccessibilityModifiers())
    }
}
