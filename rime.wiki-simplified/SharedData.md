# 共享文件夹

存放由本机多个用户共享的文件，通常由输入法安装程序写入。

Rime 输入法在查找一项资源的时候，会优先访问 [[用户文件夹|UserData]] 中的文件。
用户文件不存在时，再到共享文件夹中寻找。

一些 Linux 发行版可由 `rime-data` 软件包安装常用数据文件到这里。或用 [/plum/][plum-make-install] 编译安装。

  [plum-make-install]: https://github.com/rime/plum#install-as-shared-data

## 位置

`librime` 允许输入法指定共享文件夹的位置。

- **小狼毫：** `<安装目录>\data`
- **鼠须管：** `"/Library/Input Methods/Squirrel.app/Contents/SharedSupport"`
- **ibus-rime, fcitx-rime:** `/usr/share/rime-data` （编译时可配置）

## 内容

输入方案、韵书、默认配置源文件：

- `<输入方案代号>.schema.yaml`: 用户下载或自定义的 *输入方案*。
- `<韵书代号>.dict.yaml`: 用户下载或自定义的 *韵书*。
- `<词典名称>.txt`: 文本格式的词典，如预设词汇表。

也可以包含编译后的机读格式，从而省去用户部署时从相同源文件再次编译的步骤：

- `build/*` 快取文件。为使输入法程序高效运行，预先将配置、韵书等编译为机读格式。

注： `librime` 1.3 版本之前，编译后的快取文件直接存放在共享文件夹，与源文件并列。

其他：

- `opencc/*` - [OpenCC](https://github.com/BYVoid/OpenCC) 字形转换配置及字典文件。

