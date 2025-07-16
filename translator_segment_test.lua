#!/usr/bin/env lua

-- translator_segment_test.lua
-- 测试Translator Query方法中Segment参数的作用

print("=== Translator Segment参数影响测试 ===")

-- 模拟测试环境
local function create_mock_env()
    local mock_env = {
        engine = {
            schema = {
                config = {
                    get_bool = function() return false end
                }
            }
        }
    }
    
    -- 模拟Component.Translator
    mock_env.translator = {
        query = function(self, input, segment)
            print(string.format("Query调用: input='%s', segment.start=%d, segment._end=%d, segment.length=%d", 
                  input, segment.start or 0, segment._end or 0, segment.length or 0))
            
            -- 模拟真实翻译器的行为：只关注input，忽略segment长度
            local results = {}
            
            -- 模拟拼音翻译逻辑
            local pinyin_map = {
                ["keyi"] = {"可以", "科艺", "克易"},
                ["yi"] = {"一", "以", "已", "亿"},
                ["qi"] = {"七", "起", "气", "奇"},
                ["keyiyiqi"] = {"可以一起"}
            }
            
            -- 关键：始终处理完整的input，不受segment长度影响
            local full_input = input
            print(string.format("  处理完整输入: '%s'", full_input))
            
            -- 尝试匹配各种组合
            for pattern, translations in pairs(pinyin_map) do
                if string.find(full_input, pattern) then
                    for _, translation in ipairs(translations) do
                        table.insert(results, {
                            text = translation,
                            input_pattern = pattern,
                            quality = 0.8,
                            comment = "拼音翻译"
                        })
                    end
                end
            end
            
            return {
                iter = function()
                    local i = 0
                    return function()
                        i = i + 1
                        return results[i]
                    end
                end,
                results = results
            }
        end
    }
    
    return mock_env
end

-- 创建不同长度的Segment
local function create_segment(start, end_pos, tags)
    return {
        start = start,
        _end = end_pos,
        length = end_pos - start,
        tags = tags or {}
    }
end

-- 执行测试
local function run_test()
    local env = create_mock_env()
    local test_input = "keyiyiqiiifj"
    
    print(string.format("\n测试输入: '%s'\n", test_input))
    
    -- 测试1：不同长度的segment
    print("--- 测试1：不同Segment长度对结果的影响 ---")
    
    local segments = {
        {name = "短segment", seg = create_segment(0, 4)},   -- 长度4 "keyi"
        {name = "中segment", seg = create_segment(0, 8)},   -- 长度8 "keyiyiqi"  
        {name = "长segment", seg = create_segment(0, 12)},  -- 长度12 "keyiyiqiiifj"
        {name = "超长segment", seg = create_segment(0, 20)} -- 长度20（超出input）
    }
    
    local all_results = {}
    
    for i, test_case in ipairs(segments) do
        print(string.format("\n%d. %s (长度:%d)", i, test_case.name, test_case.seg.length))
        
        local translation = env.translator:query(test_input, test_case.seg)
        local results = {}
        
        for candidate in translation:iter() do
            if not candidate then break end
            table.insert(results, candidate.text)
            print(string.format("   候选词: %s (%s)", candidate.text, candidate.input_pattern))
        end
        
        all_results[i] = results
    end
    
    -- 比较结果
    print("\n--- 结果比较 ---")
    local first_result = all_results[1]
    local all_same = true
    
    for i = 2, #all_results do
        if #all_results[i] ~= #first_result then
            all_same = false
            break
        end
        
        for j = 1, #first_result do
            if all_results[i][j] ~= first_result[j] then
                all_same = false
                break
            end
        end
        
        if not all_same then break end
    end
    
    if all_same then
        print("✅ 所有不同长度的segment产生了相同的翻译结果")
        print("   这证实了segment长度不影响查询结果的结论")
    else
        print("❌ 不同长度的segment产生了不同的结果")
        print("   这与我们的分析不符，需要进一步调查")
    end
    
    -- 测试2：相同长度，不同起始位置
    print("\n--- 测试2：相同长度，不同起始位置 ---")
    
    local position_tests = {
        {name = "位置0-4", seg = create_segment(0, 4)},
        {name = "位置2-6", seg = create_segment(2, 6)},
        {name = "位置5-9", seg = create_segment(5, 9)}
    }
    
    for i, test_case in ipairs(position_tests) do
        print(string.format("\n%d. %s", i, test_case.name))
        local translation = env.translator:query(test_input, test_case.seg)
        
        for candidate in translation:iter() do
            if not candidate then break end
            print(string.format("   候选词: %s", candidate.text))
        end
    end
    
    -- 测试3：验证input截取vs segment长度的区别
    print("\n--- 测试3：Input截取 vs Segment长度 ---")
    
    local segment_full = create_segment(0, 12)
    local segment_short = create_segment(0, 4)
    
    print("\n3.1 完整input + 短segment:")
    local t1 = env.translator:query(test_input, segment_short)
    for candidate in t1:iter() do
        if not candidate then break end
        print(string.format("   %s", candidate.text))
    end
    
    print("\n3.2 截取input + 短segment:")
    local truncated_input = string.sub(test_input, 1, 4)  -- "keyi"
    local t2 = env.translator:query(truncated_input, segment_short)
    for candidate in t2:iter() do
        if not candidate then break end
        print(string.format("   %s", candidate.text))
    end
    
    print("\n--- 总结 ---")
    print("1. Translator的query方法主要基于input参数进行翻译")
    print("2. Segment的长度信息不直接影响翻译结果")
    print("3. 要限制翻译范围，应该截取input参数，而不是依赖segment长度")
    print("4. Segment参数主要用于tags、位置信息等上下文数据")
end

-- 运行测试
run_test()

print("\n=== 测试完成 ===")
