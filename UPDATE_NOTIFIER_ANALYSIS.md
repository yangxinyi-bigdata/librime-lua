# context.update_notifier 触发时机详细分析

## 概述

`context.update_notifier` 是Rime中最重要和最频繁触发的通知器之一，它在Context对象的状态发生变化时触发。通过分析Rime核心源代码，我发现了所有触发 `update_notifier` 的具体场景。

## 触发时机

### 1. 输入内容变化时

#### 1.1 添加输入字符
```cpp
// src/rime/context.cc:58-87
bool Context::PushInput(char ch) {
    // ...添加字符逻辑...
    update_notifier_(this);  // 触发通知
    return true;
}

bool Context::PushInput(const string& str) {
    // ...添加字符串逻辑...
    update_notifier_(this);  // 触发通知
    return true;
}
```

**触发场景：**
- 用户按下字母键输入字符
- 用户输入拼音、汉字等
- 通过API添加输入内容

#### 1.2 删除输入内容
```cpp
// src/rime/context.cc:88-111
bool Context::PopInput(size_t len) {
    // ...删除逻辑...
    update_notifier_(this);  // 触发通知
    return true;
}

bool Context::DeleteInput(size_t len) {
    // ...删除逻辑...
    update_notifier_(this);  // 触发通知
    return true;
}
```

**触发场景：**
- 用户按退格键删除字符
- 用户按Delete键删除字符
- 通过API删除输入内容

#### 1.3 清空输入
```cpp
// src/rime/context.cc:103-108
void Context::Clear() {
    input_.clear();
    caret_pos_ = 0;
    composition_.clear();
    update_notifier_(this);  // 触发通知
}
```

**触发场景：**
- 用户按Escape键清空输入
- 程序清空输入状态
- 输入法状态重置

### 2. 光标位置变化时

```cpp
// src/rime/context.cc:258-266
void Context::set_caret_pos(size_t caret_pos) {
    if (caret_pos > input_.length())
        caret_pos_ = input_.length();
    else
        caret_pos_ = caret_pos;
    update_notifier_(this);  // 触发通知
}
```

**触发场景：**
- 用户按左右方向键移动光标
- 用户点击输入框改变光标位置
- 程序设置光标位置

### 3. 候选词选择状态变化时

```cpp
// src/rime/context.cc:126-144
bool Context::Highlight(size_t index) {
    // ...选择逻辑...
    seg.selected_index = new_index;
    update_notifier_(this);  // 触发通知
    return true;
}
```

**触发场景：**
- 用户按上下方向键切换候选词
- 用户通过数字键选择候选词
- 程序高亮显示候选词

### 4. 组合状态重新计算时

```cpp
// src/rime/context.cc:198-208
bool Context::ReopenPreviousSegment() {
    if (composition_.Trim()) {
        // ...重新打开逻辑...
        update_notifier_(this);  // 触发通知
        return true;
    }
    return false;
}
```

```cpp
// src/rime/context.cc:250-258
bool Context::RefreshNonConfirmedComposition() {
    if (ClearNonConfirmedComposition()) {
        update_notifier_(this);  // 触发通知
        return true;
    }
    return false;
}
```

**触发场景：**
- 输入法重新分析输入内容
- 删除未确认的组合片段
- 重新打开之前的输入片段

### 5. 重新打开之前的选择时

```cpp
// src/rime/context.cc:220-239
bool Context::ReopenPreviousSelection() {
    // ...重新打开逻辑...
    it->Reopen(caret_pos());
    update_notifier_(this);  // 触发通知
    return true;
}
```

**触发场景：**
- 用户撤销之前的选择
- 重新编辑已确认的内容

## 触发频率

`update_notifier` 是**最高频**触发的通知器：

1. **每次按键几乎都触发** - 包括字母、数字、方向键等
2. **光标移动时触发** - 左右移动、点击等
3. **候选词切换时触发** - 上下选择候选词
4. **状态变化时触发** - 输入法内部状态更新

## 与其他通知器的区别

| 通知器 | 触发频率 | 主要用途 |
|--------|----------|----------|
| `update_notifier` | 极高 | 所有状态变化 |
| `commit_notifier` | 低 | 仅内容上屏时 |
| `select_notifier` | 中 | 仅确认选择时 |
| `delete_notifier` | 极低 | 请求删除候选词时 |

## 实际监听示例

```lua
function init(env)
    local context = env.engine.context
    
    env.update_notifier = context.update_notifier:connect(function(ctx)
        -- 这里会被频繁调用
        local input = ctx.input or ""
        local caret_pos = ctx.caret_pos
        local is_composing = ctx:is_composing()
        
        print(string.format("输入变化: '%s', 光标:%d, 组合:%s", 
                           input, caret_pos, tostring(is_composing)))
    end)
end
```

## 注意事项

### 1. 性能考虑
由于触发频率极高，在监听函数中应该：
- 避免复杂计算
- 避免频繁的文件I/O
- 避免网络请求
- 使用缓存减少重复计算

### 2. 状态检测模式
通常需要保存上一次的状态来检测变化：

```lua
local last_state = {
    input = "",
    caret_pos = 0,
    is_composing = false
}

env.update_notifier = context.update_notifier:connect(function(ctx)
    local current_input = ctx.input or ""
    local current_caret = ctx.caret_pos
    local current_composing = ctx:is_composing()
    
    -- 检测特定的变化
    if last_state.input ~= current_input then
        print("输入内容变化")
    end
    
    if last_state.caret_pos ~= current_caret then
        print("光标位置变化")
    end
    
    -- 更新状态
    last_state.input = current_input
    last_state.caret_pos = current_caret
    last_state.is_composing = current_composing
end)
```

### 3. 内存泄露预防
务必在 `fini` 函数中断开连接：

```lua
function fini(env)
    if env.update_notifier then
        env.update_notifier:disconnect()
    end
end
```

## 总结

`context.update_notifier` 在几乎每次用户交互时都会触发，是监听Rime输入状态变化的核心机制。它提供了最全面的状态监听能力，但也需要注意性能和正确的使用方式。
