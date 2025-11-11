# Reality Composer Pro 集成指南

本项目已集成 Reality Composer Pro 工作流，用于优化和预览 3D 模型。

## 工作流程

### 1. 模型生成流程

```
用户输入梦境
    ↓
DeepSeek 分析梦境
    ↓
生成3D模型提示词
    ↓
腾讯混元生3D API（请求USDZ格式）
    ↓
返回USDZ下载URL
    ↓
写入 AppAssets/models.json
    ↓
Xcode Build Phase 自动下载并转换
    ↓
realitytool 转换为 .reality（Reality Composer Pro 工具）
    ↓
打包到 RealityKitContent 包
    ↓
App 运行时优先加载 .reality 文件
```

### 2. Xcode Build Phase 配置

在 Xcode 中添加 Run Script Phase（在 "Compile Sources" 之前）：

```bash
# Reality Composer Pro 工作流：自动下载并转换模型
CONFIG_JSON="${SRCROOT}/AppAssets/models.json"

if [ -f "$CONFIG_JSON" ]; then
  /usr/bin/python3 - <<'PY'
import os, json, subprocess, urllib.request
from pathlib import Path

root = Path(os.environ['SRCROOT'])
config_file = root / 'AppAssets' / 'models.json'
build_dir = root / 'AppAssets' / 'Build'
realitykit_dir = root / 'Packages' / 'RealityKitContent' / 'Sources' / 'RealityKitContent' / 'RealityKitContent.rkassets'

build_dir.mkdir(parents=True, exist_ok=True)
realitykit_dir.mkdir(parents=True, exist_ok=True)

with open(config_file) as f:
    cfg = json.load(f)

for item in cfg.get('models', []):
    url = item['url']
    name = item.get('name', 'dreamecho_model')
    
    # 下载USDZ
    usdz_path = build_dir / f"{name}.usdz"
    print(f"📥 Downloading {name} from {url[:50]}...")
    urllib.request.urlretrieve(url, usdz_path)
    
    # 转换为 .reality（使用 realitytool，Reality Composer Pro 工具）
    reality_path = realitykit_dir / f"{name}.reality"
    print(f"🔄 Converting to .reality using realitytool...")
    subprocess.check_call([
        'xcrun', 'realitytool', 'convert',
        '--input', str(usdz_path),
        '--output', str(reality_path),
        '--noninteractive',
        '--optimize', 'materials', 'transforms', 'meshes'
    ])
    
    print(f"✅ {name}.reality created in RealityKitContent package")

PY
fi
```

### 3. 模型加载优先级

App 运行时按以下优先级加载模型：

1. **RealityKitContent 包中的 .reality 文件**（最优）
   - 构建期优化，性能最佳
   - 使用 `realityKitContentBundle.url(forResource:withExtension:)`

2. **主 Bundle 中的 .reality 文件**
   - 备选方案

3. **运行时下载 USDZ**（回退方案）
   - 如果构建期转换未完成，使用运行时下载

### 4. 优势

- ✅ **性能优化**：.reality 格式经过 Reality Composer Pro 优化
- ✅ **材质优化**：自动优化材质、变换和网格
- ✅ **构建期处理**：不占用运行时资源
- ✅ **原生工具**：使用 Xcode 自带的 `realitytool`
- ✅ **无缝集成**：与 Xcode 构建流程完美集成

### 5. 手动使用 Reality Composer Pro

如果需要手动编辑模型：

1. 打开 Xcode
2. 在项目导航器中找到 `Packages/RealityKitContent`
3. 双击 `.reality` 文件
4. Reality Composer Pro 会自动打开
5. 进行编辑和预览
6. 保存后会自动集成到构建流程

### 6. 注意事项

- `realitytool` 是 Xcode 自带的命令行工具，无需额外安装
- `.reality` 文件会自动打包到 RealityKitContent 包中
- 确保 `AppAssets/models.json` 格式正确
- Build Phase 脚本会在每次构建时执行

