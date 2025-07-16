--[[
完整的解决方案演示：正确处理segment prompt显示
解决输入 "nihaobeijing" 光标左移时字母跑到prompt后面的问题

问题原因：
Rime在 composition.cc 的 GetPreedit 方法中会在光标位置插入 prompt，
导致："nihaobeijin^     > 搜索模式g"

解决方法：
动态监听context变化，只在光标位于末尾时显示prompt
--]]

local log = require("log")

local M = {}

-- ========== 主要解决方案 ==========

-- 初始化函数 - 设置context监听器
function M.init(env)
    log.info("初始化 segment_prompt_fix")
    
    -- 监听context更新事件
    env.notifier = env.engine.context.update_notifier:connect(function(ctx)
        M.handle_context_update(ctx)
    end)
end

-- 清理函数
function M.fini(env)
    if env.notifier then
        env.notifier:disconnect()
    end
end

-- 处理context更新事件
function M.handle_context_update(ctx)
    local composition = ctx.composition
    if composition:empty() then
        return
    end
    
    local last_seg = composition:back()
    local caret_pos = ctx.caret_pos
    local input_len = string.len(ctx.input)
    
    -- 关键逻辑：只在光标位于输入末尾时显示prompt
    if caret_pos >= input_len then
        -- 光标在末尾，显示prompt
        if last_seg.prompt ~= "> 搜索模式" then
            last_seg.prompt = "> 搜索模式"
            log.info("显示prompt：光标在末尾")
        end
    else
        -- 光标不在末尾，隐藏prompt避免位置错乱
        if last_seg.prompt ~= "" then
            last_seg.prompt = ""
            log.info("隐藏prompt：光标不在末尾，位置=" .. tostring(caret_pos))
        end
    end
end

-- ========== 替代方案：使用translator处理 ==========

-- 方案A：translator中处理（如果你在translator中设置prompt）
function M.translator(input, seg, env)
    -- 不在这里设置 seg.prompt
    -- 因为在translator中设置的prompt会有光标位置问题
    
    -- 你的正常翻译逻辑
    local candidates = {}
    
    -- 示例：创建一些候选词
    local candidate = Candidate("word", seg.start, seg._end, "示例候选词", "提示")
    
    -- 方法1：使用preedit属性（推荐）
    -- candidate.preedit = input .. "\t> 搜索模式"  -- tab后的内容只在光标末尾显示
    
    yield(candidate)
end

-- ========== 高级解决方案：processor处理 ==========

-- 方案B：在processor中动态处理
function M.processor(key, env)
    local context = env.engine.context
    local key_name = key:repr()
    
    -- 监听方向键
    if key_name == "Left" or key_name == "Right" or 
       key_name == "Home" or key_name == "End" then
        
        -- 延迟处理，确保光标位置已更新
        -- 注意：这里使用简单的标记，实际中可能需要更复杂的处理
        env.need_update_prompt = true
    end
    
    -- 如果需要更新prompt
    if env.need_update_prompt then
        M.handle_context_update(context)
        env.need_update_prompt = false
    end
    
    return 2 -- kNoop，继续处理
end

-- ========== 完整的使用示例 ==========

-- 示例：在你的实际代码中如何使用
function M.example_usage()
    --[[
    在你的 rime.lua 中：
    
    local segment_fix = require("segment_prompt_fix")
    
    -- 方案1：使用初始化监听器（推荐）
    local function init(env)
        segment_fix.init(env)
        -- 你的其他初始化代码
    end
    
    local function fini(env)
        segment_fix.fini(env)
        -- 你的其他清理代码
    end
    
    local function your_translator(input, seg, env)
        -- 不要设置 seg.prompt = "> 搜索模式"
        -- 让init中的监听器来处理
        
        -- 你的翻译逻辑
        local candidate = Candidate("type", seg.start, seg._end, "结果", "comment")
        yield(candidate)
    end
    
    return {
        init = init,
        fini = fini,
        translator = your_translator
    }
    --]]
end

-- ========== 调试和测试功能 ==========

-- 调试函数：打印当前状态
function M.debug_status(ctx)
    local composition = ctx.composition
    if composition:empty() then
        log.info("DEBUG: composition为空")
        return
    end
    
    local last_seg = composition:back()
    local caret_pos = ctx.caret_pos
    local input_len = string.len(ctx.input)
    
    log.info("DEBUG: input='" .. ctx.input .. "', caret_pos=" .. 
             tostring(caret_pos) .. ", input_len=" .. tostring(input_len))
    log.info("DEBUG: prompt='" .. (last_seg.prompt or "") .. "'")
    log.info("DEBUG: seg.start=" .. tostring(last_seg.start) .. 
             ", seg.end=" .. tostring(last_seg._end))
end

-- 测试函数
function M.test_scenario()
    --[[
    测试场景：
    1. 输入 "nihaobeijing"
    2. 光标应该在末尾，prompt显示 "> 搜索模式"
    3. 按左箭头，光标移动到 "g" 前面
    4. prompt应该消失，避免 "nihaobeijin^     > 搜索模式g"
    5. 按右箭头回到末尾，prompt重新显示
    --]]
end

return M
