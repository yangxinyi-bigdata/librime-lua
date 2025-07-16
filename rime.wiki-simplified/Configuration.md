# Rime 配置文件

- [Rime 配置文件](#rime-配置文件)
  - [文件格式](#文件格式)
  - [位置及组织方式](#位置及组织方式)
  - [语法](#语法)
    - [包含](#包含)
    - [补丁\_\_patch](#补丁__patch)
    - [用补丁指令修改列表](#用补丁指令修改列表)
    - [可选的包含与补丁](#可选的包含与补丁)
    - [追加与合并](#追加与合并)
  - [配置编译器插件](#配置编译器插件)
    - [自动应用补丁](#自动应用补丁)
    - [应用默认配置](#应用默认配置)
    - [导入成套组件配置](#导入成套组件配置)
    - [导入韵书配置](#导入韵书配置)
  - [加载规则](#加载规则)
  - [配置组件调用方式](#配置组件调用方式)
  - [代码风格](#代码风格)
  - [错误处理](#错误处理)
  - [版本控制](#版本控制)
  - [分发](#分发)


Rime 配置文件，用于设置输入法引擎、输入法客户端的运行参数，也包括输入方案及词典配置。

## 文件格式

采用 UTF-8 编码的 [YAML][] 文本。

  [YAML]: http://yaml.org/

## 位置及组织方式

Rime 所使用的配置文件在 [[用户文件夹|UserData]] 及 [[共享文件夹|SharedData]]。

## 语法

在 [YAML][] 语法的基础上，增设以下编译指令：

### 包含

`__include:` 指令在当前位置包含另一 YAML 节点的内容。

可写在配置源文件任一 YAML map 节点下。其语法为

```yaml
include_example_1:
  __include: local/node

local:
  node: contents to include
```

被引用的节点可以来自另一个配置文件。
目标配置节点的路径以 `<filename>:/` 开始，可省略扩展名 `.yaml`。

```yaml
include_example_2:
  __include: config:/external/node

include_example_3:
  __include: config.yaml:/external/node
```

包含整个文件，可指定路径为目标配置文件的根节点：

```yaml
include_example_4:
  __include: config.yaml:/
```

包含另一个 YAML map 节点后，源文件中 `__include:` 指令所在 map 除编译指令外的其他数据与被包含的 map 合并：

```yaml
include_example_5:
  __include: some_map
  occupation: journalist # new key and value
  simplicity: very # override value for included key

some_map:
  simplicity: somewhat
  naivety: sometimes
```

合并发生在 `__include:` 指令所在节点，不会修改被引用节点 `some_map` 的内容。

包含 YAML 列表，则指令所在 map 节点替换为所引用的 YAML 列表。
该 map 节点不应包含任何编译指令以外的 key-value，因为不相容于 YAML 列表类型。

也不能直接在该节点下追加列表项，因为 YAML 语法不允许混合 map 与 list。
在包含列表后追加、修改列表项，必须使用下文介绍的 `__append:` 或 `__patch:` 指令。

```yaml
include_example_6:
  __include: some_list
  __append:
    - someone else

some_list:
  - youngster
  - elder
```

### 补丁__patch

修改某一相对路径下的配置节点，而非当前节点的整体。
基本语法为：

```yaml
__patch:
  key/alpha: value A
  key/beta: value B
```

目标节点路径的写法为将各级 map 的 key 用 `/` 分隔。
因此 `key` 如果包含 `/` 字符，则不能作为节点路径的一部分。

可在节点路径末尾添加 `/+` 操作符，表示合并 list 或 map 节点；
或者（可选地）添加 `/=` 表示用指定的值替换目标节点原有的值。
若未指定操作符，`__patch:` 指令的默认操作为替换。

以下是一些示例：

```yaml
patch_example_1:
  sibling: old value
  append_to_list:
    - existing item
  merge_with_map:
    key: value
  replace_list:
    - item 1
    - item 2
  replace_map:
    a: value
    b: value
  __patch:
    sibling: new value
    append_to_list/+:
      - appended item
    merge_with_map/+:
      key: new value
      new_key: value
    replace_list/=:
      - only item
    replace_map/=:
      only_key: value
```

以上示例仅为表现 `__patch:` 的作用方式。
实际上在当前节点和补丁内容均为字面值的情况下，没有打补丁的必要。
字面值补丁通常用于当前节点包含了其他节点，并需要修改部份配置项的场景：

```yaml
patch_example_2:
  __include: patch_example_1
  __patch:
    sibling: even newer value
    append_to_list/+:
      - another appended item
```

由于 YAML map 的 key 是无序的，书写顺序并不决定编译指令的先后。

同一节点下，编译指令的执行顺序为：
`__include:` 包含指定节点 → 合并当前节点下的其他 key-value 数据 → `__patch:` 修改子节点。

`__patch:` 指令的另一种主要用法是引用另一个节点中的补丁内容，并作用于指令所在节点：

```yaml
patch_example_3:
  __patch: changes
  some_list:
    - youngster
    - elder
  some_map:
    simplicity: somewhat
    naivety: sometimes

changes:
  some_list/+:
    - someone else
  some_map/simplicity: too much
```

YAML 语法不允许 map 有重复的 key。
如果要引用不同位置的多项补丁，可以为 `__patch:` 指定一个列表，其中每项通过节点引用定义一组补丁：

```yaml
patch_example_4:
  __include: base_config
  __patch:
    - company_standard
    - team_convention
    - personal_preference

base_config:
  actors: []
  company_info:
    based_in: unknown location
  favorites: {}

company_standard:
  company_info/based_in: american san diego

team_convention:
  actors/+:
    - feifei
    - meimei
    - riri

personal_preference:
  favorites/fertilizer: jinkela
```

### 用补丁指令修改列表

补丁指令中，目标节点路径由各级节点的 key 组成。
若某一节点为 list 类型，可以 `@<下标>` 形式指定列表项。下标从 0 开始计数。
无论列表长度，末位列表元素可表示为 `@last`。

```yaml
patch_list_example_1:
  some_list/@0/simplicity: very
  some_list/@last/naivety: always

some_list:
  - simplicity: somewhat
  - naivety: sometimes
```

在指定元素之前、之后插入列表元素，用 `@before <下标>`、`@after <下标>`。
`@after last` 可简写为 `@next`，向列表末尾添加元素：

```yaml
patch_list_example_2:
  'some_list/@before 0/youthfulness': too much
  'some_list/@after last/velocity': greater than westerners
  some_list/@next/questions: no good
```

### 可选的包含与补丁

若包含或补丁指令的目标是以 `?` 结尾的节点路径，
则当该路径对应的节点（或所属外部配置文件）不存在时，不产生编译错误。

如：

```yaml
__patch: default.custom:/patch?

nice_to_have:
  __include: optional_config?
```

### 追加与合并

追加指令 `__append:` 将其下的列表项追加到该指令所在的节点。
合并指令 `__merge:` 将其下的 map 合并到该指令所在的节点。

这两条指令只能用在 `__include:` 指令所在节点及其（字面值）子节点。

```yaml
append_merge_example_1:
  __include: starcraft
  __merge:
    made_by: blizzard entertainment
    races:
      __append:
        - protoss
        - zerg

starcraft:
  first_release: 1998
  races:
    - terrans
```

实际书写配置时，`__merge:` 指令往往省略。
因为 `__include:` 指令自动合并其所在节点下的 key-value 并递归地合并所有 map 类型的子节点。

而对于类型为 list 的子节点，默认操作是替换整个列表。
如果要以向后追加列表项的方式合并，除了 `__append:` 指令之外，还可以采用 `/+` 操作符：

```yaml
append_merge_example_2:
  __include: starcraft
  made_by: blizzard entertainment
  races/+:
    - protoss
    - zerg
```

在 `__include:` 指令自动合并的节点树中，如果要对某个 map 类型的子节点整体替换，可使用 `/=` 操作符：

```yaml
revealed_map:
  __include: old_map
  terran_command_center/=:
    x: 3.14
    y: 6.28
old_map:
  terran_command_center:
    location: unexplored
  protoss_nexus: {x: 128, y: 256}
  zerg_hatchary: {x -1024, y: 0}
```

案例解析：

- https://github.com/rime/librime/pull/192#issuecomment-371202389

## 配置编译器插件

自动添加一些隐含的编译指令，用来实现对原有补丁机制以及导入成套组件配置等语法的兼容。

这些插件的作用是将当前输入方案所需的全部配置内容在部署期间汇总到一份编译结果文件里。使输入法程序不必在运行时打开众多的配置文件。

### 自动应用补丁

配置文件的根节点如果没有使用 `__patch:` 指令，则在源文件编译完成后，自动插入以下指令：

（注：请将实际的配置名称代入 `<config>`）

```yaml
# <config>.yaml 或 <config>.schema.yaml 的根节点
__patch: <config>.custom:/patch?
```

如果存在与旧版本 librime 兼容的补丁文件，则从中加载补丁：

```yaml
# <config>.custom.yaml
patch:
  key: value
```

以上插件的效果相当于

```yaml
# <config>.yaml 或 <config>.schema.yaml 的根节点
__patch:
  key: value
```

如果源文件的根节点使用了 `__patch:` 指令，则不论其是否加载 `<config>.custom:/patch`，都不再添加自动补丁指令。
如果这种情况下仍希望支持补丁文件，须将其列为 `__patch:` 列表中的一项：

```yaml
# <config>.yaml 或 <config>.schema.yaml 的根节点
__patch:
  - other_patch # ...
  - <config>.custom:/patch?
```

### 应用默认配置

输入方案中未指定以下配置项时，自动导入默认配置 `default.yaml` 的定义：

```yaml
menu:
  page_size: # ...
```

### 导入成套组件配置

将部份组件配置中的 `<component>/import_preset: <config>` 语法翻译为

（注：请将实际的配置名称和组件名称代入 `<config>`、`<component>`）

```yaml
<component>:
  __include: <config>:/<component>
  # 以下为输入方案覆盖定义的内容
```

注意：如果指定的配置节点 `<config>:/<component>` 不存在会导致输入方案编译错误。

### 导入韵书配置

（尚未实现）导入 `*.dict.yaml` 的 YAML 配置部份。

## 加载规则

以上介绍的编译指令及编译器插件，仅对交给 *配置编译器* 处理的 *源文件* 有效。

配置源文件的位置详见 [[用户文件夹|UserData]] 及 [[共享文件夹|SharedData]]。

输入法程序运行时读取的配置文件是 *编译结果文件*（可能是 YAML 格式或二进制格式）。
编译结果只包含直接供程序读取的配置内容，而不再包含有特殊含义的编译指令。

配置的编译结果文件与源文件并非一一对应的关系，
而是合并重组为编译后的默认配置 `default` 以及各输入方案的配置。

其他不经过编译处理而直接在运行时由输入法程序存取的配置文件有：
`installation.yaml`, `user.yaml` 等。

*韵书* 文件中的 YAML 配置部份目前也不支持配置编译指令。

TODO(rime/docs): 详解 YAML 节点树及编译指令的解析、执行顺序

## 配置组件调用方式

TODO(rime/engine): 完成本节

## 代码风格

YAML 书写样式参照 [yaml.org][YAML] 的示例。推荐以下风格：

配置文件开头用注释行简述文件的内容和使用方法。

缩进：用两个空格缩进。

字符串值：无特殊字符时不使用引号；
需要使用引号时，优先用单引号，以减少双引号引起的字符转义问题。

flow-style list: 仅在节点树的最内层使用。不嵌套使用。元素较多时不用。

flow-style map: 仅在节点树的最内层使用。不嵌套使用。元素较多时不用。

仅包含一对 key-value 的 map 作为列表项时，省略 `{ }` 并与 `-` 写在同一行。

不推荐使用 YAML 的锚点（`&`）和别名引用（`*`）。请用本文介绍的 `__include:` 编译指令。

## 错误处理

部署后出现错误，请查看 `INFO` 日志（[参考][debug]），
找到行首字符为 `E` 的记录，根据错误信息以及上下文排查出错的配置文件。

未出现错误信息，配置亦未达到预期效果，请对照 `<用户文件夹>/build/` 文件夹内的编译结果文件，检查配置源文件与补丁。

  [debug]: https://github.com/rime/home/wiki/RimeWithSchemata#%E9%97%9C%E6%96%BC%E8%AA%BF%E8%A9%A6

## 版本控制

输入方案及配置的版本可以用文件中的一项 *字符串值* 记录。如：`version: '3.14'`

版本号习惯以形为 `X.Y.Z` 的多个数字组成。
为避免将版本号解析为 YAML 数值类型而发生错误，如 `0.10`（〇点十）不同于 `0.1`（〇点一），
应一律为版本号加上引号 `'3.14'` 以示其为字符串类型。

## 分发

输入方案设计师完成输入方案及配套韵书后，将源文件发布在一间 [GitHub][] 代码库，
用家便可通过 Rime 配置管理工具 [东风破][plum] 获取输入方案的最新版本并安装到输入法。

  [GitHub]: https://github.com
  [plum]: https://github.com/rime/plum
