#!/bin/bash
# convert.sh - GLB/USD → USDZ → .reality 转换脚本
# 用法：MODEL_URL="url" NAME="model_name" ./tools/convert.sh

set -euo pipefail

# 参数检查
: "${MODEL_URL:?MODEL_URL is required}"
NAME="${NAME:-dreamecho_model}"

# 路径配置
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ASSETS_DIR="$ROOT/AppAssets/3D"
BUILD_DIR="$ROOT/AppAssets/Build"

# 创建目录
mkdir -p "$ASSETS_DIR" "$BUILD_DIR"

# 文件路径
GLB="$ASSETS_DIR/${NAME}.glb"
USD="$ASSETS_DIR/${NAME}.usda"
USDZ="$ASSETS_DIR/${NAME}.usdz"
REALITY="$BUILD_DIR/${NAME}.reality"

echo "🔄 Starting model conversion..."
echo "📦 Model URL: ${MODEL_URL:0:80}..."
echo "📝 Model Name: $NAME"

# 1. 下载模型文件
echo "📥 Step 1: Downloading model..."
if [[ "$MODEL_URL" == file://* ]]; then
    cp "${MODEL_URL#file://}" "$GLB"
else
    curl -fsSL "$MODEL_URL" -o "$GLB"
fi

# 验证文件大小
if [[ ! -s "$GLB" ]]; then
    echo "❌ Error: Downloaded file is empty"
    exit 1
fi

echo "✅ Downloaded: $(basename "$GLB") ($(stat -f%z "$GLB") bytes)"

# 2. 检测文件格式并选择转换路径
FILE_EXTENSION="${GLB##*.}"
echo "📋 File format: $FILE_EXTENSION"

case "$FILE_EXTENSION" in
    "usdz")
        echo "✅ File is already USDZ format, skipping GLB→USD conversion"
        USDZ="$GLB"
        ;;
    "usd")
        echo "✅ File is USD format, converting to USDZ..."
        usdzip "$USDZ" "$GLB"
        ;;
    "glb")
        echo "🔄 Converting GLB → USD → USDZ..."

        # GLB → USD (使用 Pixar USD 工具)
        if command -v usd_from_gltf >/dev/null 2>&1; then
            echo "📐 Using Pixar USD: usd_from_gltf"
            usd_from_gltf "$GLB" -o "$USD" --st
        elif command -v usdcat >/dev/null 2>&1; then
            echo "📐 Using usdcat (alternative)"
            usdcat "$GLB" > "$USD"
        else
            echo "❌ Error: Neither usd_from_gltf nor usdcat found. Please install Pixar USD tools:"
            echo "   brew install usd"
            exit 1
        fi

        # 验证USD文件
        if [[ ! -s "$USD" ]]; then
            echo "❌ Error: USD conversion failed"
            exit 1
        fi

        # USD → USDZ
        echo "📦 Converting USD → USDZ..."
        if command -v usdzip >/dev/null 2>&1; then
            usdzip "$USDZ" "$USD"
        else
            echo "❌ Error: usdzip not found. Please install Pixar USD tools:"
            echo "   brew install usd"
            exit 1
        fi
        ;;
    *)
        echo "❌ Error: Unsupported file format: $FILE_EXTENSION"
        echo "   Supported formats: GLB, USD, USDZ"
        exit 1
        ;;
esac

# 3. 验证USDZ文件
if [[ ! -s "$USDZ" ]]; then
    echo "❌ Error: USDZ file is empty or missing"
    exit 1
fi

echo "✅ USDZ file ready: $(basename "$USDZ") ($(stat -f%z "$USDZ") bytes)"

# 4. USDZ → .reality (使用Apple RealityKit)
echo "🚀 Converting USDZ → .reality..."
if command -v xcrun >/dev/null 2>&1; then
    xcrun realitytool convert \
        --input "$USDZ" \
        --output "$REALITY" \
        --noninteractive \
        --optimize materials transforms meshes
else
    echo "❌ Error: xcrun command not found. Please ensure Xcode command line tools are installed."
    exit 1
fi

# 5. 验证最终文件
if [[ ! -s "$REALITY" ]]; then
    echo "❌ Error: .reality file conversion failed"
    exit 1
fi

echo "🎉 Conversion completed successfully!"
echo "📁 Output files:"
echo "   📄 GLB:  $GLB"
echo "   📄 USD:  $USD"
echo "   📄 USDZ: $USDZ"
echo "   📄 .reality: $REALITY"

# 6. 输出构建信息（供Xcode Build Phase使用）
echo ""
echo "📋 Build Phase Information:"
echo "   NAME=$NAME"
echo "   REALITY_FILE=$REALITY"
echo "   BUILD_DIR=$BUILD_DIR"

# 7. 清理临时文件（可选）
# rm -f "$USD" "$GLB"

echo "✅ All done!"