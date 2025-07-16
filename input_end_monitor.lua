--[[
Rime输入结束事件监听器
监听各种输入结束情况：内容上屏、输入框消失、切换应用等

支持的事件类型：
1. commit_notifier - 内容上屏时触发
2. update_notifier - 输入状态变化时触发（可以检测输入框消失）
3. delete_notifier - 输入被删除时触发
4. unhandled_key_notifier - 未处理的按键事件（可以检测切换应用）

使用方法：
在你的 rime.lua 中：
local input_end_monitor = require("input_end_monitor")

function init(env)
    input_end_monitor.init(env)
end

function fini(env)
    input_end_monitor.fini(env)
end
--]]

local log = require("log")

local M = {}

-- 保存上一次的状态，用于检测变化
local last_state = {
    is_composing = false,
    input_length = 0,
    has_composition = false
}

-- ========== 主要的输入结束检测逻辑 ==========

-- 处理输入结束的回调函数
function M.on_input_ended(ctx, reason)
    local current_input = ctx.input or ""
    local current_composition = ctx.composition
    
    log.info("输入结束检测到：" .. reason)
    log.info("最后的输入内容：'" .. current_input .. "'")
    
    if not current_composition:empty() then
        local last_segment = current_composition:back()
        if last_segment then
            log.info("最后的segment: start=" .. tostring(last_segment.start) .. 
                     ", end=" .. tostring(last_segment._end))
        end
    end
    
    -- 在这里执行你想要的操作
    M.execute_custom_action(ctx, reason, current_input)
end

-- 自定义操作函数 - 在这里添加你想要执行的具体操作
function M.execute_custom_action(ctx, reason, input_text)
    --[[
    在这里添加你想要在输入结束时执行的操作
    
    参数说明：
    ctx - Context对象
    reason - 结束原因：
        "commit" - 内容上屏
        "clear" - 输入被清空
        "app_switch" - 应用切换（推测）
        "composition_empty" - 组合状态变为空
    input_text - 最后的输入内容
    --]]
    
    -- 示例1：记录到日志
    log.info("执行自定义操作：原因=" .. reason .. ", 输入='" .. input_text .. "'")
    
    -- 示例2：根据不同原因执行不同操作
    if reason == "commit" then
        -- 内容上屏时的操作
        M.handle_commit_action(input_text)
    elseif reason == "clear" then
        -- 输入被清空时的操作
        M.handle_clear_action(input_text)
    elseif reason == "app_switch" then
        -- 应用切换时的操作
        M.handle_app_switch_action(input_text)
    end
    
    -- 示例3：将信息写入文件
    -- M.write_to_file(reason, input_text)
    
    -- 示例4：更新用户词典或统计信息
    -- M.update_user_stats(input_text)
end

-- 具体的处理函数
function M.handle_commit_action(input_text)
    log.info("处理上屏事件：" .. input_text)
    -- 在这里添加上屏时要执行的操作
end

function M.handle_clear_action(input_text)
    log.info("处理清空事件：" .. input_text)
    -- 在这里添加清空时要执行的操作
end

function M.handle_app_switch_action(input_text)
    log.info("处理应用切换事件：" .. input_text)
    -- 在这里添加切换应用时要执行的操作
end

-- ========== 事件监听器设置 ==========

-- 初始化函数
function M.init(env)
    log.info("初始化输入结束监听器")
    
    local context = env.engine.context
    
    -- 1. 监听上屏事件（最直接的输入结束）
    env.commit_notifier = context.commit_notifier:connect(function(ctx)
        local commit_text = ctx:get_commit_text()
        log.info("检测到上屏事件：'" .. commit_text .. "'")
        M.on_input_ended(ctx, "commit")
    end)
    
    -- 2. 监听上下文更新事件（检测输入状态变化）
    env.update_notifier = context.update_notifier:connect(function(ctx)
        M.check_input_state_change(ctx)
    end)
    
    -- 3. 监听删除事件
    env.delete_notifier = context.delete_notifier:connect(function(ctx)
        log.info("检测到删除事件")
        -- 如果输入被完全删除，也算是输入结束
        if not ctx:is_composing() and (last_state.is_composing or last_state.input_length > 0) then
            M.on_input_ended(ctx, "clear")
        end
    end)
    
    -- 4. 监听未处理的按键事件（可能是切换应用等）
    env.unhandled_key_notifier = context.unhandled_key_notifier:connect(function(ctx, key)
        local key_repr = key:repr()
        log.info("未处理的按键：" .. key_repr)
        
        -- 检测可能的应用切换按键（如 Alt+Tab, Cmd+Tab 等）
        if key_repr:find("alt") or key_repr:find("cmd") or key_repr:find("super") then
            if ctx:is_composing() then
                M.on_input_ended(ctx, "app_switch")
            end
        end
    end)
    
    -- 初始化状态
    M.update_last_state(context)
end

-- 检测输入状态变化
function M.check_input_state_change(ctx)
    local current_is_composing = ctx:is_composing()
    local current_input_length = string.len(ctx.input or "")
    local current_has_composition = not ctx.composition:empty()
    
    -- 检测从有输入变为无输入的情况（可能是输入框消失）
    if (last_state.is_composing or last_state.has_composition or last_state.input_length > 0) and
       (not current_is_composing and not current_has_composition and current_input_length == 0) then
        
        log.info("检测到输入状态清空（可能是输入框消失）")
        M.on_input_ended(ctx, "composition_empty")
    end
    
    -- 更新状态
    M.update_last_state(ctx)
end

-- 更新上次状态
function M.update_last_state(ctx)
    last_state.is_composing = ctx:is_composing()
    last_state.input_length = string.len(ctx.input or "")
    last_state.has_composition = not ctx.composition:empty()
end

-- 清理函数
function M.fini(env)
    log.info("清理输入结束监听器")
    
    if env.commit_notifier then
        env.commit_notifier:disconnect()
    end
    
    if env.update_notifier then
        env.update_notifier:disconnect()
    end
    
    if env.delete_notifier then
        env.delete_notifier:disconnect()
    end
    
    if env.unhandled_key_notifier then
        env.unhandled_key_notifier:disconnect()
    end
end

-- ========== 高级功能：写入文件 ==========

-- 将输入结束事件写入文件
function M.write_to_file(reason, input_text)
    local timestamp = os.date("%Y-%m-%d %H:%M:%S")
    local log_entry = string.format("[%s] %s: '%s'\n", timestamp, reason, input_text)
    
    local file = io.open(os.getenv("HOME") .. "/.rime_input_log.txt", "a")
    if file then
        file:write(log_entry)
        file:close()
    end
end

-- ========== 高级功能：统计信息 ==========

-- 更新用户统计信息
function M.update_user_stats(input_text)
    -- 这里可以添加统计逻辑，比如：
    -- 1. 统计输入频率
    -- 2. 记录常用词汇
    -- 3. 分析输入模式等
    
    if string.len(input_text) > 0 then
        log.info("更新统计信息：长度=" .. string.len(input_text))
    end
end

-- ========== 调试功能 ==========

-- 调试模式：打印详细状态
function M.debug_print_state(ctx, label)
    local composition = ctx.composition
    log.info("=== " .. label .. " ===")
    log.info("is_composing: " .. tostring(ctx:is_composing()))
    log.info("input: '" .. (ctx.input or "") .. "'")
    log.info("composition.empty: " .. tostring(composition:empty()))
    log.info("has_menu: " .. tostring(ctx:has_menu()))
    
    if not composition:empty() then
        local last_seg = composition:back()
        if last_seg then
            log.info("last_segment.start: " .. tostring(last_seg.start))
            log.info("last_segment.end: " .. tostring(last_seg._end))
            log.info("last_segment.prompt: '" .. (last_seg.prompt or "") .. "'")
        end
    end
    log.info("==================")
end

-- ========== 使用示例 ==========

--[[
完整的使用示例：

-- 在你的 rime.lua 中
local input_monitor = require("input_end_monitor")

-- 自定义处理函数
local function my_custom_handler()
    input_monitor.execute_custom_action = function(ctx, reason, input_text)
        if reason == "commit" then
            -- 内容上屏时，执行某些操作
            print("用户上屏了：" .. input_text)
            -- 例如：记录到数据库、触发其他程序等
        elseif reason == "clear" then
            -- 输入被清空时
            print("输入被清空了，之前的内容是：" .. input_text)
        end
    end
end

local function init(env)
    my_custom_handler() -- 设置自定义处理
    input_monitor.init(env)
end

local function fini(env)
    input_monitor.fini(env)
end

return {
    init = init,
    fini = fini
}
--]]

return M
