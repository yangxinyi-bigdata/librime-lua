--[[
Segment Prompt 显示修正方案
解决光标移动时字母跑到prompt后面的问题

问题根源：
Rime在composition.cc的GetPreedit方法中，会在光标位置插入prompt，
导致光标右侧的字符被推到prompt后面。

解决方案有以下几种：
--]]

local M = {}

-- 方案1：使用候选词的preedit属性来控制显示
-- 这是最推荐的方案，因为它不会影响光标位置
function M.solution1_use_candidate_preedit(env)
    local function translator(input, seg, env)
        -- 不设置 seg.prompt
        -- 而是在候选词的preedit中加入提示信息
        
        local candidates = {}
        
        -- 假设你的正常翻译逻辑
        local normal_candidates = your_normal_translation_logic(input, seg, env)
        
        for candidate in normal_candidates do
            -- 修改候选词的preedit，在末尾添加prompt信息
            local modified_preedit = candidate.preedit .. "\t> 搜索模式"
            candidate.preedit = modified_preedit
            yield(candidate)
        end
    end
    
    return translator
end

-- 方案2：自定义Filter来后处理显示
function M.solution2_custom_filter(env)
    local function filter(input, env)
        for cand in input:iter() do
            -- 在filter中处理显示逻辑
            -- 这里可以修改候选词的显示格式
            yield(cand)
        end
    end
    
    return filter
end

-- 方案3：使用Context事件监听器动态调整
function M.solution3_context_monitor(env)
    local function processor(key, env)
        local context = env.engine.context
        local composition = context.composition
        
        if not composition:empty() then
            local last_seg = composition:back()
            
            -- 检测光标位置变化
            local caret_pos = context.caret_pos
            local input_len = string.len(context.input)
            
            if caret_pos < input_len then
                -- 光标不在末尾时，清除prompt避免位置错乱
                last_seg.prompt = ""
            else
                -- 光标在末尾时，显示prompt
                last_seg.prompt = "> 搜索模式"
            end
        end
        
        return 2 -- kNoop，让其他processor处理
    end
    
    return processor
end

-- 方案4：使用Composition的spans机制（最复杂但最精确）
function M.solution4_spans_based(env)
    local function segmentor(segmentation, env)
        local input = segmentation.input
        local start_pos = segmentation:get_current_start_position()
        
        -- 创建segment但不设置prompt
        local segment = Segment(start_pos, string.len(input))
        segment.tags = segment.tags + Set{"custom_prompt"}
        
        segmentation:add_segment(segment)
        return true
    end
    
    local function translator(input, seg, env)
        if seg:has_tag("custom_prompt") then
            -- 创建特殊的候选词，使用preedit控制显示
            local cand = Candidate("custom", seg.start, seg._end, input, "")
            
            -- 关键：使用tab分隔符控制光标和prompt的位置
            -- tab前是正常输入，tab后是prompt（只在光标在末尾时显示）
            cand.preedit = input .. "\t> 搜索模式"
            
            yield(cand)
        end
    end
    
    return {
        segmentor = segmentor,
        translator = translator
    }
end

-- 方案5：最简单的workaround - 在processor中动态控制
function M.solution5_simple_workaround(env)
    -- 在init中设置
    env.engine.context.update_notifier:connect(function(ctx)
        local composition = ctx.composition
        if not composition:empty() then
            local last_seg = composition:back()
            local caret_pos = ctx.caret_pos
            local input_len = string.len(ctx.input)
            
            -- 只在光标位于输入末尾时显示prompt
            if caret_pos >= input_len then
                last_seg.prompt = "> 搜索模式"
            else
                last_seg.prompt = ""
            end
        end
    end)
end

-- 推荐的解决方案实现
function M.recommended_solution(env)
    --[[
    推荐使用方案1或方案5的组合：
    
    1. 避免直接设置segment.prompt，因为它会在光标位置插入
    2. 使用候选词的preedit属性或动态监听context变化
    3. 只在光标位于输入末尾时显示提示信息
    --]]
    
    -- 初始化时设置监听器
    env.engine.context.update_notifier:connect(function(ctx)
        local composition = ctx.composition
        if not composition:empty() then
            local last_seg = composition:back()
            local caret_pos = ctx.caret_pos
            local input_len = string.len(ctx.input)
            
            -- 动态控制prompt显示
            if caret_pos >= input_len then
                last_seg.prompt = "> 搜索模式"
            else
                last_seg.prompt = ""
            end
        end
    end)
end

return M
