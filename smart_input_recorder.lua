--[[
具体使用场景演示：智能输入记录器
功能：
1. 记录所有上屏的内容到历史文件
2. 保存未完成的输入作为草稿
3. 统计输入习惯
4. 支持外部程序集成

配置方法：
1. 将此文件放入 rime 用户目录下的 lua 文件夹
2. 在 rime.lua 中注册：
   smart_recorder_init = require("smart_input_recorder").init
   smart_recorder_fini = require("smart_input_recorder").fini

3. 在 schema 中配置（可选）：
   engine:
     translators:
       - lua_translator@smart_recorder
--]]

local log = require("log")

local M = {}

-- ========== 配置选项 ==========

local config = {
    -- 是否启用文件记录
    enable_file_logging = true,
    
    -- 历史文件路径
    history_file = os.getenv("HOME") .. "/.rime_input_history.txt",
    
    -- 草稿目录
    draft_dir = os.getenv("HOME") .. "/.rime_drafts",
    
    -- 是否启用统计
    enable_statistics = true,
    
    -- 统计文件
    stats_file = os.getenv("HOME") .. "/.rime_input_stats.txt",
    
    -- 最小记录长度（少于此长度的输入不记录）
    min_record_length = 1,
    
    -- 是否启用外部命令
    enable_external_command = false,
    
    -- 外部命令模板
    external_command_template = 'echo "Rime输入: %s" >> /tmp/rime_notify.log'
}

-- ========== 内部状态 ==========

local state = {
    session_start_time = os.time(),
    total_commits = 0,
    total_cancels = 0,
    longest_input = "",
    last_input = "",
    last_composing = false
}

-- ========== 初始化和清理 ==========

function M.init(env)
    log.info("智能输入记录器启动")
    
    -- 确保目录存在
    if config.enable_file_logging then
        os.execute("mkdir -p " .. config.draft_dir)
        M.ensure_file_exists(config.history_file)
        M.ensure_file_exists(config.stats_file)
    end
    
    local context = env.engine.context
    
    -- 监听上屏事件
    env.commit_notifier = context.commit_notifier:connect(function(ctx)
        local commit_text = ctx:get_commit_text()
        M.on_commit(commit_text, ctx)
    end)
    
    -- 监听输入状态变化
    env.update_notifier = context.update_notifier:connect(function(ctx)
        M.on_update(ctx)
    end)
    
    -- 记录会话开始
    M.log_session_event("SESSION_START")
end

function M.fini(env)
    -- 记录会话结束
    M.log_session_event("SESSION_END")
    
    -- 断开连接
    if env.commit_notifier then
        env.commit_notifier:disconnect()
    end
    
    if env.update_notifier then
        env.update_notifier:disconnect()
    end
    
    -- 保存统计信息
    if config.enable_statistics then
        M.save_session_stats()
    end
    
    log.info("智能输入记录器已停止")
end

-- ========== 事件处理 ==========

function M.on_commit(text, ctx)
    if string.len(text) < config.min_record_length then
        return
    end
    
    state.total_commits = state.total_commits + 1
    
    -- 更新最长输入记录
    if string.len(text) > string.len(state.longest_input) then
        state.longest_input = text
    end
    
    log.info("记录上屏：'" .. text .. "' (第" .. state.total_commits .. "次)")
    
    -- 记录到文件
    if config.enable_file_logging then
        M.log_to_history_file("COMMIT", text)
    end
    
    -- 触发外部命令
    if config.enable_external_command then
        M.execute_external_command(text)
    end
    
    -- 更新统计
    if config.enable_statistics then
        M.update_statistics("commit", text)
    end
end

function M.on_update(ctx)
    local current_input = ctx.input or ""
    local current_composing = ctx:is_composing()
    
    -- 检测输入取消
    if (state.last_input ~= "" or state.last_composing) and 
       (current_input == "" and not current_composing) then
        
        if string.len(state.last_input) >= config.min_record_length then
            M.on_cancel(state.last_input, ctx)
        end
    end
    
    -- 更新状态
    state.last_input = current_input
    state.last_composing = current_composing
end

function M.on_cancel(text, ctx)
    state.total_cancels = state.total_cancels + 1
    
    log.info("记录取消：'" .. text .. "' (第" .. state.total_cancels .. "次)")
    
    -- 保存草稿
    if config.enable_file_logging then
        M.save_draft(text)
        M.log_to_history_file("CANCEL", text)
    end
    
    -- 更新统计
    if config.enable_statistics then
        M.update_statistics("cancel", text)
    end
end

-- ========== 文件操作 ==========

function M.ensure_file_exists(filepath)
    local file = io.open(filepath, "a")
    if file then
        file:close()
    end
end

function M.log_to_history_file(action, text)
    local timestamp = os.date("%Y-%m-%d %H:%M:%S")
    local log_entry = string.format("[%s] %s: %s\n", timestamp, action, text)
    
    local file = io.open(config.history_file, "a")
    if file then
        file:write(log_entry)
        file:close()
    end
end

function M.save_draft(text)
    local timestamp = os.date("%Y%m%d_%H%M%S")
    local draft_file = config.draft_dir .. "/draft_" .. timestamp .. ".txt"
    
    local file = io.open(draft_file, "w")
    if file then
        file:write(text)
        file:close()
        log.info("草稿已保存：" .. draft_file)
    end
end

function M.log_session_event(event)
    local timestamp = os.date("%Y-%m-%d %H:%M:%S")
    local log_entry = string.format("[%s] %s\n", timestamp, event)
    
    if config.enable_file_logging then
        local file = io.open(config.history_file, "a")
        if file then
            file:write(log_entry)
            file:close()
        end
    end
end

-- ========== 统计功能 ==========

function M.update_statistics(action, text)
    local char_count = string.len(text)
    local word_count = M.count_words(text)
    
    -- 这里可以实现更复杂的统计逻辑
    -- 比如字符频率、词汇频率、输入模式等
end

function M.count_words(text)
    local count = 0
    -- 简单的中文词汇计数
    for _ in text:gmatch("[\u4e00-\u9fff]+") do
        count = count + 1
    end
    return count
end

function M.save_session_stats()
    local session_duration = os.time() - state.session_start_time
    local stats_data = string.format(
        "会话时长: %d秒\n上屏次数: %d\n取消次数: %d\n最长输入: %s\n\n",
        session_duration,
        state.total_commits,
        state.total_cancels,
        state.longest_input
    )
    
    local timestamp = os.date("%Y-%m-%d %H:%M:%S")
    local stats_entry = string.format("[%s] %s", timestamp, stats_data)
    
    local file = io.open(config.stats_file, "a")
    if file then
        file:write(stats_entry)
        file:close()
    end
end

-- ========== 外部集成 ==========

function M.execute_external_command(text)
    local safe_text = text:gsub("'", "\\'"):gsub('"', '\\"')
    local command = string.format(config.external_command_template, safe_text)
    
    os.execute(command)
end

-- ========== 可选的Translator接口 ==========

-- 如果你想要这个模块也提供翻译功能，可以实现这个函数
function M.translator(input, seg, env)
    -- 这里可以添加一些特殊的翻译逻辑
    -- 比如显示输入统计信息等
    
    if input == "/stats" then
        local stats_text = string.format(
            "本次会话：上屏%d次，取消%d次",
            state.total_commits,
            state.total_cancels
        )
        yield(Candidate("stats", seg.start, seg._end, stats_text, "统计信息"))
    end
end

-- ========== 配置修改接口 ==========

function M.set_config(key, value)
    if config[key] ~= nil then
        config[key] = value
        log.info("配置已更新：" .. key .. " = " .. tostring(value))
    end
end

function M.get_stats()
    return {
        session_duration = os.time() - state.session_start_time,
        total_commits = state.total_commits,
        total_cancels = state.total_cancels,
        longest_input = state.longest_input
    }
end

-- ========== 使用示例 ==========

--[[
完整的配置示例：

1. 在 rime.lua 中：

local smart_recorder = require("smart_input_recorder")

-- 可选：修改配置
smart_recorder.set_config("min_record_length", 2)
smart_recorder.set_config("enable_external_command", true)

local function init(env)
    smart_recorder.init(env)
end

local function fini(env)
    smart_recorder.fini(env)
end

-- 可选：如果想要统计信息翻译功能
local function translator(input, seg, env)
    return smart_recorder.translator(input, seg, env)
end

return {
    init = init,
    fini = fini,
    translator = translator  -- 可选
}

2. 生成的文件：
- ~/.rime_input_history.txt - 所有输入历史
- ~/.rime_drafts/ - 未完成的输入草稿
- ~/.rime_input_stats.txt - 统计信息

3. 特殊功能：
- 输入 "/stats" 可以查看当前会话统计
--]]

return M
