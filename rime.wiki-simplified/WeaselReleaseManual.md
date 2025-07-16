# weasel 发布手册

TODO: 更新该文档，以反映自动化发布流程

1.  在 [Trello](https://trello.com/b/iUJWFnjb/rime-development) 或笔记本上辟一叶纸，记下主要更新内容，方便粘贴到更新日志。
    例如 https://trello.com/c/WieadeZt
1.  对比上次发布（git tag），检查 `weasel.yaml` 是否需要更新版本号。
    注：检查配置更新的机制改动后，这一步不严格要求。但仍建议更新小狼毫配置同时升级该配置文件的版本。
1.  代码交齐后，用工具根据惯例格式生成变更记录。（这一步合并到 `update/bump-version.sh` 脚本中）
    以 clog-cli 为例，为新版本 0.11.0 生成变更记录，做法是
    ``` sh
    # cargo install clog-cli
    cd weasel
    clog --from-latest-tag \
        --changelog CHANGELOG.md \
        --repository https://github.com/rime/weasel \
        --setversion 0.11.0
    ```
1.  把手写的「主要更新」列在变更记录文件中本次发布的标题下，格式（包括空行）须与自动生成的段落相同：
    ``` markdown
    <a name="0.11.0"></a>
    ## 0.11.0 (2018-04-07)


    #### 主要更新

    * 新增 [Rime 配置管理器](https://github.com/rime/plum)，通过「输入法设定／获取更多输入方案」调用
    * 在输入法语言栏显示状态切换按钮（TSF 模式）
    * 修复多个前端兼容性问题
    * 新增配色主题「现代蓝」`metroblue`、「幽能」`psionics`

    #### Features
    ```
1.  提交对变更记录的修改（可以与版本号的修改合并为一条提交记录）
    ``` sh
    git commit --all --message "docs(CHANGELOG.md): release 0.11.0"
    ```
1.  用脚本更新输入法程序的版本号，并提交修改过的文件（脚本会在最后调用 `clog` 提取更新日志）
    ``` sh
    update/bump-version.sh # print usage
    update/bump-version.sh 0.10.0 0.11.0

    git commit --all --message "chore(release): 0.11.0 :tada:"
    ```
1.  以上提交在 `master` 完成。如果在另一个分支发布，如 `legacy`，则将以上修改合并到分支。
1.  push 所有修改到 GitHub。检验 CI build：下载安装程序，测试全新安装以及从上一个推送版本升级。
1.  确认该版本可发布后，在 `master` 或要做发布的分支上打标签。推送标签到 GitHub 会在安装包构建完成后自动触发发布到 bintray release 频道的部署作业。
    ``` sh
    git tag --annotate 0.11.0 --message "chore(release): 0.11.0 :tada:"
    git push --tags
    ```
1.  AppVeyor 已经创建好了版本，并上传了文件，只等一键发布。如果手动完成，这个过程为：
    将（release tag 触发的） CI build 生成的安装包上传到 bintray。
    在 https://bintray.com/rime/weasel/release 新建版本 (New version)，命名为版本号 `0.11.0`，描述：`小狼毫 0.11.0`。
    为新建的版本上传文件 `weasel-0.11.0.0-installer.exe`。
1.  生成显示在推送更新介面的变更记录。只包含 `CHANGELOG.md` 的最新版本章节，格式为朴素的 HTML 网页。
    ``` sh
    # npm install --global marked
    update/write-release-notes.sh
    ```
    留存生成的 `release-notes.html` 文件备用。
1.  使用 [Hexo](https://hexo.io/) 在官方网站 <rime.im> 发布更新。

    ``` sh
    git clone https://github.com/rime/home.git rime-home
    cd rime-home/blog
    npm install

    npm install --global hexo-cli

    # TODO(keyholder): edit files
    cp ~/code/rime/weasel/update/appcast.xml ~/code/rime/home/blog/source/release/weasel/appcast.xml
    cp ~/code/rime/weasel/update/testing-appcast.xml ~/code/rime/home/blog/source/testing/weasel/appcast.xml
    cp ~/code/rime/weasel/release-notes.html ~/code/rime/home/blog/source/release/weasel/release-notes.html
    cp ~/code/rime/weasel/release-notes.html ~/code/rime/home/blog/source/testing/weasel/release-notes.html

    cat <<EOF > ~/code/rime/home/blog/source/release/weasel/index.md
    title: 【小狼毫】更新日志
    comments: false
    $(date '+date: %Y-%m-%d %H:%M:%S')
    ---

    EOF
    cat ~/code/rime/weasel/CHANGELOG.md >> ~/code/rime/home/blog/source/release/weasel/index.md
    cp ~/code/rime/home/blog/source/release/weasel/index.md  ~/code/rime/home/blog/source/testing/weasel/index.md
    ```

    需要修改的内容包括：

    - [首叶](https://rime.im/) 的下载按钮：[源代码](https://github.com/rime/home/blob/master/blog/source/_data/downloads.yaml)
    - [下载叶](https://rime.im/download/) 的版本号及下载链接：[源代码](https://github.com/rime/home/blob/master/blog/source/download/index.md)
    - [更新日志](https://rime.im/release/weasel/)，
      更新 [源代码](https://github.com/rime/home/blob/master/blog/source/release/weasel/index.md) 文件头的 `date` 字段，
      并用 `weasel/CHANGELOG.md` 的内容替换 Markdown 正文部份（YAML 结束标记 `---` 及随后空行以下）
    - [推送更新频道](https://rime.im/release/weasel/appcast.xml)，
      将 [源代码](https://github.com/rime/home/blob/master/blog/source/release/weasel/appcast.xml) 替换为第 5 步修改过的 `weasel/update/appcast.xml`
    - [推送更新提示](https://rime.im/release/weasel/release-notes.html)，
      将 [源代码](https://github.com/rime/home/blob/master/blog/source/release/weasel/release-notes.html) 替换为第 10 步生成的 `release-notes.html`

    测试频道（用于手动检查更新）自动化调试就绪前，将 `blog/source/release/weasel/` 的内容复制到 `blog/source/testing/weasel/`，唯独需要用 `weasel/update/testing-appcast.xml` 更新 `blog/source/testing/weasel/appcast.xml`。

1.  修改完成后，在本地调试网站。

    ``` sh
    # check your changes with local HTTP server
    hexo server
    ```

    方法为：将以上修改过的网叶地址中的域名部份替换为 Hexo 提示的本地服务器地址，在浏览器中预览各个网叶，检查文字内容和链接地址。

1.  确认内容无误，用 Hexo 发布网站。

    ``` sh
    # first time releaser, setup without deployment
    hexo deploy --setup

    # source XML/HTML files in generated folder may not get updated.
    hexo clean

    # publish website at rime.github.io
    hexo deploy --generate
    ```

    发布完成后，可以在 https://github.com/rime/rime.github.io/commits/master 复查提交到 GitHub Pages 的修订。

1.  提交以上修改到 `rime/home` 代码库。

1.  如果本次发布不是针对小狼毫 0.9 的升级版本（见第 6 步），发布至此完成。
    否则需要在验证新版本工作正常后，将其推送到位于 <rimeime.github.io> 的旧更新频道。

    首先需要取得 [rimeime.github.io](https://github.com/rimeime/rimeime.github.io) 的写权限。

    ``` sh
    git clone https://github.com/rimeime/rimeime.github.io
    cd rimeime.github.io
    ```

1.  编辑 `weasel-update/appcast.xml` 以及 `weasel-update/pioneer/appcast.xml`：
    从第 5 步的 `weasel/update/appcast.xml` 复制 `<item>` 标签的内容，视情况修改 `channel > title` 文字中的升级终点版本号。

    当前版本同时在新、旧两个更新频道发布，因此不必修改 <rimeime.github.io> 的更新日志。
    因为根据 `appcast.xml` 中 `<sparkle:releaseNotesLink>` 的定义，推送更新提示一律从新官网 <rime.github.io> 加载。

1.  最后提交修改，发出 pull-request。修改并入 `master` 即开始推送更新。
