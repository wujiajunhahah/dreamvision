# DreamEcho - visionOS 梦境可视化应用

<div align="center">

![DreamEcho](https://img.shields.io/badge/visionOS-26.1-blue)
![Swift](https://img.shields.io/badge/Swift-6.0-orange)
![License](https://img.shields.io/badge/License-Private-red)

**将梦境转化为现实的沉浸式体验** ✨

[功能特性](#-核心功能) • [快速开始](#-快速开始) • [开发指南](#-开发指南) • [API配置](#-api配置)

</div>

---

## 🌟 项目概述

DreamEcho 是一个专为 Apple Vision Pro 开发的 visionOS 原生应用，使用 Swift 6 和 visionOS 26.1 系统特性构建。应用可以将用户的梦境描述转换为精美的3D模型，并在沉浸式空间中展示，带来前所未有的梦境可视化体验。

### 核心价值

- 🎨 **原生 visionOS 体验**：充分利用 Vision Pro 的空间计算能力
- 🤖 **AI 驱动**：集成 DeepSeek 和 Tripo3D API 进行智能分析和生成
- 💎 **液态玻璃设计**：采用 iOS 26 的液态玻璃材质，优雅美观
- 🚀 **高性能渲染**：使用 RealityKit 实现流畅的3D渲染
- 📦 **格式自动转换**：自动将 GLB 格式转换为 USDZ，确保最佳兼容性

---

## ✨ 核心功能

### 1. 梦境输入
- **文本输入**：支持详细的梦境描述输入，实时字数统计
- **语音输入**：使用语音识别功能聆听和转录梦境（支持中文）
- **实时预览**：输入时实时显示内容，提供流畅的输入体验

### 2. AI 梦境分析
- **关键词提取**：自动提取梦境中的关键词和主题
- **情感分析**：识别梦境中的情感元素和情绪
- **符号识别**：识别梦境中的象征符号和隐喻
- **视觉描述生成**：生成详细的视觉描述，用于3D模型生成

### 3. 3D 模型生成
- **DeepSeek API 集成**：使用 DeepSeek 进行梦境分析和提示词生成
- **Tripo3D API 集成**：使用 Tripo3D 生成高质量的3D模型
- **格式自动转换**：自动将 GLB 格式转换为 USDZ（visionOS 最佳格式）
- **文件验证**：转换后自动验证文件可加载性，确保展示无错误
- **实时进度显示**：显示模型生成进度和预计时间

### 4. 沉浸式3D展示
- **全沉浸式空间**：在 Vision Pro 的沉浸式空间中展示3D模型
- **AR Quick Look**：使用系统原生 AR Quick Look 预览模型（推荐）
- **窗口预览**：备选的窗口预览模式（用于 GLB 格式）
- **交互式模型**：支持模型旋转、缩放、拖拽放置
- **梦幻粒子效果**：添加梦幻氛围的粒子效果
- **环境光照**：优化的光照系统，提供最佳视觉效果

### 5. 数据管理
- **本地持久化**：自动保存梦境数据到本地文件
- **模型缓存**：智能缓存机制，避免重复下载
- **模型导出**：支持导出模型到 Documents 目录
- **数据恢复**：应用重启后自动恢复数据

### 6. 设计系统
- **液态玻璃效果**：采用 iOS 26 的液态玻璃材质
- **深蓝渐变主题**：梦幻的深蓝渐变配色
- **现代化UI**：符合 visionOS 设计规范
- **无障碍支持**：完整的无障碍功能支持

---

## 🛠 技术栈

- **开发语言**：Swift 6.0
- **系统版本**：visionOS 26.1+
- **UI框架**：SwiftUI
- **3D引擎**：RealityKit
- **语音识别**：Speech Framework
- **文件管理**：FileManager, ModelIO
- **API集成**：
  - DeepSeek API（梦境分析）
  - Tripo3D API（3D模型生成）

---

## 📁 项目结构

```
Dreamecho/
├── Dreamecho/
│   ├── DreamechoApp.swift          # 应用入口，配置 WindowGroup 和 ImmersiveSpace
│   ├── ContentView.swift            # 主窗口视图，TabView 导航
│   ├── DreamInputView.swift         # 梦境输入视图（文本+语音）
│   ├── DreamListView.swift          # 梦境列表视图，显示所有梦境
│   ├── DreamDetailView.swift        # 梦境详情视图
│   ├── DreamProcessingView.swift    # 梦境处理进度视图（全屏）
│   ├── ImmersiveView.swift          # 沉浸式3D展示视图
│   ├── ModelPreviewView.swift       # 窗口预览视图（SceneKit）
│   ├── ARQuickLookView.swift        # AR Quick Look 预览视图
│   ├── ErrorPanel3DView.swift      # 3D空间错误提示面板
│   ├── ProgressView.swift           # 进度显示组件
│   ├── ToggleImmersiveSpaceButton.swift # 沉浸式空间切换按钮
│   │
│   ├── AppModel.swift               # 应用状态管理（@Observable）
│   ├── DreamModel.swift             # 数据模型（Dream, DreamAnalysis）
│   ├── DreamStore.swift             # 数据存储和管理（持久化）
│   │
│   ├── APIService.swift             # API服务层（DeepSeek + Tripo3D）
│   ├── SpeechRecognitionService.swift # 语音识别服务
│   ├── ModelLoader.swift            # 3D模型加载器（缓存+格式转换）
│   ├── ModelExporter.swift          # 模型导出器
│   │
│   ├── DesignSystem.swift           # 设计系统（颜色、字体、组件）
│   ├── AccessibilitySupport.swift   # 无障碍支持
│   │
│   ├── Info.plist                   # 应用配置（API密钥、权限）
│   └── Assets.xcassets/            # 资源文件
│
├── Packages/
│   └── RealityKitContent/          # RealityKit 内容包
│
├── README.md                        # 项目文档（本文件）
└── VISIONOS_UI_DESIGN_SPEC.md      # UI设计规范文档
```

---

## 🚀 快速开始

### 环境要求

- **macOS**：macOS 14.0 或更高版本
- **Xcode**：Xcode 26.1 或更高版本
- **Apple Vision Pro**：真机设备（推荐）或模拟器
- **Apple Developer Account**：用于代码签名和部署

### 安装步骤

1. **克隆仓库**
   ```bash
   git clone https://github.com/wujiajunhahah/dreamvision.git
   cd dreamvision
   ```

2. **打开项目**
   ```bash
   open Dreamecho.xcodeproj
   ```

3. **配置 API 密钥**
   
   编辑 `Dreamecho/Info.plist`，添加你的 API 密钥：
   ```xml
   <key>DeepSeekAPIKey</key>
   <string>你的_DeepSeek_API_密钥</string>
   <key>TripoAPIKey</key>
   <string>你的_Tripo3D_API_密钥</string>
   ```
   
   > ⚠️ **重要**：不要将包含真实 API 密钥的 `Info.plist` 提交到 Git！

4. **配置开发者账号**
   - 在 Xcode 中选择项目
   - 进入 "Signing & Capabilities"
   - 选择你的 Team
   - 确保 Bundle Identifier 唯一

5. **连接设备**
   - 使用 USB-C 连接 Vision Pro 到 Mac
   - 在 Vision Pro 上信任此电脑
   - 在 Xcode 中选择设备

6. **运行项目**
   - 按 `Cmd + R` 或点击运行按钮
   - 等待编译和安装完成

### 首次运行

1. **授予权限**
   - 语音识别权限：用于语音输入
   - 麦克风权限：用于录制语音

2. **测试功能**
   - 输入一个梦境描述
   - 点击"生成梦境模型"
   - 等待模型生成完成
   - 在沉浸式空间中查看模型

---

## 🔑 API配置

### DeepSeek API

1. **获取 API 密钥**
   - 访问 [DeepSeek 官网](https://www.deepseek.com/)
   - 注册账号并获取 API 密钥

2. **配置密钥**
   - 在 `Info.plist` 中添加 `DeepSeekAPIKey`
   - 格式：`sk-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx`

### Tripo3D API

1. **获取 API 密钥**
   - 访问 [Tripo3D 官网](https://www.tripo3d.ai/)
   - 注册账号并获取 API 密钥

2. **配置密钥**
   - 在 `Info.plist` 中添加 `TripoAPIKey`
   - 格式：`tsk_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx`

3. **格式支持**
   - API 默认返回 GLB 格式
   - 应用会自动转换为 USDZ 格式
   - 转换后会自动验证文件可加载性

### API 使用说明

- **DeepSeek API**：用于梦境分析和提示词生成
- **Tripo3D API**：用于3D模型生成
- **格式转换**：如果 API 返回 GLB，会自动通过 Post-Process API 转换为 USDZ
- **错误处理**：完善的错误处理和重试机制

---

## 💻 开发指南

### 代码结构

#### 1. 应用入口 (`DreamechoApp.swift`)

```swift
@main
struct DreamechoApp: App {
    @State private var dreamStore = DreamStore()
    @State private var appModel = AppModel()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(dreamStore)
                .environment(appModel)
        }
        
        ImmersiveSpace(id: appModel.immersiveSpaceID) {
            ImmersiveView()
                .environment(appModel)
        }
    }
}
```

#### 2. 状态管理

- **`AppModel`**：应用全局状态（沉浸式空间状态、预览模式等）
- **`DreamStore`**：梦境数据管理（CRUD、持久化）

#### 3. API 服务

- **`APIService`**：统一的 API 调用接口
  - `analyzeDream()`：分析梦境
  - `generate3DModel()`：生成3D模型
  - `convertToUSDZ()`：格式转换
  - `validateUSDZFile()`：文件验证

#### 4. 模型加载

- **`ModelLoader`**：3D模型加载和缓存
  - 支持 USDZ 格式（推荐）
  - 自动缓存机制
  - 格式验证和错误处理

### 关键功能实现

#### 格式转换流程

```swift
// 1. API 返回 GLB
if normalizedPath.hasSuffix(".glb") {
    // 2. 转换为 USDZ
    let usdzURL = try await convertToUSDZ(sourceURL: url)
    
    // 3. 验证文件
    try await validateUSDZFile(url: usdzURL)
    
    // 4. 返回验证通过的 URL
    return usdzURL
}
```

#### 沉浸式空间管理

```swift
// 打开沉浸式空间
if appModel.immersiveSpaceState == .closed {
    appModel.immersiveSpaceState = .inTransition
    let result = await openImmersiveSpace(id: appModel.immersiveSpaceID)
    // 处理结果...
}

// 关闭沉浸式空间
if appModel.immersiveSpaceState == .open {
    await dismissImmersiveSpace()
    appModel.immersiveSpaceState = .closed
}
```

### 添加新功能

1. **添加新的视图**
   - 创建新的 SwiftUI View
   - 遵循设计系统规范
   - 使用 `@Environment` 访问共享状态

2. **扩展 API 服务**
   - 在 `APIService` 中添加新方法
   - 实现错误处理
   - 添加日志输出

3. **添加新的数据模型**
   - 在 `DreamModel.swift` 中定义
   - 实现 `Codable` 协议
   - 更新 `DreamStore` 的持久化逻辑

---

## 🎨 设计系统

### 颜色系统

```swift
// 主色调
DesignSystem.primaryColor        // 梦幻蓝 #3366E6
DesignSystem.accentColor         // 紫色 #9933CC

// 背景
DesignSystem.backgroundColor     // 深蓝渐变

// 文本
DesignSystem.primaryTextColor   // 白色
DesignSystem.secondaryTextColor // 半透明白色
```

### 组件使用

```swift
// 液态玻璃卡片
LiquidGlassCard {
    // 内容
}

// 液态玻璃按钮
LiquidGlassButton(
    "按钮文本",
    icon: "icon.name",
    style: .primary,
    isEnabled: true
) {
    // 操作
}
```

### 字体系统

```swift
DesignSystem.title1      // 大标题
DesignSystem.title2     // 中标题
DesignSystem.headline    // 标题
DesignSystem.body        // 正文
DesignSystem.caption     // 说明文字
```

---

## 🐛 常见问题

### 1. 编译错误

**问题**：`Cannot find type 'Entity' in scope`

**解决**：确保导入了 `RealityKit`
```swift
import RealityKit
```

### 2. API 错误

**问题**：`API authentication failed`

**解决**：
- 检查 `Info.plist` 中的 API 密钥是否正确
- 确认 API 密钥有效且有余额
- 检查网络连接

### 3. 模型加载失败

**问题**：`Failed to load model`

**解决**：
- 检查模型 URL 是否有效
- 确认网络连接正常
- 查看控制台日志获取详细错误信息

### 4. 沉浸式空间无法打开

**问题**：`Unable to present another Immersive Space`

**解决**：
- 确保当前没有其他沉浸式空间打开
- 等待状态转换完成后再操作
- 检查 `appModel.immersiveSpaceState` 状态

### 5. 语音识别不工作

**问题**：语音输入没有反应

**解决**：
- 检查是否授予了语音识别权限
- 检查是否授予了麦克风权限
- 确认设备支持语音识别功能

---

## 📝 开发注意事项

### 1. API 密钥安全

- ⚠️ **不要**将包含真实 API 密钥的 `Info.plist` 提交到 Git
- ✅ 使用 `.gitignore` 排除敏感文件
- ✅ 使用环境变量或配置文件管理密钥

### 2. 格式支持

- ✅ **USDZ**：visionOS 推荐格式，支持最佳
- ⚠️ **GLB**：会自动转换为 USDZ，但转换可能失败
- ❌ **其他格式**：不支持

### 3. 性能优化

- 使用模型缓存避免重复下载
- 异步加载模型避免阻塞主线程
- 及时释放不需要的资源

### 4. 错误处理

- 所有 API 调用都应该有错误处理
- 提供用户友好的错误提示
- 记录详细的错误日志便于调试

---

## 🔮 未来计划

- [ ] 支持更多3D模型格式
- [ ] 添加梦境分享功能
- [ ] 支持梦境编辑和重新生成
- [ ] 添加更多视觉效果和动画
- [ ] 支持梦境库搜索和筛选
- [ ] 添加梦境分类和标签
- [ ] 支持批量处理
- [ ] 添加导出功能（图片、视频）

---

## 📄 许可证

本项目为私有项目，保留所有权利。

---

## 👨‍💻 开发信息

- **开发环境**：Xcode 26.1
- **Swift版本**：Swift 6.0
- **部署目标**：visionOS 26.1+
- **最低支持版本**：visionOS 26.1

---

## 🙏 致谢

- [DeepSeek](https://www.deepseek.com/) - AI 分析服务
- [Tripo3D](https://www.tripo3d.ai/) - 3D 模型生成服务
- Apple - visionOS 平台和开发工具

---

<div align="center">

**DreamEcho** - 将梦境转化为现实 ✨

Made with ❤️ for Apple Vision Pro

</div>
