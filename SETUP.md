# Dreamecho 项目设置指南

## 🚀 快速开始

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

你需要获取以下API密钥：

1. **DeepSeek AI API密钥**
   - 访问: https://platform.deepseek.com/
   - 注册账号并创建API密钥

2. **腾讯云混元API凭证**
   - 访问: https://console.cloud.tencent.com/cam/capi
   - 创建SecretId和SecretKey

3. **后端服务API密钥**
   - 需要部署后端代理服务或获取API密钥

### 步骤 4: 配置应用

#### 方法A: 编辑Info.plist
在 `Dreamecho/Info.plist` 中添加：

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

#### 方法B: 使用环境变量
```bash
# 复制示例文件
cp .env.example .env

# 编辑.env文件，填入你的API密钥
```

### 步骤 5: 配置后端服务

更新 `Dreamecho/BackendAPIService.swift`:
```swift
private let baseURL = "https://your-backend-api.com"
```

### 步骤 6: 运行应用
```bash
# 打开Xcode项目
open Dreamecho.xcodeproj

# 或直接构建
xcodebuild -project Dreamecho.xcodeproj -scheme Dreamecho
```

## 🧪 测试功能

### 1. 完整流水线测试
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

1. 在Xcode中选择你的visionOS设备
2. 配置开发证书和Bundle ID
3. 点击运行按钮

## 🆘 获取帮助

如果遇到问题：
1. 检查API密钥配置是否正确
2. 确认网络连接正常
3. 查看Xcode控制台日志

## 🔧 后端API端点

应用期望以下后端API端点：

### 提交3D生成任务
```
POST /dreams/3d
Content-Type: application/json
Authorization: Bearer {API_KEY}

{
  "description": "梦境描述",
  "analysis": {
    "keywords": ["关键词"],
    "emotions": ["情感"],
    "visualDescription": "视觉描述"
  },
  "quality": "high",
  "format": "glb"
}
```

### 查询任务状态
```
GET /dreams/3d/{taskId}
Authorization: Bearer {API_KEY}
```

---

🎉 **配置完成后，你就可以开始体验梦境转3D模型的功能了！**