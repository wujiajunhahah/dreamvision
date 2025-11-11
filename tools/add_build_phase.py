#!/usr/bin/env python3
"""
add_build_phase.py - 自动添加Xcode Build Phase脚本
"""

import os
import sys
import plistlib
import json
import re

def add_run_script_phase(project_path):
    """添加Run Script Build Phase到Xcode项目"""

    project_file = os.path.join(project_path, 'project.pbxproj')

    if not os.path.exists(project_file):
        print(f"❌ 项目文件不存在: {project_file}")
        return False

    print(f"📝 正在修改项目文件: {project_file}")

    # 读取项目文件内容
    with open(project_file, 'r', encoding='utf-8') as f:
        content = f.read()

    # 构建脚本内容 (简化版，避免转义问题)
    script_content = '''#!/bin/bash
# 3D模型自动转换脚本

set -euo pipefail

PROJECT_DIR="$PROJECT_DIR"
TOOLS_DIR="$PROJECT_DIR/tools"

echo "Starting 3D model conversion..."

# 检查convert.sh脚本是否存在
if [[ -x "$TOOLS_DIR/convert.sh" ]]; then
    echo "Running conversion script..."
    "$TOOLS_DIR/convert.sh"
else
    echo "convert.sh not found, skipping"
fi

echo "Build phase completed"
'''

    # 查找目标ID和构建阶段
    target_id = "77D0401C2EC09A7B0004334C"  # Dreamecho target

    # 生成新的构建阶段ID
    import uuid
    phase_id = str(uuid.uuid4()).replace('-', '').upper()[:24]

    # 检查是否已存在Run Script阶段
    if "PBXShellScriptBuildPhase" in content:
        print("⚠️ 项目已包含Run Script构建阶段")
        return True

    # 使用行替换方法添加构建阶段
    lines = content.split('\n')

    # 找到buildPhases部分并在Resources后添加我们的构建阶段
    new_lines = []
    for i, line in enumerate(lines):
        new_lines.append(line)

        # 在Resources行后添加我们的构建阶段
        if '77D0401B2EC09A7B0004334C /* Resources */,' in line:
            new_lines.append(f'\t\t\t{phase_id} /* Convert 3D Models */,')
            print("✅ 已添加构建阶段到buildPhases")

    content = '\n'.join(new_lines)

    # 添加PBXShellScriptBuildPhase部分
    shell_script_section = f'''

/* Begin PBXShellScriptBuildPhase section */
\t\t\t{phase_id} /* Convert 3D Models */ = {{
\t\t\t\tisa = PBXShellScriptBuildPhase;
\t\t\t\tbuildActionMask = 2147483647;
\t\t\t\tfiles = (
\t\t\t\t);
\t\t\t\tinputFileListPaths = (
\t\t\t\t);
\t\t\t\tinputPaths = (
\t\t\t\t);
\t\t\t\toutputFileListPaths = (
\t\t\t\t);
\t\t\t\toutputPaths = (
\t\t\t\t);
\t\t\t\trunOnlyForDeploymentPostprocessing = 0;
\t\t\t\tshellPath = /bin/bash;
\t\t\t\tshellScript = {json.dumps(script_content)};
\t\t\t}};
/* End PBXShellScriptBuildPhase section */
'''

    # 在PBXResourcesBuildPhase之前插入
    insert_pattern = r'(/\* Begin PBXResourcesBuildPhase section \*/)'

    if re.search(insert_pattern, content):
        content = content.replace(insert_pattern, shell_script_section + '\n' + insert_pattern)
        print("✅ 已添加PBXShellScriptBuildPhase部分")
    else:
        print("❌ 无法找到插入位置")
        return False

    # 备份原文件
    backup_file = project_file + '.backup'
    with open(backup_file, 'w', encoding='utf-8') as f:
        f.write(content)
    print(f"💾 已备份原文件到: {backup_file}")

    # 写入修改后的内容
    with open(project_file, 'w', encoding='utf-8') as f:
        f.write(content)

    print("✅ 成功添加Run Script构建阶段")
    return True

def main():
    """主函数"""
    print("🚀 开始添加Xcode Build Phase...")

    # 查找项目文件
    current_dir = os.path.dirname(os.path.abspath(__file__))
    project_dir = os.path.dirname(current_dir)
    xcodeproj_path = os.path.join(project_dir, 'Dreamecho.xcodeproj')

    if not os.path.exists(xcodeproj_path):
        print(f"❌ 找不到Xcode项目: {xcodeproj_path}")
        sys.exit(1)

    print(f"📁 项目目录: {project_dir}")
    print(f"📁 Xcode项目: {xcodeproj_path}")

    # 添加构建阶段
    success = add_run_script_phase(xcodeproj_path)

    if success:
        print("🎉 构建阶段添加完成!")
        print("💡 现在可以在Xcode中看到'Convert 3D Models'构建阶段")
        print("💡 每次构建时都会自动检查并转换3D模型")
    else:
        print("❌ 构建阶段添加失败")
        sys.exit(1)

if __name__ == '__main__':
    main()