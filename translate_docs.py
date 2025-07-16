#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
繁体中文文档转简体中文脚本
使用OpenCC库进行繁简转换
"""

import os
import shutil
import logging
from pathlib import Path

# 设置日志
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('translation.log'),
        logging.StreamHandler()
    ]
)

def install_opencc():
    """安装OpenCC库"""
    import subprocess
    import sys
    
    try:
        import opencc
        logging.info("OpenCC已安装")
        return True
    except ImportError:
        logging.info("正在安装OpenCC...")
        try:
            subprocess.check_call([sys.executable, "-m", "pip", "install", "opencc-python-reimplemented"])
            logging.info("OpenCC安装成功")
            return True
        except subprocess.CalledProcessError as e:
            logging.error(f"OpenCC安装失败: {e}")
            return False

def convert_traditional_to_simplified(text):
    """将繁体中文转换为简体中文"""
    try:
        import opencc
        converter = opencc.OpenCC('t2s')  # 繁体到简体
        return converter.convert(text)
    except Exception as e:
        logging.error(f"转换失败: {e}")
        return text

def should_translate_file(filepath):
    """判断文件是否需要翻译"""
    # 只处理.md文件
    if not filepath.suffix.lower() == '.md':
        return False
    
    # 跳过一些可能不需要翻译的文件
    skip_files = {'.git', '__pycache__', '.DS_Store'}
    if filepath.name in skip_files:
        return False
    
    return True

def translate_markdown_file(input_path, output_path):
    """翻译单个markdown文件"""
    try:
        with open(input_path, 'r', encoding='utf-8') as f:
            content = f.read()
        
        # 检查是否包含繁体中文字符
        traditional_chars = set('習慣個們來說話時會與經過認識為這樣實現開發項目設計問題運行軟件版本')
        if not any(char in content for char in traditional_chars):
            logging.info(f"文件 {input_path.name} 似乎不包含繁体中文，跳过")
            return False
        
        # 进行繁简转换
        simplified_content = convert_traditional_to_simplified(content)
        
        # 创建输出目录
        output_path.parent.mkdir(parents=True, exist_ok=True)
        
        # 保存转换后的内容
        with open(output_path, 'w', encoding='utf-8') as f:
            f.write(simplified_content)
        
        logging.info(f"已翻译: {input_path} -> {output_path}")
        return True
        
    except Exception as e:
        logging.error(f"翻译文件 {input_path} 时出错: {e}")
        return False

def translate_directory(source_dir, target_dir):
    """翻译整个目录"""
    source_path = Path(source_dir)
    target_path = Path(target_dir)
    
    if not source_path.exists():
        logging.error(f"源目录不存在: {source_dir}")
        return
    
    # 创建目标目录
    target_path.mkdir(parents=True, exist_ok=True)
    
    translated_count = 0
    skipped_count = 0
    
    # 遍历源目录中的所有文件
    for file_path in source_path.rglob('*'):
        if file_path.is_file() and should_translate_file(file_path):
            # 计算相对路径
            relative_path = file_path.relative_to(source_path)
            output_path = target_path / relative_path
            
            if translate_markdown_file(file_path, output_path):
                translated_count += 1
            else:
                skipped_count += 1
        elif file_path.is_file():
            # 对于非markdown文件，直接复制
            relative_path = file_path.relative_to(source_path)
            output_path = target_path / relative_path
            output_path.parent.mkdir(parents=True, exist_ok=True)
            try:
                shutil.copy2(file_path, output_path)
                logging.info(f"已复制: {file_path} -> {output_path}")
            except Exception as e:
                logging.error(f"复制文件失败: {e}")
    
    logging.info(f"翻译完成! 翻译了 {translated_count} 个文件，跳过了 {skipped_count} 个文件")

def main():
    """主函数"""
    # 安装OpenCC
    if not install_opencc():
        return
    
    # 设置路径
    source_dir = "/Users/yangxinyi/opt/100_code/librime-lua/rime.wiki"
    target_dir = "/Users/yangxinyi/opt/100_code/librime-lua/rime.wiki-simplified"
    
    logging.info(f"开始翻译文档...")
    logging.info(f"源目录: {source_dir}")
    logging.info(f"目标目录: {target_dir}")
    
    # 执行翻译
    translate_directory(source_dir, target_dir)
    
    logging.info("所有翻译任务完成!")

if __name__ == "__main__":
    main()
