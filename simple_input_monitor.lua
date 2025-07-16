--[[
简化版输入结束监听器示例
专注于最常用的场景：内容上屏和输入框消失

使用场景示例：
1. 记录用户的输入历史
2. 在输入结束时触发外部程序
3. 统计用户的输入习惯
4. 自动保存草稿等
--]]

local log = require("log")

local M = {}

-- ========== 核心监听逻辑 ==========

function M.init(env)
    local context = env.engine.context
    
    -- 方案1：监听上屏事件（最可靠的输入结束检测）
    env.commit_listener = context.commit_notifier:connect(function(ctx)
        local commit_text = ctx:get_commit_text()
        
        -- 在这里添加你的自定义操作
        M.handle_input_committed(commit_text, ctx)
    end)
    
    -- 方案2：监听输入状态变化（检测输入框消失）
    env.last_input = ""
    env.last_composing = false
    
    env.update_listener = context.update_notifier:connect(function(ctx)
        local current_input = ctx.input or ""
        local current_composing = ctx:is_composing()
        
        -- 检测从有输入变为无输入（输入框消失或被清空）
        if (env.last_input ~= "" or env.last_composing) and 
           (current_input == "" and not current_composing) then
            
            -- 输入框消失或被清空
            M.handle_input_cancelled(env.last_input, ctx)
        end
        
        -- 更新状态
        env.last_input = current_input
        env.last_composing = current_composing
    end)
end

-- ========== 自定义处理函数 ==========

-- 处理内容上屏
function M.handle_input_committed(text, ctx)
    log.info("用户上屏了内容：'" .. text .. "'")
    
    -- 示例1：记录到文件
    M.log_to_file("COMMIT", text)
    
    -- 示例2：触发外部命令
    -- M.trigger_external_command(text)
    
    -- 示例3：更新用户词频统计
    -- M.update_word_frequency(text)
    
    -- 示例4：发送到剪贴板历史
    -- M.add_to_clipboard_history(text)
end

-- 处理输入取消（输入框消失）
function M.handle_input_cancelled(text, ctx)
    if text ~= "" then
        log.info("输入被取消，内容：'" .. text .. "'")
        
        -- 示例1：保存草稿
        M.save_draft(text)
        
        -- 示例2：记录未完成的输入
        M.log_to_file("CANCEL", text)
    end
end

-- ========== 具体实现示例 ==========

-- 记录到文件
function M.log_to_file(action, text)
    local timestamp = os.date("%Y-%m-%d %H:%M:%S")
    local log_line = string.format("[%s] %s: %s\n", timestamp, action, text)
    
    -- 写入到用户目录下的日志文件
    local log_file = io.open(os.getenv("HOME") .. "/.rime_input_history.log", "a")
    if log_file then
        log_file:write(log_line)
        log_file:close()
        log.info("已记录到文件：" .. log_line:gsub("\n", ""))
    end
end

-- 保存草稿
function M.save_draft(text)
    local timestamp = os.date("%Y%m%d_%H%M%S")
    local draft_file = os.getenv("HOME") .. "/.rime_drafts/" .. timestamp .. ".txt"
    
    -- 确保目录存在
    os.execute("mkdir -p " .. os.getenv("HOME") .. "/.rime_drafts")
    
    local file = io.open(draft_file, "w")
    if file then
        file:write(text)
        file:close()
        log.info("草稿已保存：" .. draft_file)
    end
end

-- 触发外部命令
function M.trigger_external_command(text)
    -- 示例：将上屏的文本传递给外部脚本
    local command = string.format('echo "%s" | /path/to/your/script.sh', text:gsub('"', '\\"'))
    os.execute(command)
end

-- 更新词频统计
function M.update_word_frequency(text)
    -- 这里可以实现简单的词频统计
    -- 将文本分解为词语并统计使用频率
    local words = {}
    for word in text:gmatch("[\u4e00-\u9fff]+") do -- 匹配中文
        table.insert(words, word)
    end
    
    if #words > 0 then
        log.info("检测到 " .. #words .. " 个中文词语")
        -- 在这里实现具体的统计逻辑
    end
end

-- 添加到剪贴板历史
function M.add_to_clipboard_history(text)
    -- 示例：使用系统命令更新剪贴板
    local command = string.format('echo "%s" | pbcopy', text:gsub('"', '\\"'))
    os.execute(command)
    log.info("已添加到剪贴板：" .. text)
end

-- ========== 清理函数 ==========

function M.fini(env)
    if env.commit_listener then
        env.commit_listener:disconnect()
    end
    
    if env.update_listener then
        env.update_listener:disconnect()
    end
    
    log.info("输入监听器已清理")
end

-- ========== 实际使用示例 ==========

--[[
在你的 rime.lua 文件中：

local input_monitor = require("simple_input_monitor")

local function init(env)
    input_monitor.init(env)
end

local function fini(env)
    input_monitor.fini(env)
end

-- 如果你有其他的translator或processor
local function your_translator(input, seg, env)
    -- 你的翻译逻辑
    yield(Candidate("type", seg.start, seg._end, "结果", ""))
end

return {
    init = init,
    fini = fini,
    translator = your_translator  -- 可选
}

然后在你的schema配置中引用：
engine:
  translators:
    - lua_translator@your_module_name
--]]

return M
