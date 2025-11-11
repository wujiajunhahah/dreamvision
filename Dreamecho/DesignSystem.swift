//
//  DesignSystem.swift
//  Dreamecho
//
//  Created by sztu on 2025/11/9.
//

import SwiftUI

/// 组件化设计系统 - 符合 visionOS HIG + 液态玻璃效果
/// 参考: https://developer.apple.com/documentation/technologyoverviews/adopting-liquid-glass
struct DesignSystem {
    // MARK: - Colors (浅色主题，符合 HIG)
    
    static let background = Color.white
    static let backgroundSecondary = Color(white: 0.98)
    static let surface = Color.white
    static let surfaceSecondary = Color(white: 0.95)
    
    // MARK: - Liquid Glass Materials (完整实现)
    
    /// 超薄液态玻璃效果 - 用于卡片和次要元素
    /// 符合 Apple Liquid Glass 设计规范
    static func liquidGlassThin() -> some View {
        RoundedRectangle(cornerRadius: 20)
            .fill(.ultraThinMaterial)
            .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 5)
            .overlay {
                // 添加微妙的边框高光，模拟玻璃边缘
                RoundedRectangle(cornerRadius: 20)
                    .stroke(
                        LinearGradient(
                            colors: [
                                .white.opacity(0.3),
                                .white.opacity(0.0)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.5
                    )
            }
    }
    
    /// 常规液态玻璃效果 - 用于主要容器
    static func liquidGlass() -> some View {
        RoundedRectangle(cornerRadius: 20)
            .fill(.regularMaterial)
            .shadow(color: .black.opacity(0.08), radius: 15, x: 0, y: 8)
            .overlay {
                RoundedRectangle(cornerRadius: 20)
                    .stroke(
                        LinearGradient(
                            colors: [
                                .white.opacity(0.4),
                                .white.opacity(0.0)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.5
                    )
            }
    }
    
    /// 厚液态玻璃效果 - 用于重要元素
    static func liquidGlassThick() -> some View {
        RoundedRectangle(cornerRadius: 20)
            .fill(.thickMaterial)
            .shadow(color: .black.opacity(0.1), radius: 20, x: 0, y: 10)
            .overlay {
                RoundedRectangle(cornerRadius: 20)
                    .stroke(
                        LinearGradient(
                            colors: [
                                .white.opacity(0.5),
                                .white.opacity(0.0)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.5
                    )
            }
    }
    
    // MARK: - Typography (符合 HIG 动态类型)
    
    static let largeTitle = Font.system(size: 34, weight: .bold, design: .default)
    static let title = Font.system(size: 28, weight: .bold, design: .default)
    static let title2 = Font.system(size: 22, weight: .semibold, design: .default)
    static let title3 = Font.system(size: 20, weight: .semibold, design: .default)
    static let headline = Font.system(size: 17, weight: .semibold, design: .default)
    static let body = Font.system(size: 17, weight: .regular, design: .default)
    static let callout = Font.system(size: 16, weight: .regular, design: .default)
    static let subheadline = Font.system(size: 15, weight: .regular, design: .default)
    static let footnote = Font.system(size: 13, weight: .regular, design: .default)
    static let caption = Font.system(size: 12, weight: .regular, design: .default)
    static let caption2 = Font.system(size: 11, weight: .regular, design: .default)
}

// MARK: - 可复用组件（符合 visionOS HIG）

/// 液态玻璃卡片组件 - 支持动态光影效果
struct LiquidGlassCard<Content: View>: View {
    let content: Content
    let cornerRadius: CGFloat
    let padding: CGFloat
    let material: Material
    @State private var isHovered = false
    
    init(
        cornerRadius: CGFloat = 20,
        padding: CGFloat = 24,
        material: Material = .ultraThinMaterial,
        @ViewBuilder content: () -> Content
    ) {
        self.cornerRadius = cornerRadius
        self.padding = padding
        self.material = material
        self.content = content()
    }
    
    var body: some View {
        content
            .padding(padding)
            .background {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(material)
                    .shadow(
                        color: .black.opacity(isHovered ? 0.1 : 0.05),
                        radius: isHovered ? 15 : 10,
                        x: 0,
                        y: isHovered ? 8 : 5
                    )
                    .overlay {
                        // 动态边框高光
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        .white.opacity(isHovered ? 0.4 : 0.3),
                                        .white.opacity(0.0)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 0.5
                            )
                    }
                    .animation(.easeInOut(duration: 0.2), value: isHovered)
            }
            .onHover { hovering in
                isHovered = hovering
            }
    }
}

/// 液态玻璃按钮组件 - 支持按压反馈和动画
struct LiquidGlassButton: View {
    let title: String
    let icon: String?
    let action: () -> Void
    let isEnabled: Bool
    let style: ButtonStyle
    
    enum ButtonStyle {
        case primary
        case secondary
    }
    
    @State private var isPressed = false
    @State private var isHovered = false
    
    init(
        _ title: String,
        icon: String? = nil,
        style: ButtonStyle = .primary,
        isEnabled: Bool = true,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.icon = icon
        self.style = style
        self.isEnabled = isEnabled
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .semibold))
                        .symbolEffect(.bounce, value: isPressed)
                }
                Text(title)
                    .font(.system(size: 17, weight: .semibold))
            }
            .foregroundStyle(isEnabled ? .primary : .secondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background {
                RoundedRectangle(cornerRadius: 12)
                    .fill(isEnabled ? materialForStyle : .ultraThinMaterial)
                    .overlay {
                        // 动态高光效果
                        RoundedRectangle(cornerRadius: 12)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        .white.opacity(isHovered && isEnabled ? 0.2 : 0.0),
                                        .white.opacity(0.0)
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                    }
                    .scaleEffect(isPressed ? 0.98 : 1.0)
                    .shadow(
                        color: .black.opacity(isHovered && isEnabled ? 0.1 : 0.05),
                        radius: isHovered && isEnabled ? 12 : 8,
                        x: 0,
                        y: isHovered && isEnabled ? 6 : 4
                    )
            }
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
        .pressEvents {
            withAnimation(.easeInOut(duration: 0.1)) {
                isPressed = true
            }
        } onRelease: {
            withAnimation(.easeInOut(duration: 0.1)) {
                isPressed = false
            }
        }
    }
    
    private var materialForStyle: Material {
        switch style {
        case .primary:
            return .regularMaterial
        case .secondary:
            return .thinMaterial
        }
    }
}

/// 液态玻璃输入框组件 - 支持焦点状态
struct LiquidGlassTextField: View {
    let title: String
    let placeholder: String
    @Binding var text: String
    let icon: String?
    @FocusState private var isFocused: Bool
    
    init(
        _ title: String,
        text: Binding<String>,
        placeholder: String = "",
        icon: String? = nil
    ) {
        self.title = title
        self._text = text
        self.placeholder = placeholder
        self.icon = icon
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 14))
                }
                Text(title)
                    .font(.system(size: 15, weight: .medium))
            }
            .foregroundStyle(.secondary)
            
            TextField("", text: $text, prompt: Text(placeholder).foregroundStyle(.tertiary))
                .textFieldStyle(.plain)
                .font(.system(size: 17))
                .foregroundStyle(.primary)
                .padding(16)
                .background {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(.ultraThinMaterial)
                        .overlay {
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(
                                    isFocused ? Color.accentColor.opacity(0.5) : Color.clear,
                                    lineWidth: 2
                                )
                        }
                }
                .focused($isFocused)
                .animation(.easeInOut(duration: 0.2), value: isFocused)
        }
    }
}

/// 液态玻璃文本编辑器组件 - 支持焦点和动态高度
struct LiquidGlassTextEditor: View {
    let title: String
    let placeholder: String
    @Binding var text: String
    let icon: String?
    let minHeight: CGFloat
    @FocusState private var isFocused: Bool
    
    init(
        _ title: String,
        text: Binding<String>,
        placeholder: String = "",
        icon: String? = nil,
        minHeight: CGFloat = 180
    ) {
        self.title = title
        self._text = text
        self.placeholder = placeholder
        self.icon = icon
        self.minHeight = minHeight
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 14))
                }
                Text(title)
                    .font(.system(size: 15, weight: .medium))
            }
            .foregroundStyle(.secondary)
            
            ZStack(alignment: .topLeading) {
                if text.isEmpty {
                    Text(placeholder)
                        .foregroundStyle(.tertiary)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 16)
                }
                
                TextEditor(text: $text)
                    .scrollContentBackground(.hidden)
                    .padding(12)
                    .font(.system(size: 17))
                    .foregroundStyle(.primary)
                    .frame(minHeight: minHeight)
                    .background {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(.ultraThinMaterial)
                            .overlay {
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(
                                        isFocused ? Color.accentColor.opacity(0.5) : Color.clear,
                                        lineWidth: 2
                                    )
                            }
                    }
                    .focused($isFocused)
                    .animation(.easeInOut(duration: 0.2), value: isFocused)
            }
        }
    }
}

/// 液态玻璃标签组件 - 支持动态效果
struct LiquidGlassTag: View {
    let text: String
    let icon: String?
    @State private var isHovered = false
    
    init(_ text: String, icon: String? = nil) {
        self.text = text
        self.icon = icon
    }
    
    var body: some View {
        HStack(spacing: 4) {
            if let icon = icon {
                Image(systemName: icon)
                    .font(.system(size: 10))
            }
            Text(text)
                .font(.system(size: 13))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background {
            Capsule()
                .fill(.ultraThinMaterial)
                .overlay {
                    Capsule()
                        .stroke(
                            LinearGradient(
                                colors: [
                                    .white.opacity(isHovered ? 0.3 : 0.2),
                                    .white.opacity(0.0)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 0.5
                        )
                }
        }
        .foregroundStyle(.secondary)
        .scaleEffect(isHovered ? 1.05 : 1.0)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }
}

/// 液态玻璃导航栏组件 - 支持平滑过渡
struct LiquidGlassNavigationBar: View {
    let items: [NavigationItem]
    @Binding var selectedItem: NavigationItem
    
    struct NavigationItem: Identifiable, Hashable {
        let id = UUID()
        let title: String
        let icon: String
        
        static func == (lhs: NavigationItem, rhs: NavigationItem) -> Bool {
            lhs.title == rhs.title
        }
        
        func hash(into hasher: inout Hasher) {
            hasher.combine(title)
        }
    }
    
    var body: some View {
        HStack(spacing: 20) {
            ForEach(items) { item in
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        selectedItem = item
                    }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: item.icon)
                            .font(.system(size: 16, weight: .medium))
                            .symbolEffect(.bounce, value: selectedItem.title == item.title)
                        Text(item.title)
                            .font(.system(size: 17, weight: .semibold))
                    }
                    .foregroundStyle(selectedItem.title == item.title ? .primary : .secondary)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background {
                        if selectedItem.title == item.title {
                            Capsule()
                                .fill(.ultraThinMaterial)
                                .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
                                .overlay {
                                    Capsule()
                                        .stroke(
                                            LinearGradient(
                                                colors: [
                                                    .white.opacity(0.4),
                                                    .white.opacity(0.0)
                                                ],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            ),
                                            lineWidth: 0.5
                                        )
                                }
                        }
                    }
                }
                .buttonStyle(.plain)
            }
            
            Spacer()
        }
        .padding(.horizontal, 32)
        .padding(.vertical, 16)
        .background(.ultraThinMaterial)
    }
}

/// 液态玻璃背景视图 - 环境适应效果
struct LiquidGlassBackground: View {
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        ZStack {
            // 浅色渐变背景（根据环境光自适应）
            LinearGradient(
                colors: colorScheme == .dark ? [
                    Color(white: 0.1),
                    Color(white: 0.08),
                    Color(white: 0.05)
                ] : [
                    Color.white,
                    Color(white: 0.98),
                    Color(white: 0.95)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
            // 装饰性光晕效果（动态）
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color.blue.opacity(colorScheme == .dark ? 0.1 : 0.05),
                            Color.clear
                        ],
                        center: .topLeading,
                        startRadius: 0,
                        endRadius: 400
                    )
                )
                .frame(width: 800, height: 800)
                .offset(x: -200, y: -200)
                .blur(radius: 20)
            
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color.purple.opacity(colorScheme == .dark ? 0.1 : 0.05),
                            Color.clear
                        ],
                        center: .bottomTrailing,
                        startRadius: 0,
                        endRadius: 400
                    )
                )
                .frame(width: 800, height: 800)
                .offset(x: 200, y: 200)
                .blur(radius: 20)
        }
        .ignoresSafeArea()
    }
}

// MARK: - View Modifiers（符合 HIG）

extension View {
    /// 应用液态玻璃卡片效果
    func liquidGlassCard(cornerRadius: CGFloat = 20, padding: CGFloat = 24) -> some View {
        self
            .padding(padding)
            .background {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(.ultraThinMaterial)
                    .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 5)
                    .overlay {
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        .white.opacity(0.3),
                                        .white.opacity(0.0)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 0.5
                            )
                    }
            }
    }
    
    /// 应用液态玻璃背景
    func liquidGlassBackground() -> some View {
        self
            .background {
                LiquidGlassBackground()
            }
    }
    
    /// 添加按压事件支持
    func pressEvents(onPress: @escaping () -> Void, onRelease: @escaping () -> Void) -> some View {
        self
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        onPress()
                    }
                    .onEnded { _ in
                        onRelease()
                    }
            )
    }
}
