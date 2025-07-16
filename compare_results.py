#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
简单的文档转换对比工具
"""

def show_conversion_examples():
    """展示一些转换前后的例子"""
    
    # 读取原始文件的前几行
    try:
        with open('/Users/yangxinyi/opt/100_code/librime-lua/rime.wiki/ComboPinyin.md', 'r', encoding='utf-8') as f:
            original_lines = f.readlines()[:20]
            
        with open('/Users/yangxinyi/opt/100_code/librime-lua/rime.wiki-simplified/ComboPinyin.md', 'r', encoding='utf-8') as f:
            simplified_lines = f.readlines()[:20]
            
        print("=== 宫保拼音文档转换对比 ===\n")
        
        for i, (orig, simp) in enumerate(zip(original_lines, simplified_lines)):
            orig = orig.strip()
            simp = simp.strip()
            
            if orig != simp and orig and simp:
                print(f"第 {i+1} 行:")
                print(f"  繁体: {orig}")
                print(f"  简体: {simp}")
                print()
                
    except Exception as e:
        print(f"读取文件出错: {e}")

def show_home_conversion():
    """展示首页文档的转换对比"""
    
    try:
        with open('/Users/yangxinyi/opt/100_code/librime-lua/rime.wiki/Home.md', 'r', encoding='utf-8') as f:
            original_content = f.read()
            
        with open('/Users/yangxinyi/opt/100_code/librime-lua/rime.wiki-simplified/Home.md', 'r', encoding='utf-8') as f:
            simplified_content = f.read()
            
        print("=== 首页文档转换对比 ===\n")
        print("繁体版本:")
        print(original_content[:300] + "...")
        print("\n简体版本:")
        print(simplified_content[:300] + "...")
        print()
        
    except Exception as e:
        print(f"读取文件出错: {e}")

def show_statistics():
    """显示转换统计信息"""
    import os
    
    original_dir = '/Users/yangxinyi/opt/100_code/librime-lua/rime.wiki'
    simplified_dir = '/Users/yangxinyi/opt/100_code/librime-lua/rime.wiki-simplified'
    
    original_files = []
    simplified_files = []
    
    # 统计原始目录中的md文件
    for root, dirs, files in os.walk(original_dir):
        for file in files:
            if file.endswith('.md'):
                original_files.append(file)
    
    # 统计转换后目录中的md文件
    for root, dirs, files in os.walk(simplified_dir):
        for file in files:
            if file.endswith('.md'):
                simplified_files.append(file)
    
    print("=== 转换统计信息 ===")
    print(f"原始目录 Markdown 文件数: {len(original_files)}")
    print(f"转换后目录 Markdown 文件数: {len(simplified_files)}")
    print(f"转换成功率: {len(simplified_files)}/{len(original_files)} = {len(simplified_files)/len(original_files)*100:.1f}%")
    print()
    
    print("转换的文件列表:")
    for file in sorted(simplified_files):
        print(f"  ✅ {file}")
    
    print("\n未转换的文件:")
    for file in sorted(set(original_files) - set(simplified_files)):
        print(f"  ⏭️ {file}")

if __name__ == "__main__":
    show_statistics()
    print("\n" + "="*50 + "\n")
    show_home_conversion()
    print("\n" + "="*50 + "\n")
    show_conversion_examples()
