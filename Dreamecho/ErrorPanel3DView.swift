//
//  ErrorPanel3DView.swift
//  Dreamecho
//
//  Created by sztu on 2025/11/9.
//

import SwiftUI
import RealityKit

/// 3D 空间错误提示面板 - 可移动，位于用户面前
struct ErrorPanel3DView: View {
    let position: SIMD3<Float>
    @Binding var isDragging: Bool
    let onDrag: (SIMD3<Float>) -> Void
    let dream: Dream?
    let modelURL: String?
    let onClose: () -> Void
    let onARQuickLook: (String) -> Void
    let onWindowPreview: (String) -> Void
    
    @State private var dragStartPosition: SIMD3<Float> = [0, 0, 0]
    @State private var dragOffset: CGSize = .zero
    
    var body: some View {
        // 使用 SwiftUI 窗口定位，在用户面前显示
        VStack {
            Spacer()
            
            // 错误提示卡片 - 居中显示在用户面前，可移动
            VStack(spacing: 24) {
                // 标题栏 - 可拖拽
                HStack {
                    HStack(spacing: 12) {
                        Image(systemName: "hand.draw.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(.blue.opacity(0.6))
                        Text("拖拽移动")
                            .font(.system(size: 16))
                            .foregroundStyle(.secondary)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundStyle(.orange)
                        .symbolEffect(.pulse, options: .repeating)
                    
                    Text("模型格式不支持")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundStyle(.primary)
                    
                    Spacer()
                    
                    // 关闭按钮
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            onClose()
                        }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 28))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 32)
                .padding(.top, 24)
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            if !isDragging {
                                isDragging = true
                                dragStartPosition = position
                            }
                            
                            dragOffset = value.translation
                            
                            // 将屏幕坐标转换为3D空间坐标
                            let sensitivity: Float = 0.008
                            let deltaX = Float(value.translation.width) * sensitivity
                            let deltaY = Float(-value.translation.height) * sensitivity
                            
                            let newPosition = SIMD3<Float>(
                                dragStartPosition.x + deltaX,
                                dragStartPosition.y + deltaY,
                                position.z // 保持Z轴距离
                            )
                            onDrag(newPosition)
                        }
                        .onEnded { _ in
                            isDragging = false
                            dragOffset = .zero
                        }
                )
                
                VStack(spacing: 20) {
                    Text("当前模型为 GLB 格式")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(.secondary)
                    
                    Text("visionOS 沉浸式空间无法直接加载 GLB 格式")
                        .font(.system(size: 20))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    
                    Divider()
                        .padding(.vertical, 8)
                    
                    VStack(spacing: 16) {
                        Text("解决方案")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(.primary)
                        
                        // 预览选项按钮
                        if let modelURL = modelURL {
                            VStack(spacing: 12) {
                                // AR Quick Look 按钮（推荐用于 USDZ）
                                if normalizedURLPath(modelURL).hasSuffix(".usdz") {
                                    Button {
                                        onARQuickLook(modelURL)
                                    } label: {
                                        Label("AR Quick Look", systemImage: "arkit")
                                            .font(.system(size: 20, weight: .semibold))
                                            .padding(.horizontal, 32)
                                            .padding(.vertical, 16)
                                            .frame(maxWidth: .infinity)
                                            .background(.blue.opacity(0.3))
                                            .cornerRadius(12)
                                    }
                                    .buttonStyle(.plain)
                                }
                                
                                // 窗口预览按钮（适用于所有格式）
                                Button {
                                    onWindowPreview(modelURL)
                                } label: {
                                    Label("Window Preview", systemImage: "rectangle.inset.filled.and.person.filled")
                                        .font(.system(size: 20, weight: .semibold))
                                        .padding(.horizontal, 32)
                                        .padding(.vertical, 16)
                                        .frame(maxWidth: .infinity)
                                        .background(.blue.opacity(0.3))
                                        .cornerRadius(12)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        
                        Text("已自动打开预览模式")
                            .font(.system(size: 18))
                            .foregroundStyle(.blue)
                        
                        Text("AR Quick Look 提供最佳预览体验（USDZ 格式）")
                            .font(.system(size: 16))
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                        
                        Text("窗口预览支持所有格式，包括 GLB")
                            .font(.system(size: 14))
                            .foregroundStyle(.tertiary)
                            .multilineTextAlignment(.center)
                        
                        Divider()
                            .padding(.vertical, 8)
                        
                        Text("建议：联系 Tripo3D 申请 USDZ 格式支持")
                            .font(.system(size: 16))
                            .foregroundStyle(.tertiary)
                            .multilineTextAlignment(.center)
                        
                        Text("USDZ 是 visionOS 推荐格式，支持最佳")
                            .font(.system(size: 14))
                            .foregroundStyle(.tertiary)
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 32)
            }
            .frame(maxWidth: 900)
            .background(.regularMaterial)
            .cornerRadius(28)
            .shadow(color: .black.opacity(0.4), radius: 30, x: 0, y: 15)
            .overlay(
                RoundedRectangle(cornerRadius: 28)
                    .stroke(.orange.opacity(0.3), lineWidth: 2)
            )
            .offset(x: dragOffset.width, y: dragOffset.height)
            .scaleEffect(isDragging ? 1.05 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isDragging)
            .padding(.horizontal, 40)
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.clear)
    }
    
    private func normalizedURLPath(_ url: String) -> String {
        let lowercased = url.lowercased()
        if let questionIndex = lowercased.firstIndex(of: "?") {
            return String(lowercased[..<questionIndex])
        }
        return lowercased
    }
}
