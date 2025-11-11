#!/usr/bin/env python3
"""
run_pipeline.py - 一键流水线脚本：提交→轮询→下载→转换
"""

import os
import json
import time
import pathlib
import sys
import urllib.request
import urllib.error
import subprocess
import shutil
from datetime import datetime

# 配置
ROOT = pathlib.Path(__file__).resolve().parents[1]
BACKEND_BASE_URL = os.environ.get('BACKEND_BASE_URL', 'https://your-backend-api.com')
BACKEND_API_KEY = os.environ.get('BACKEND_API_KEY', '')

# 文件路径
MODELS_JSON = ROOT / 'AppAssets' / 'models.json'
LOG_FILE = ROOT / 'tools' / 'pipeline.log'

def log(message):
    """记录日志"""
    timestamp = datetime.now().strftime('%Y-%m-%d %H:%M:%S')
    with open(LOG_FILE, 'a', encoding='utf-8') as f:
        f.write(f"[{timestamp}] {message}\n")
    print(f"[{timestamp}] {message}")

def download_file(url: str, output_path: pathlib.Path) -> bool:
    """下载文件"""
    try:
        log(f"Downloading: {url[:80]}...")

        # 创建HEAD请求检查文件存在
        req = urllib.request.Request(url, method='HEAD')
        try:
            with urllib.request.urlopen(req, timeout=10) as response:
                content_length = response.headers.get('Content-Length')
                log(f"File size: {content_length} bytes")
        except:
            pass  # HEAD请求失败不影响下载

        # 下载文件
        urllib.request.urlretrieve(url, output_path)

        # 验证文件大小
        file_size = output_path.stat().st_size
        if file_size == 0:
            log(f"Error: Downloaded file is empty")
            return False

        log(f"Downloaded successfully: {output_path.name} ({file_size} bytes)")
        return True

    except Exception as e:
        log(f"Download failed: {e}")
        return False

def validate_file(url: str) -> bool:
    """验证文件URL可访问"""
    try:
        req = urllib.request.Request(url, method='HEAD', timeout=10)
        with urllib.request.urlopen(req) as response:
            return response.status == 200
    except Exception as e:
        log(f"File validation failed: {e}")
        return False

def submit_generation_task(description: str, analysis: dict = None) -> str:
    """提交3D生成任务"""
    url = f"{BACKEND_BASE_URL}/dreams/3d"

    payload = {
        "description": description,
        "analysis": analysis or {
            "keywords": [],
            "emotions": [],
            "visualDescription": ""
        },
        "quality": "high",
        "format": "glb"  # 优先GLB，支持转换为USDZ
    }

    headers = {
        'Content-Type': 'application/json',
        'Authorization': f'Bearer {BACKEND_API_KEY}'
    }

    data = json.dumps(payload).encode('utf-8')
    req = urllib.request.Request(url, data=data, headers=headers, method='POST')

    log(f"Submitting task to: {url}")

    try:
        with urllib.request.urlopen(req, timeout=30) as response:
            if response.status == 200:
                result = json.loads(response.read().decode('utf-8'))
                task_id = result.get('taskId')
                if task_id:
                    log(f"Task submitted successfully: {task_id}")
                    return task_id
                else:
                    log("Error: No taskId in response")
                    raise Exception("No taskId in response")
            else:
                error_data = response.read().decode('utf-8')
                log(f"HTTP {response.status}: {error_data}")
                raise Exception(f"HTTP {response.status}")

    except Exception as e:
        log(f"Failed to submit task: {e}")
        raise

def poll_task_status(task_id: str, max_attempts: int = 60, interval: int = 2) -> dict:
    """轮询任务状态"""
    url = f"{BACKEND_BASE_URL}/dreams/3d/{task_id}"

    headers = {
        'Authorization': f'Bearer {BACKEND_API_KEY}'
    }

    log(f"Polling task status: {task_id}")

    for attempt in range(max_attempts):
        req = urllib.request.Request(url, headers=headers, method='GET')

        try:
            with urllib.request.urlopen(req, timeout=10) as response:
                if response.status == 200:
                    result = json.loads(response.read().decode('utf-8'))
                    status = result.get('status', 'unknown').lower()

                    log(f"Attempt {attempt + 1}/{max_attempts}: Status = {status}")

                    if status == 'completed':
                        download_url = result.get('downloadUrl')
                        file_format = result.get('format', 'unknown')

                        if download_url:
                            log(f"✅ Task completed!")
                            log(f"Download URL: {download_url[:80]}...")
                            log(f"File format: {file_format}")

                            # 验证下载链接
                            if validate_file(download_url):
                                return {
                                    'status': 'completed',
                                    'download_url': download_url,
                                    'format': file_format
                                }
                            else:
                                log("⚠️ Warning: Download URL validation failed")
                                return {
                                    'status': 'completed',
                                    'download_url': download_url,
                                    'format': file_format,
                                    'validation_failed': True
                                }
                        else:
                            log("⚠️ Warning: No download URL in response")
                            return {
                                'status': 'completed',
                                'download_url': None,
                                'format': file_format
                            }

                    elif status == 'failed':
                        log(f"❌ Task failed")
                        return {'status': 'failed'}

                    elif status in ['pending', 'processing', 'unknown']:
                        if attempt < max_attempts - 1:
                            time.sleep(interval)
                            continue
                        else:
                            log(f"⏰ Timeout after {max_attempts} attempts")
                            return {'status': 'timeout'}

                else:
                    error_data = response.read().decode('utf-8')
                    log(f"HTTP {response.status}: {error_data}")
                    return {'status': 'error', 'http_status': response.status}

        except Exception as e:
            log(f"Polling attempt {attempt + 1} failed: {e}")
            if attempt < max_attempts - 1:
                time.sleep(interval)
                continue
            else:
                return {'status': 'network_error'}

    return {'status': 'unknown_error'}

def write_models_json(model_info: dict):
    """写入models.json文件"""
    try:
        # 确保目录存在
        MODELS_JSON.parent.mkdir(parents=True, exist_ok=True)

        # 读取现有数据（如果有）
        if MODELS_JSON.exists():
            with open(MODELS_JSON, 'r', encoding='utf-8') as f:
                existing_data = json.load(f)
        else:
            existing_data = {'models': []}

        # 添加新模型信息
        existing_data['models'].append(model_info)

        # 写入文件
        with open(MODELS_JSON, 'w', encoding='utf-8') as f:
            json.dump(existing_data, f, indent=2, ensure_ascii=False)

        log(f"✅ Updated models.json: {len(existing_data['models'])} models")

    except Exception as e:
        log(f"Failed to write models.json: {e}")
        raise

def run_convert_script(model_url: str, model_name: str) -> bool:
    """运行convert.sh脚本"""
    convert_script = ROOT / 'tools' / 'convert.sh'

    if not convert_script.exists():
        log(f"❌ Error: convert.sh not found at {convert_script}")
        return False

    # 设置环境变量
    env = os.environ.copy()
    env['MODEL_URL'] = model_url
    env['NAME'] = model_name

    log(f"Running convert.sh with MODEL_URL={model_url[:50]}...")

    try:
        result = subprocess.run(
            [str(convert_script)],
            env=env,
            cwd=convert_script.parent,
            capture_output=True,
            text=True,
            timeout=300  # 5分钟超时
        )

        if result.returncode == 0:
            log("✅ convert.sh completed successfully")
            log(f"Output: {result.stdout}")
            return True
        else:
            log(f"❌ convert.sh failed: {result.stderr}")
            return False

    except subprocess.TimeoutExpired:
        log("❌ convert.sh timed out after 5 minutes")
        return False
    except Exception as e:
        log(f"❌ Failed to run convert.sh: {e}")
        return False

def main():
    """主函数"""
    log("=" * 50)
    log("🚀 Starting 3D Model Generation Pipeline")
    log("=" * 50)

    try:
        # 检查配置
        if not BACKEND_API_KEY:
            log("❌ Error: BACKEND_API_KEY environment variable not set")
            sys.exit(1)

        # 示例梦境描述（在实际使用中应该从外部获取）
        dream_description = "A dream about flying through clouds with a sense of freedom and wonder"

        dream_analysis = {
            "keywords": ["flying", "clouds", "freedom", "wonder"],
            "emotions": ["peaceful", "excited", "liberated"],
            "visualDescription": "A figure soaring through fluffy white clouds in a bright blue sky, arms outstretched, with a peaceful expression"
        }

        log(f"📝 Dream: {dream_description[:50]}...")

        # 1. 提交任务
        log("📋 Step 1: Submitting generation task...")
        task_id = submit_generation_task(dream_description, dream_analysis)

        # 2. 轮询状态
        log("⏳ Step 2: Polling task status...")
        final_status = poll_task_status(task_id)

        if final_status['status'] == 'completed':
            download_url = final_status['download_url']
            model_name = "dreamecho_model"

            if download_url:
                # 3. 验证下载链接
                log("🔍 Step 3: Validating download URL...")

                if final_status.get('validation_failed'):
                    log("⚠️ Warning: Download URL validation failed, but continuing...")

                # 4. 写入models.json
                log("📝 Step 4: Writing to models.json...")
                model_info = {
                    'name': model_name,
                    'url': download_url,
                    'description': dream_description,
                    'analysis': dream_analysis,
                    'timestamp': datetime.now().isoformat(),
                    'task_id': task_id
                }
                write_models_json(model_info)

                # 5. 运行转换脚本（可选，Xcode Build Phase会自动执行）
                if '--convert' in sys.argv:
                    log("🔄 Step 5: Running conversion script...")
                    success = run_convert_script(download_url, model_name)
                    if not success:
                        log("⚠️ Warning: conversion failed, but pipeline completed")

                log("=" * 50)
                log("🎉 Pipeline completed successfully!")
                log(f"📦 Final model: {model_name}")
                log(f"🔗 Download URL: {download_url}")
                log("=" * 50)

            else:
                log("❌ Error: No download URL available")
                sys.exit(1)
        else:
            log(f"❌ Task failed with status: {final_status['status']}")
            sys.exit(1)

    except KeyboardInterrupt:
        log("\n🛑 Pipeline cancelled by user")
        sys.exit(1)
    except Exception as e:
        log(f"❌ Pipeline failed: {e}")
        sys.exit(1)

if __name__ == '__main__':
    main()