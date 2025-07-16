# context.delete_notifier 触发时机详细分析

## 概述

根据Rime核心源代码分析，`context.delete_notifier` 是一个**极低频**触发的通知器，专门用于处理候选词删除请求。需要注意的是，这个通知器触发时**候选词不一定真的被删除**，它只是一个删除请求的通知。

## 核心触发代码

```cpp
// src/rime/context.cc:145-161
bool Context::DeleteCandidate(size_t index) {
  if (composition_.empty())
    return false;
  Segment& seg(composition_.back());
  seg.selected_index = index;
  DLOG(INFO) << "Deleting candidate: " << seg.GetSelectedCandidate()->text();
  delete_notifier_(this);  // 在这里触发通知
  return true;  // CAVEAT: this doesn't mean anything is deleted for sure
}

bool Context::DeleteCurrentSelection() {
  if (composition_.empty())
    return false;
  Segment& seg(composition_.back());
  return DeleteCandidate(seg.selected_index);
}
```

## 触发时机

### 1. 通过API删除候选词
```cpp
// 从外部API调用
RimeDeleteCandidate(session_id, index);
RimeDeleteCandidateOnCurrentPage(session_id, index);
```

### 2. 通过编辑器删除当前选择
```cpp
// src/rime/gear/editor.cc:161-163
bool Editor::DeleteCandidate(Context* ctx) {
  ctx->DeleteCurrentSelection();
  return true;
}
```

### 3. 用户操作触发删除
- 通常通过特定的按键绑定（如 Ctrl+Delete 或其他自定义键）
- 通过输入法界面的删除按钮
- 通过编程接口直接调用

## 什么时候可以删除候选词？

### 1. 基本条件
- **必须有活跃的组合（composition）**：`!composition_.empty()`
- **必须有候选词菜单**：当前段落必须有可选的候选词
- **必须有有效的候选词索引**：指定的索引位置必须存在候选词

### 2. 实际删除的处理
`delete_notifier` 只是**请求删除**，实际删除由其他组件处理：

```cpp
// src/rime/gear/memory.cc:127-149
void Memory::OnDeleteEntry(Context* ctx) {
  if (!user_dict_ || user_dict_->readonly() || !ctx || !ctx->HasMenu())
    return;
  auto phrase = 
      As<Phrase>(Candidate::GetGenuineCandidate(ctx->GetSelectedCandidate()));
  if (Language::intelligible(phrase, this)) {
    const DictEntry& entry(phrase->entry());
    LOG(INFO) << "deleting entry: '" << entry.text << "'.";
    user_dict_->UpdateEntry(entry, -1);  // 在用户词典中标记为已删除
    ctx->RefreshNonConfirmedComposition();
  }
}
```

### 3. 删除限制
- **只读词典**：如果用户词典是只读的，无法删除
- **系统词汇**：某些内置词汇可能无法删除
- **词汇类型**：只有特定类型的候选词（如用户词汇）可以被删除
- **权限限制**：某些情况下没有删除权限

## 典型使用场景

### 1. 删除错误的用户词汇
```lua
function init(env)
    local context = env.engine.context
    
    env.delete_notifier = context.delete_notifier:connect(function(ctx)
        local candidate = ctx:GetSelectedCandidate()
        if candidate then
            print("请求删除候选词: " .. candidate.text)
            -- 可以在这里添加额外的删除逻辑或确认
        end
    end)
end
```

### 2. 删除确认或记录
```lua
env.delete_notifier = context.delete_notifier:connect(function(ctx)
    local candidate = ctx:GetSelectedCandidate()
    if candidate then
        -- 记录删除操作
        local timestamp = os.date("%Y-%m-%d %H:%M:%S")
        local log_entry = string.format("[%s] 删除请求: %s\n", 
                                       timestamp, candidate.text)
        
        -- 写入删除日志
        local log_file = io.open("delete_log.txt", "a")
        if log_file then
            log_file:write(log_entry)
            log_file:close()
        end
        
        -- 可选：显示确认消息
        print("已请求删除: " .. candidate.text)
    end
end)
```

### 3. 实现删除确认机制
```lua
env.delete_notifier = context.delete_notifier:connect(function(ctx)
    local candidate = ctx:GetSelectedCandidate()
    if candidate then
        -- 检查是否是重要词汇
        local important_words = {"重要", "常用", "系统"}
        for _, word in ipairs(important_words) do
            if string.find(candidate.text, word) then
                print("警告: 尝试删除重要词汇 '" .. candidate.text .. "'")
                -- 可以选择阻止删除或要求额外确认
                return false
            end
        end
        
        print("确认删除: " .. candidate.text)
    end
end)
```

## 重要注意事项

### 1. 删除不保证成功
```cpp
// 注释说明：this doesn't mean anything is deleted for sure
return true;  // 返回true不意味着候选词真的被删除了
```

`delete_notifier` 触发只表示**收到了删除请求**，实际删除需要：
- 用户词典支持删除操作
- 词汇类型允许删除
- 系统有足够权限

### 2. 触发频率极低
- 只在明确的删除操作时触发
- 不像 `update_notifier` 那样频繁
- 主要用于删除用户自定义词汇

### 3. 与其他通知器的配合
```lua
-- 通常需要配合其他通知器使用
env.delete_notifier = context.delete_notifier:connect(function(ctx)
    -- 删除请求处理
end)

env.update_notifier = context.update_notifier:connect(function(ctx)
    -- 检查删除后的状态更新
end)
```

## 实际应用示例

### 删除功能的完整实现
```lua
local function setup_delete_monitoring(env)
    local context = env.engine.context
    
    -- 记录删除统计
    local delete_stats = {
        total_requests = 0,
        successful_deletes = 0,
        failed_deletes = 0
    }
    
    env.delete_notifier = context.delete_notifier:connect(function(ctx)
        delete_stats.total_requests = delete_stats.total_requests + 1
        
        local candidate = ctx:GetSelectedCandidate()
        if candidate then
            print(string.format("删除请求 #%d: '%s'", 
                               delete_stats.total_requests, candidate.text))
            
            -- 检查删除条件
            if can_delete_candidate(candidate) then
                delete_stats.successful_deletes = delete_stats.successful_deletes + 1
                print("  → 删除条件满足")
            else
                delete_stats.failed_deletes = delete_stats.failed_deletes + 1
                print("  → 删除条件不满足")
            end
            
            -- 输出统计信息
            print(string.format("删除统计: 请求=%d, 成功=%d, 失败=%d",
                               delete_stats.total_requests,
                               delete_stats.successful_deletes,
                               delete_stats.failed_deletes))
        end
    end)
end

function can_delete_candidate(candidate)
    -- 检查候选词是否可以删除
    local type = candidate.type
    return type == "user_phrase" or type == "user_table"
end
```

## 总结

`context.delete_notifier` 是一个专门用于候选词删除请求的通知器：

1. **触发时机**：仅在明确请求删除候选词时触发
2. **触发频率**：极低，只有用户主动删除词汇时
3. **主要用途**：删除用户自定义词汇、错误录入的词汇
4. **注意事项**：触发不等于删除成功，需要配合其他机制使用

这个通知器主要用于用户词汇管理，是Rime个性化功能的重要组成部分。
