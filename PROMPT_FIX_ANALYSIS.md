# Rime Segment Prompt 光标位置问题分析与解决方案

## 问题描述

当输入 `nihaobeijing` 并设置 `segment.prompt = "> 搜索模式"` 时：

**期望显示：**
```
光标在末尾：   nihaobeijing^     > 搜索模式
光标左移一位： nihaobeijin^g     > 搜索模式
```

**实际显示：**
```
光标在末尾：   nihaobeijing^     > 搜索模式  ✓ 正确
光标左移一位： nihaobeijin^     > 搜索模式g  ✗ 错误！
```

字母 "g" 跑到了 prompt 的后面。

## 问题根源分析

通过分析 Rime 核心代码 `src/rime/composition.cc` 的 `GetPreedit` 方法，发现了问题的根本原因：

```cpp
// 在 composition.cc 的 GetPreedit 方法中
auto prompt = caret + GetPrompt();
if (!prompt.empty()) {
    // 关键问题：在光标位置插入 prompt
    preedit.text.insert(preedit.caret_pos, prompt);
    
    // 调整选择区域位置
    if (preedit.caret_pos < preedit.sel_start) {
        preedit.sel_start += prompt.length();
    }
    if (preedit.caret_pos < preedit.sel_end) {
        preedit.sel_end += prompt.length();
    }
}
```

**核心问题：** Rime 会在**光标当前位置**插入 prompt 字符串，而不是在 segment 末尾或其他固定位置。

## 问题演示

```
输入：nihaobeijing
位置：0123456789AB  (B=11)

初始状态 (光标在位置11)：
nihaobeijing^ + prompt插入在位置11 = nihaobeijing^     > 搜索模式

光标左移到位置10：
nihaobeijin^g + prompt插入在位置10 = nihaobeijin^     > 搜索模式g
```

## 解决方案

### 方案1：动态控制 prompt 显示（推荐）

```lua
-- 监听 context 更新事件
function init(env)
    env.notifier = env.engine.context.update_notifier:connect(function(ctx)
        local composition = ctx.composition
        if not composition:empty() then
            local last_seg = composition:back()
            local caret_pos = ctx.caret_pos
            local input_len = string.len(ctx.input)
            
            -- 只在光标位于输入末尾时显示 prompt
            if caret_pos >= input_len then
                last_seg.prompt = "> 搜索模式"
            else
                last_seg.prompt = ""  -- 隐藏 prompt 避免位置错乱
            end
        end
    end)
end

function fini(env)
    if env.notifier then
        env.notifier:disconnect()
    end
end
```

### 方案2：使用候选词的 preedit 属性

```lua
function translator(input, seg, env)
    -- 不设置 seg.prompt
    local candidate = Candidate("type", seg.start, seg._end, "结果", "")
    
    -- 使用 tab 分隔符控制显示
    -- tab 前是正常内容，tab 后是 prompt（只在光标末尾显示）
    candidate.preedit = input .. "\t> 搜索模式"
    
    yield(candidate)
end
```

### 方案3：processor 中处理光标移动

```lua
function processor(key, env)
    local context = env.engine.context
    local key_name = key:repr()
    
    -- 监听方向键
    if key_name == "Left" or key_name == "Right" or 
       key_name == "Home" or key_name == "End" then
        
        -- 重新评估 prompt 显示
        local composition = context.composition
        if not composition:empty() then
            local last_seg = composition:back()
            local caret_pos = context.caret_pos
            local input_len = string.len(context.input)
            
            if caret_pos >= input_len then
                last_seg.prompt = "> 搜索模式"
            else
                last_seg.prompt = ""
            end
        end
    end
    
    return 2 -- kNoop
end
```

## 推荐实现

使用**方案1**，因为它：
1. 最简洁直接
2. 自动处理所有光标移动情况
3. 不需要手动监听按键事件
4. 与现有代码兼容性最好

## 完整示例代码

```lua
local M = {}

function M.init(env)
    env.prompt_notifier = env.engine.context.update_notifier:connect(function(ctx)
        local composition = ctx.composition
        if not composition:empty() then
            local last_seg = composition:back()
            local caret_pos = ctx.caret_pos
            local input_len = string.len(ctx.input)
            
            -- 核心逻辑：动态控制 prompt 显示
            if caret_pos >= input_len then
                last_seg.prompt = "> 搜索模式"
            else
                last_seg.prompt = ""
            end
        end
    end)
end

function M.fini(env)
    if env.prompt_notifier then
        env.prompt_notifier:disconnect()
    end
end

function M.translator(input, seg, env)
    -- 你的翻译逻辑，不需要设置 seg.prompt
    local candidate = Candidate("type", seg.start, seg._end, "翻译结果", "")
    yield(candidate)
end

return M
```

## 技术要点总结

1. **问题根源：** Rime 在光标位置插入 prompt，导致光标右侧字符被推后
2. **解决思路：** 动态控制 prompt 显示，只在光标末尾时显示
3. **实现方法：** 监听 context.update_notifier 事件
4. **关键判断：** `caret_pos >= input_len` 决定是否显示 prompt
5. **避免：** 直接在 translator 中设置固定的 `seg.prompt`

这样就能确保显示效果为：
```
光标在末尾：   nihaobeijing^     > 搜索模式
光标左移一位： nihaobeijin^g     （无 prompt）
```
