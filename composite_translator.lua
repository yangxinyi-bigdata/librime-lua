--[[
复合分段翻译器 - 实现多段输入处理
支持 "nihao`hello`keyi" 翻译成 "你好`hello`可以" 这样的混合翻译

使用方法：
1. 在 schema.yaml 中配置：
   engine:
     segmentors:
       - ascii_segmentor
       - matcher
       - lua_segmentor@composite_segmentor
       - abc_segmentor
       - punct_segmentor
       - fallback_segmentor
     translators:
       - echo_translator
       - punct_translator
       - lua_translator@composite_translator
       - script_translator
       - table_translator

2. 在 rime.lua 中注册：
   composite_segmentor = require("composite_translator").segmentor
   composite_translator = require("composite_translator").translator
--]]

local M = {}

-- 分段器：将输入拆分成多个segment
function M.segmentor(segmentation, env)
    local input = segmentation.input
    local len = string.len(input)
    local start_pos = segmentation:get_current_start_position()
    
    if start_pos >= len then
        return false
    end
    
    -- 检查是否包含反引号分隔的复合输入
    local backtick_pos = string.find(input, "`", start_pos + 1)
    if not backtick_pos then
        return false -- 没有反引号，让其他segmentor处理
    end
    
    -- 分析整个输入，创建复合segment
    local segments = parse_composite_input(input, start_pos)
    
    if #segments > 1 then
        -- 创建一个覆盖整个输入的复合segment
        local composite_seg = Segment(start_pos, len)
        composite_seg.tags = composite_seg.tags + Set{"composite"}
        segmentation:add_segment(composite_seg)
        return true
    end
    
    return false
end

-- 解析复合输入，返回各个部分的信息
function parse_composite_input(input, start_pos)
    local parts = {}
    local current_pos = start_pos + 1
    local input_len = string.len(input)
    
    while current_pos <= input_len do
        local backtick_start = string.find(input, "`", current_pos)
        
        if not backtick_start then
            -- 没有更多反引号，添加剩余部分
            if current_pos <= input_len then
                table.insert(parts, {
                    type = "normal",
                    text = string.sub(input, current_pos),
                    start = current_pos - 1,
                    length = input_len - current_pos + 1
                })
            end
            break
        end
        
        -- 添加反引号前的普通部分
        if backtick_start > current_pos then
            table.insert(parts, {
                type = "normal",
                text = string.sub(input, current_pos, backtick_start - 1),
                start = current_pos - 1,
                length = backtick_start - current_pos
            })
        end
        
        -- 查找配对的反引号
        local backtick_end = string.find(input, "`", backtick_start + 1)
        if backtick_end then
            -- 添加反引号段
            table.insert(parts, {
                type = "backtick",
                text = string.sub(input, backtick_start + 1, backtick_end - 1),
                start = backtick_start - 1,
                length = backtick_end - backtick_start + 1,
                original = string.sub(input, backtick_start, backtick_end) -- 包含反引号的原文
            })
            current_pos = backtick_end + 1
        else
            -- 没有配对的反引号，当作普通文本
            table.insert(parts, {
                type = "normal",
                text = string.sub(input, backtick_start),
                start = backtick_start - 1,
                length = input_len - backtick_start + 1
            })
            break
        end
    end
    
    return parts
end

-- 翻译器：处理复合segment
function M.translator(input, seg, env)
    -- 只处理带有composite标签的segment
    if not seg:has_tag("composite") then
        return
    end
    
    local parts = parse_composite_input(input, seg.start)
    
    if #parts == 0 then
        return
    end
    
    -- 为每个部分生成候选词
    local part_candidates = {}
    
    for i, part in ipairs(parts) do
        if part.type == "normal" then
            -- 翻译普通文本部分
            part_candidates[i] = translate_normal_part(part.text, env)
        elseif part.type == "backtick" then
            -- 反引号内容保持原样，但可以选择是否保留反引号
            part_candidates[i] = {
                { text = part.text, comment = "原文保留" },
                { text = part.original, comment = "保留反引号" }
            }
        end
    end
    
    -- 生成组合候选词
    generate_composite_candidates(parts, part_candidates, seg, env)
end

-- 翻译普通文本部分
function translate_normal_part(text, env)
    local candidates = {}
    
    -- 尝试使用内置翻译器
    local internal_candidates = query_internal_translator(text, env)
    if internal_candidates and #internal_candidates > 0 then
        for _, cand in ipairs(internal_candidates) do
            table.insert(candidates, { text = cand.text, comment = cand.comment })
        end
    end
    
    -- 使用简单字典作为后备
    local simple_dict = get_simple_dictionary()
    if simple_dict[text] then
        table.insert(candidates, { text = simple_dict[text], comment = "字典翻译" })
    end
    
    -- 如果没有翻译，保持原文
    if #candidates == 0 then
        table.insert(candidates, { text = text, comment = "保持原文" })
    end
    
    return candidates
end

-- 查询内置翻译器
function query_internal_translator(text, env)
    local candidates = {}
    
    -- 尝试创建临时segment来查询其他翻译器
    local temp_seg = Segment(0, string.len(text))
    temp_seg.tags = temp_seg.tags + Set{"abc"}
    
    -- 这里可以调用其他翻译器组件
    -- 示例：使用Component.Translator来调用script_translator
    if env.script_translator then
        local translation = env.script_translator:query(text, temp_seg)
        if translation then
            local count = 0
            for cand in translation:iter() do
                table.insert(candidates, cand)
                count = count + 1
                if count >= 3 then break end -- 限制候选词数量
            end
        end
    end
    
    return candidates
end

-- 获取简单字典
function get_simple_dictionary()
    return {
        ni = "你",
        nihao = "你好", 
        hao = "好",
        keyi = "可以",
        wo = "我",
        de = "的",
        shi = "是",
        zai = "在",
        you = "有",
        bu = "不",
        le = "了",
        ren = "人",
        ta = "他",
        women = "我们",
        lai = "来",
        dao = "到",
        shuo = "说",
        qu = "去",
        jiu = "就",
        hen = "很",
        zhe = "这",
        ge = "个"
    }
end

-- 生成组合候选词
function generate_composite_candidates(parts, part_candidates, seg, env)
    -- 生成第一个组合（每个部分的第一个候选词）
    local primary_text = ""
    local primary_comment = "复合翻译"
    
    for i, part in ipairs(parts) do
        if part_candidates[i] and #part_candidates[i] > 0 then
            primary_text = primary_text .. part_candidates[i][1].text
        else
            primary_text = primary_text .. part.text
        end
    end
    
    yield(Candidate("composite", seg.start, seg._end, primary_text, primary_comment))
    
    -- 生成其他组合（可选）
    -- 为每个部分提供替代选择
    for i, part in ipairs(parts) do
        if part_candidates[i] and #part_candidates[i] > 1 then
            for j = 2, math.min(#part_candidates[i], 3) do -- 最多3个替代选择
                local alt_text = ""
                for k, p in ipairs(parts) do
                    if k == i then
                        alt_text = alt_text .. part_candidates[i][j].text
                    else
                        if part_candidates[k] and #part_candidates[k] > 0 then
                            alt_text = alt_text .. part_candidates[k][1].text
                        else
                            alt_text = alt_text .. p.text
                        end
                    end
                end
                
                local comment = "变体" .. j .. ": " .. (part_candidates[i][j].comment or "")
                yield(Candidate("composite_alt", seg.start, seg._end, alt_text, comment))
            end
        end
    end
    
    -- 生成分段显示版本（用于调试）
    if env.debug_mode then
        local debug_text = ""
        for i, part in ipairs(parts) do
            if part_candidates[i] and #part_candidates[i] > 0 then
                debug_text = debug_text .. "[" .. part_candidates[i][1].text .. "]"
            else
                debug_text = debug_text .. "[" .. part.text .. "]"
            end
        end
        yield(Candidate("composite_debug", seg.start, seg._end, debug_text, "分段显示"))
    end
end

-- 初始化函数
function M.init(env)
    log.info("Composite translator initialized for: " .. (env.name_space or "unknown"))
    
    -- 尝试创建script_translator实例用于查询
    if Component and Component.Translator then
        env.script_translator = Component.Translator(env.engine, "", "script_translator")
        if env.script_translator then
            log.info("Internal script_translator created successfully")
        else
            log.warning("Failed to create internal script_translator")
        end
    end
    
    -- 设置调试模式
    env.debug_mode = env.engine.schema.config:get_bool("translator/debug_mode") or false
end

-- 清理函数
function M.fini(env)
    log.info("Composite translator finalized")
end

-- 示例filter：后处理候选词格式
function M.filter(input, env)
    for cand in input:iter() do
        if cand.type == "composite" then
            -- 可以在这里对复合候选词进行进一步处理
            yield(cand)
        else
            yield(cand)
        end
    end
end

return M
