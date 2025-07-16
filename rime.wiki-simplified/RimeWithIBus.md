> Building and installing ibus-rime.

# Packages for Linux Distributions

## Archlinux

    pacman -S ibus-rime

## Debian

Rime 已收录于 [Debian Jessie](https://wiki.debian.org/DebianJessie) 及以上版本

    sudo apt-get install ibus-rime # or fcitx-rime

## Gentoo

    emerge ibus-rime  # or fcitx-rime

## Ubuntu

Rime 已收录于 [Ubuntu 12.10 (Quantal Quetzal)](http://old-releases.ubuntu.com/releases/12.10/) 及以上版本

    sudo apt-get install ibus-rime

安装更多输入方案：（推荐使用 [/plum/](https://github.com/rime/plum) 安装最新版本）

    # 朙月拼音（预装）
    sudo apt-get install librime-data-luna-pinyin
    # 双拼
    sudo apt-get install librime-data-double-pinyin
    # 宫保拼音
    sudo apt-get install librime-data-combo-pinyin
    # 注音、地球拼音
    sudo apt-get install librime-data-terra-pinyin librime-data-bopomofo
    # 仓颉五代（预装）
    sudo apt-get install librime-data-cangjie5
    # 速成五代
    sudo apt-get install librime-data-quick5
    # 五笔86、袖珍简化字拼音、五笔画
    sudo apt-get install librime-data-wubi librime-data-pinyin-simp librime-data-stroke-simp
    # IPA (X-SAMPA)
    sudo apt-get install librime-data-ipa-xsampa
    # 上海吴语
    sudo apt-get install librime-data-wugniu
    # 粤拼
    sudo apt-get install librime-data-jyutping
    # 中古汉语拼音
    sudo apt-get install librime-data-zyenpheng

## Fedora 22+

    sudo dnf install ibus-rime

## Fedora 18/19

    sudo yum install ibus-rime

## OpenSUSE tumbleweed & 15
    
    sudo zypper in ibus-rime

## Solus

    sudo eopkg it ibus-rime

有手艺、有时间、热心肠的Linux技术高手！ 请帮我把Rime打包到你喜爱的Linux发行版，分享给其他同学吧。

谢谢你们！

# Manual Installation

## Prerequisites

To build la rime, you need these tools and libraries:
  * capnproto (for librime>=1.6)
  * cmake
  * boost >= 1.46
  * glog (for librime>=0.9.3)
  * gtest (optional, recommended for developers)
  * libibus-1.0
  * libnotify (for ibus-rime>=0.9.2)
  * kyotocabinet (for librime<=1.2)
  * leveldb (for librime>=1.3, replacing kyotocabinet)
  * libmarisa (for librime>=1.2)
  * opencc
  * yaml-cpp

Note: If your compiler doesn't fully support C++11, please checkout `oldschool` branch from https://github.com/rime/librime/tree/oldschool

## Build and install ibus-rime

Checkout the repository:

    git clone https://github.com/rime/ibus-rime.git
    cd ibus-rime

If you haven't installed dependencies (librime, rime-data), install those first:

    git submodule update --init
    (cd librime; make && sudo make install)
    (cd plum; make && sudo make install)
    
Finally:

    make
    sudo make install

## Configure IBus

  * restart IBus (`ibus-daemon -drx`)
  * in IBus Preferences (`ibus-setup`), add "Chinese - Rime" to the input method list

Voilà !

## ibus-rime on Ubuntu 12.04 安装手记

注：这篇文章过时了。

今天天气不错，我更新了一把Ubuntu，记录下安装 ibus-rime 的步骤。

    # 安装编译工具
    sudo apt-get install build-essential cmake

    # 安装程序库
    sudo apt-get install libopencc-dev libz-dev libibus-1.0-dev libnotify-dev

    sudo apt-get install libboost-dev libboost-filesystem-dev libboost-regex-dev libboost-signals-dev libboost-system-dev libboost-thread-dev
    # 如果不嫌多，也可以安装整套Boost开发包（敲字少：）
    # sudo apt-get install libboost-all-dev
    
    # 下文略……

## ibus-rime on Centos 7
```
yum install -y gcc gcc-c++ boost boost-devel cmake make cmake3
yum install glog glog-devel kyotocabinet kyotocabinet-devel marisa-devel yaml-cpp yaml-cpp-devel gtest gtest-devel libnotify zlib zlib-devel gflags gflags-devel leveldb leveldb-devel libnotify-devel ibus-devel
cd /usr/src

# install opencc
curl -L https://github.com/BYVoid/OpenCC/archive/ver.1.0.5.tar.gz | tar zx
cd OpenCC-ver.1.0.5/
make
make install
ln -s /usr/lib/libopencc.so /usr/lib64/libopencc.so

cd /usr/src
git clone --recursive https://github.com/rime/ibus-rime.git

cd /usr/src/ibus-rime
# 下文略，同前文给出的安装步骤

```