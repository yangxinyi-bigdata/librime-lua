### 如何定制输入法？

请查阅[[定制指南|CustomizationGuide]]。

### 如何卸载鼠须管（Squirrel）？

1. 开启系统输入法设定面板，移除「鼠须管」。
2. 打开 Finder 并按下 command+shift+G 前往 `/Library/Input Methods` 档案夹，移除「鼠须管.app」。
3. 如上，前往 `~/Library` 并移除个人鼠须管设定资料夹 `Rime`。
4. 重新登入系统，确保清理完毕。

### 如何使用双拼时，启动台湾繁体习惯用字？（Linux + ibus或fcitx）
例如：

    为→为
    启→启
    着→著
    里→里
    面→面 …等
1. 在方案Schema里面，switches项目之下加：

    \- name: zh_tw  
    &nbsp;&nbsp;  reset: 1

2. Schema档案中再来多件一项simplifier项目（在reverse lookup下面位置），如下：

    simplifier:  
    &nbsp;&nbsp;opencc_config: t2tw.json  
    &nbsp;&nbsp;option_name: zh_tw

3. 输入引擎（ibus或fcitx）重新开启后，就应该成功打出《面包》、《里面》等台湾繁体字。  
（注：schema档案在 ~/.config/ibus/rime/ 里面）

Windows用户的简单设定方法：
1. 按下Windows键
2. 寻找【小狼毫输入法设定】 
3. 选择【繁体正题】