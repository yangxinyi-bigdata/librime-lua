# Rime多段翻译器配置与使用指南

## 配置文件示例

### 1. 方案配置 (multi_segment.schema.yaml)
```yaml
schema:
  schema_id: multi_segment_demo
  name: "多段翻译演示"
  version: "1.0"
  description: |
    支持多段输入处理的Rime方案
    输入格式：nihao`hello`keyi
    输出结果：你好hello可以

switches:
  - name: ascii_mode
    reset: 0
    states: [ 中文, 西文 ]
  - name: full_shape
    states: [ 半角, 全角 ]
  - name: debug_mode
    reset: 0
    states: [ 正常, 调试 ]

engine:
  processors:
    - ascii_composer
    - recognizer
    - key_binder
    - speller
    - punctuator
    - selector
    - navigator
    - express_editor
  segmentors:
    - ascii_segmentor
    - matcher
    - affix_segmentor@backtick_segment  # 处理反引号段落
    - abc_segmentor
    - punct_segmentor
    - fallback_segmentor
  translators:
    - punct_translator
    - script_translator
    - table_translator@custom_phrase
    - lua_translator@advanced_composite_translator  # 核心多段翻译器
  filters:
    - simplifier
    - uniquifier

# 拼写配置
speller:
  alphabet: zyxwvutsrqponmlkjihgfedcba`  # 包含反引号
  delimiter: " '"
  algebra:
    # 基础拼音规则
    - erase/^xx$/
    - derive/^([jqxy])u$/$1v/
    - derive/^([aoe])([ioun])$/$1$1$2/
    # ... 其他拼音规则

# 主翻译器配置
translator:
  dictionary: luna_pinyin
  prism: multi_segment_demo
  enable_completion: true
  enable_sentence: true
  enable_user_dict: true

# 自定义短语
custom_phrase:
  dictionary: ""
  user_dict: custom_phrase
  db_class: stabledb
  enable_completion: false
  enable_sentence: false

# 反引号段落处理
backtick_segment:
  tag: backtick_literal
  prefix: "`"
  suffix: "`"
  tips: "字面量"
  closing_tips: "字面量结束"

# 识别器配置
recognizer:
  import_preset: default
  patterns:
    # 识别多段输入模式
    multi_segment: "^[a-z]*`[^`]*`.*$"
    backtick_literal: "^`[^`]*`?$"
    punct: "^/([0-9]0?|[A-Za-z]+)$"

# Lua配置
lua_libs:
  - advanced_composite_translator
```

### 2. Lua脚本部署 (rime.lua)
```lua
-- rime.lua - 主要的Lua配置文件

-- 引入多段翻译器
advanced_composite_translator = require('advanced_composite_translator')

-- 调试开关配置
function debug_switch_processor(key, env)
    local config = env.engine.schema.config
    local context = env.engine.context
    
    if key:repr() == "Control+d" then
        local debug_mode = config:get_bool("switches/debug_mode/reset") or false
        config:set_bool("switches/debug_mode/reset", not debug_mode)
        context:refresh_non_confirmed_composition()
        return 1  -- kAccepted
    end
    
    return 2  -- kNoop
end

-- 其他可能的Lua组件
-- require('date')
-- require('number')
-- require('time')
```

## 使用方法

### 1. 基本多段输入
```
输入: nihao`hello`keyi
输出候选词:
1. 你好hello可以
2. 尼好hello可以  
3. 你好`hello`可以 (保留原格式)
4. nihao hello keyi (保留原文)
```

### 2. 复杂多段输入
```
输入: women`are`xuesheng
输出候选词:
1. 我们are学生
2. 我们are学声
3. 我们`are`学生 (保留格式)
```

### 3. 调试模式
```
输入: nihao`hello`keyi (开启调试模式)
输出候选词:
1. 你好hello可以 [调试:seg1(table)+seg2(literal)+seg3(table)]
2. 分段信息: [0-5:nihao] [6-11:`hello`] [12-16:keyi]
3. 翻译详情: seg1{你好:0.95,尼好:0.8} seg2{hello:1.0} seg3{可以:0.9}
```

## 高级配置选项

### 1. 环境变量配置
```lua
-- 在schema的lua配置中
function advanced_composite_translator.init(env)
    -- 读取配置参数
    local config = env.engine.schema.config
    env.max_candidates_per_segment = config:get_int("translator/max_candidates") or 5
    env.enable_smart_spacing = config:get_bool("translator/smart_spacing") or false
    env.cache_enabled = config:get_bool("translator/enable_cache") or true
    env.debug_mode = config:get_bool("switches/debug_mode/reset") or false
    
    -- 初始化翻译器
    env.internal_translator = Component.Translator(env.engine, "", "script_translator")
    env.table_translator = Component.Translator(env.engine, "", "table_translator")
end
```

### 2. 方案内配置参数
```yaml
# 在schema文件中添加自定义配置
translator:
  dictionary: luna_pinyin
  prism: multi_segment_demo
  # 自定义参数
  max_candidates: 3          # 每段最大候选词数
  smart_spacing: true        # 智能空格
  enable_cache: true         # 启用缓存
  merge_strategies:          # 合并策略
    - best_combination
    - alternative_combination
    - preserve_format
```

### 3. 用户自定义词典
```yaml
# custom_phrase.txt
你好世界	nihao world	1
开源软件	kaiyuan software	1
人工智能	rengong intelligence	1
```

## 性能优化配置

### 1. 缓存设置
```lua
-- 缓存配置
local cache_config = {
    max_size = 1000,           -- 最大缓存条目数
    ttl = 3600,               -- 缓存生存时间(秒)
    enable_persistent = true   -- 启用持久化缓存
}
```

### 2. 并发控制
```lua
-- 翻译器并发配置
local translation_config = {
    max_concurrent_segments = 5,    -- 最大并发段数
    timeout_ms = 1000,             -- 翻译超时时间
    fallback_enabled = true        -- 启用降级机制
}
```

## 故障排除

### 1. 常见问题
```lua
-- 检查翻译器是否正确初始化
function check_translator_health(env)
    local issues = {}
    
    if not env.internal_translator then
        table.insert(issues, "script_translator未初始化")
    end
    
    if not env.table_translator then
        table.insert(issues, "table_translator未初始化")
    end
    
    return issues
end
```

### 2. 调试工具
```lua
-- 调试信息输出
function debug_translation_info(segments, results)
    log.info("=== 翻译调试信息 ===")
    for i, segment in ipairs(segments) do
        log.info(string.format("段%d: %s -> %d个候选词", 
                 i, segment.text, #results[i]))
        for j, cand in ipairs(results[i]) do
            log.info(string.format("  %d. %s (%.3f)", 
                     j, cand.text, cand.quality))
        end
    end
end
```

### 3. 性能监控
```lua
-- 性能统计
local performance_stats = {
    total_queries = 0,
    cache_hits = 0,
    average_response_time = 0,
    error_count = 0
}

function update_performance_stats(query_time, cache_hit, error_occurred)
    performance_stats.total_queries = performance_stats.total_queries + 1
    if cache_hit then
        performance_stats.cache_hits = performance_stats.cache_hits + 1
    end
    if error_occurred then
        performance_stats.error_count = performance_stats.error_count + 1
    end
    -- 更新平均响应时间
    performance_stats.average_response_time = 
        (performance_stats.average_response_time + query_time) / 2
end
```

## 部署建议

1. **测试环境**: 先在测试环境验证配置正确性
2. **渐进部署**: 逐步启用多段翻译功能
3. **性能监控**: 监控内存使用和响应时间
4. **用户反馈**: 收集用户使用体验并持续优化
5. **版本控制**: 对配置文件进行版本管理

通过这些配置和优化，可以在实际的Rime输入法中成功部署多段翻译功能，为用户提供高效的中英文混合输入体验。
