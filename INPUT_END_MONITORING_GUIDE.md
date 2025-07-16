# Rime 输入结束事件监听完整指南

## 概述

在Rime中，可以通过多种通知器（notifier）来监听输入结束事件。本指南详细介绍了所有可用的监听方法和具体的实现方案。

## 可用的通知器

### 1. commit_notifier - 上屏事件监听
**最重要和最可靠的输入结束事件**

```lua
env.commit_notifier = context.commit_notifier:connect(function(ctx)
    local commit_text = ctx:get_commit_text()
    -- 用户上屏了内容
    print("上屏内容：" .. commit_text)
end)
```

**触发场景：**
- 用户按空格键确认候选词
- 用户按回车键确认输入
- 用户点击候选词
- 自动上屏（如果配置了auto_commit）

### 2. update_notifier - 状态变化监听
**用于检测输入框消失、内容清空等**

```lua
local last_input = ""
local last_composing = false

env.update_notifier = context.update_notifier:connect(function(ctx)
    local current_input = ctx.input or ""
    local current_composing = ctx:is_composing()
    
    -- 检测从有输入变为无输入
    if (last_input ~= "" or last_composing) and 
       (current_input == "" and not current_composing) then
        -- 输入框消失或被清空
        print("输入结束：" .. last_input)
    end
    
    last_input = current_input
    last_composing = current_composing
end)
```

**触发场景：**
- 切换到其他应用
- 点击其他地方，输入框失去焦点
- 按Escape键清空输入
- 输入内容被系统清空

### 3. delete_notifier - 删除事件监听
**检测输入被删除的情况**

```lua
env.delete_notifier = context.delete_notifier:connect(function(ctx)
    -- 如果输入被完全删除，也可能表示输入结束
    if not ctx:is_composing() then
        print("输入被删除完毕")
    end
end)
```

### 4. unhandled_key_notifier - 未处理按键监听
**检测可能导致输入结束的特殊按键**

```lua
env.unhandled_key_notifier = context.unhandled_key_notifier:connect(function(ctx, key)
    local key_repr = key:repr()
    
    -- 检测应用切换按键
    if key_repr:find("alt") or key_repr:find("cmd") then
        if ctx:is_composing() then
            print("可能切换应用，输入结束")
        end
    end
end)
```

## 完整的监听方案

### 基础方案（推荐新手）

```lua
local M = {}

function M.init(env)
    local context = env.engine.context
    
    -- 监听上屏事件
    env.commit_listener = context.commit_notifier:connect(function(ctx)
        local text = ctx:get_commit_text()
        print("用户上屏：" .. text)
        -- 在这里添加你的处理逻辑
    end)
end

function M.fini(env)
    if env.commit_listener then
        env.commit_listener:disconnect()
    end
end

return M
```

### 完整方案（检测所有情况）

```lua
local M = {}

function M.init(env)
    local context = env.engine.context
    
    -- 1. 上屏事件
    env.commit_notifier = context.commit_notifier:connect(function(ctx)
        M.handle_input_end("commit", ctx:get_commit_text(), ctx)
    end)
    
    -- 2. 状态变化
    env.last_input = ""
    env.last_composing = false
    
    env.update_notifier = context.update_notifier:connect(function(ctx)
        local current_input = ctx.input or ""
        local current_composing = ctx:is_composing()
        
        if (env.last_input ~= "" or env.last_composing) and 
           (current_input == "" and not current_composing) then
            M.handle_input_end("cancel", env.last_input, ctx)
        end
        
        env.last_input = current_input
        env.last_composing = current_composing
    end)
    
    -- 3. 删除事件
    env.delete_notifier = context.delete_notifier:connect(function(ctx)
        if not ctx:is_composing() and env.last_input ~= "" then
            M.handle_input_end("delete", env.last_input, ctx)
        end
    end)
end

function M.handle_input_end(reason, text, ctx)
    print("输入结束：" .. reason .. " - " .. text)
    -- 在这里添加你的处理逻辑
end

function M.fini(env)
    if env.commit_notifier then env.commit_notifier:disconnect() end
    if env.update_notifier then env.update_notifier:disconnect() end
    if env.delete_notifier then env.delete_notifier:disconnect() end
end

return M
```

## 实际使用场景

### 1. 记录输入历史

```lua
function M.handle_input_end(reason, text, ctx)
    local timestamp = os.date("%Y-%m-%d %H:%M:%S")
    local log_entry = string.format("[%s] %s: %s\n", timestamp, reason, text)
    
    local file = io.open(os.getenv("HOME") .. "/.rime_history.log", "a")
    if file then
        file:write(log_entry)
        file:close()
    end
end
```

### 2. 触发外部程序

```lua
function M.handle_input_end(reason, text, ctx)
    if reason == "commit" and string.len(text) > 0 then
        -- 将上屏内容传递给外部脚本
        local command = string.format('echo "%s" | /path/to/your/script.sh', 
                                       text:gsub('"', '\\"'))
        os.execute(command)
    end
end
```

### 3. 保存草稿

```lua
function M.handle_input_end(reason, text, ctx)
    if reason == "cancel" and string.len(text) > 2 then
        -- 保存未完成的输入作为草稿
        local timestamp = os.date("%Y%m%d_%H%M%S")
        local draft_file = os.getenv("HOME") .. "/.rime_drafts/draft_" .. timestamp .. ".txt"
        
        local file = io.open(draft_file, "w")
        if file then
            file:write(text)
            file:close()
        end
    end
end
```

### 4. 统计输入习惯

```lua
local stats = {commits = 0, cancels = 0, total_chars = 0}

function M.handle_input_end(reason, text, ctx)
    if reason == "commit" then
        stats.commits = stats.commits + 1
        stats.total_chars = stats.total_chars + string.len(text)
    elseif reason == "cancel" then
        stats.cancels = stats.cancels + 1
    end
    
    -- 定期保存统计信息
    if (stats.commits + stats.cancels) % 100 == 0 then
        M.save_stats()
    end
end
```

## 配置方法

### 1. 在 rime.lua 中注册

```lua
-- rime.lua
local input_monitor = require("your_monitor_module")

local function init(env)
    input_monitor.init(env)
end

local function fini(env)
    input_monitor.fini(env)
end

return {
    init = init,
    fini = fini
}
```

### 2. 在 schema 中配置

```yaml
# your_schema.schema.yaml
engine:
  translators:
    - lua_translator@your_monitor_module
```

## 注意事项

1. **内存管理**：必须在 `fini` 函数中调用 `disconnect()` 来避免内存泄露

2. **性能考虑**：`update_notifier` 触发频率很高，避免在其中执行耗时操作

3. **错误处理**：添加适当的错误处理，避免异常导致 Rime 崩溃

4. **文件操作**：注意文件权限和磁盘空间

5. **调试**：使用 `log.info()` 而不是 `print()` 进行调试

## 提供的示例文件

1. **`input_end_monitor.lua`** - 完整的监听方案，支持所有事件类型
2. **`simple_input_monitor.lua`** - 简化版本，专注于常用场景  
3. **`smart_input_recorder.lua`** - 实用的智能记录器，包含文件记录、草稿保存等功能

选择适合你需求的文件作为起点，然后根据具体需求进行修改。
