# Dreamecho 快速开始指南

## 🚀 一键部署

### 前置要求
- macOS 15.0+
- Xcode 26.1+
- visionOS Simulator 26.1+

### 步骤 1: 克隆项目
```bash
git clone https://github.com/wujiajunhahah/dreamvision.git
cd dreamvision
```

### 步骤 2: 安装依赖
```bash
# 安装Pixar USD工具链（用于3D模型转换）
brew install usd

# 验证安装
usd_from_gltf --version
```

### 步骤 3: 配置API密钥

#### 选项A: 编辑Info.plist（推荐）
1. 打开 `Dreamecho/Info.plist`
2. 添加以下配置：

```xml
<key>DeepSeekAPIKey</key>
<string>你的DeepSeek API密钥</string>

<key>TencentSecretId</key>
<string>你的腾讯云SecretId</string>

<key>TencentSecretKey</key>
<string>你的腾讯云SecretKey</string>

<key>BackendAPIKey</key>
<string>你的后端API密钥</string>
```

#### 选项B: 使用环境变量
```bash
# 复制示例文件
cp .env.example .env

# 编辑.env文件，填入你的API密钥
nano .env
```

### 步骤 4: 配置后端服务

更新 `Dreamecho/BackendAPIService.swift`:
```swift
private let baseURL = "https://your-backend-api.com"
```

### 步骤 5: 运行应用
```bash
# 打开Xcode项目
open Dreamecho.xcodeproj

# 或者直接构建
xcodebuild -project Dreamecho.xcodeproj -scheme Dreamecho -destination "platform=visionOS Simulator,name=Apple Vision Pro"
```

## 🧪 测试功能

### 1. 梦境分析测试
```bash
python3 tools/run_pipeline.py
```

### 2. 3D模型转换测试
```bash
export MODEL_URL="https://example.com/model.glb"
export NAME="test_model"
./tools/convert.sh
```

## 📱 真机部署

### 设备要求
- Apple Vision Pro 或 visionOS 兼容设备
- 开发者账号和证书

### 部署步骤
1. 在Xcode中选择你的visionOS设备
2. 配置开发证书和Bundle ID
3. 点击运行按钮

## 🆘 遇到问题？

### 常见问题
- **API密钥获取**: 查看 [API_SETUP.md](API_SETUP.md)
- **构建失败**: 检查Xcode版本和工具安装
- **3D模型不显示**: 验证构建阶段是否正常执行

### 获取帮助
- 📖 [详细开发文档](DEVELOPMENT.md)
- 🔧 [API配置指南](API_SETUP.md)
- 🐛 [故障排除](DEVELOPMENT.md#故障排除)

---

🎉 **配置完成后，你就可以开始体验梦境转3D模型的神奇之旅了！**