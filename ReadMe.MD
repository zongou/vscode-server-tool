# 在termux或alpine上运行code-server/openvscode-server

在termux上直接运行，非proot环境

    这里提供两种方法：
    1：使用yarn构建code-server
    2：给已发布的程序包打补丁

# 使用

```shell
git clone https://github.com/zongou/vscode-server-tool.git
cd vscode-server-tool
```

## 方式1

#### 使用yarn构建code-server

```shell
./vscode-server-tool.sh build
# 速度慢的话加上 --cn-proxy 选项 使用代理加速
./vscode-server-tool.sh --cn-proxy build
```

#### 启动程序

```shell
./code-server/node_modules/.bin/code-server --host 0.0.0.0 --port 8080 --auth none
# 或
./code-server/node_modules/code-server/out/node/entry.js --host 0.0.0.0 --port 8080 --auth none
```

### 放到 bin 目录里

```shell
# termux
ln -s $(realpath ./code-server/node_modules/code-server/out/node/entry.js) $PREFIX/bin/code-server
# alpine
ln -s $(realpath ./code-server/node_modules/code-server/out/node/entry.js) /usr/local/bin/code-server
```

## 方式2

### 打补丁

可以对code-server以及openvscode-server打补丁
先下载程序包

- [openvscode-server发布页](https://github.com/gitpod-io/openvscode-server/releases)  
- [code-server发布页](https://github.com/coder/code-server/releases)  

#### 解压

```shell
tar -xf [tar程序包]
```

#### 打补丁

```shell
./vscode-server-tool.sh patch [程序目录]
```

#### 启动程序

```shell
# code-server
./[程序目录]/bin/code-server --host 0.0.0.0 --port 8080 --auth none
# openvscode-server
./程序目录/bin/openvscode-server --host 0.0.0.0 --port 8080 --without-connection-token
```

## ！！一些存在的问题

### termux上直接运行的问题

1. 大部分扩展无法直接在线安装。
2. 运行时的node版本和构建时的node版本不同的话可能会出问题

### !! 无法预览网页，markdown

可以运行的情况：

1. 在本地主机打开。
2. 启用https(目前code-server 4.11版无法和openssl配合)
3. chrome浏览器里打开 chrome://flags/#unsafely-treat-insecure-origin-as-secure
    这里可以添加多个允许运行的网站，
    - 使用http 而非 <https://>
    - 例如：
    - <http://192.168.1.100:8080>
    - <http://192.168.1.100:8888>

### 修改配置使用扩展商店地址

！！注意这是违反了微软的用户使用协议  
！！目前openvscode-server不支持修改  
code-server可以通过修改product.json  
找不到这个文件？`find [程序目录] -name product.json`

```json
"extensionsGallery": {
    "serviceUrl": "https://marketplace.visualstudio.com/_apis/public/gallery",
    "itemUrl": "https://marketplace.visualstudio.com/items"
}
```

### openvscode-server无法安装语言包

目前openvscode-server 1.77.1版本无法安装语言包

### 运行太卡顿？

- code-server/openvscode-server自身对性能要求不高，但浏览器压力比较大，你可以试试在使用<https://vscode.dev> 看看会不会卡顿。
- 如果你的code-server跑在一台性能较弱的机器里，但使用性能较强的机器的浏览器打开，体验会好一点，不过现在的中高端手机都能流畅运行吧。

### termux上全局搜索不能用？

安装一下ripgrep  
`apt install ripgrep`

## 推荐配置

这是我的用户配置可以参考一下,主要是方便终端的使用

```json
{
    "workbench.startupEditor": "none",
    "workbench.colorTheme": "Default Dark+",
    "terminal.integrated.allowChords": false,
    "terminal.integrated.commandsToSkipShell": [
        "-workbench.action.quickOpenView",
        "-workbench.action.quickOpen"
    ],
    "shellcheck.customArgs": [
        "-x"
    ],
    "[xml]": {
        "editor.defaultFormatter": "DotJoshJohnson.xml"
    },
    "shellformat.path": "/data/data/com.termux/files/usr/bin/shfmt",
    "gitlens.plusFeatures.enabled": false,
    "gitlens.showWelcomeOnInstall": false,
    "gitlens.showWhatsNewAfterUpgrades": false,
    "code-runner.clearPreviousOutput": true,
    "workbench.iconTheme": "material-icon-theme",
    "workbench.productIconTheme": "material-product-icons",
}
```

推荐安装的扩展

- DavidAnson.vscode-markdownlint
- DavidWang.ini-for-vscode
- DotJoshJohnson.xml
- eamodio.gitlens
- formulahendry.code-runner
- foxundermoon.shell-format
- jeff-hykin.better-shellscript-syntax
- lkrms.inifmt
- mads-hartmann.bash-ide-vscode
- ms-vscode.live-server
- PKief.material-icon-theme
- PKief.material-product-icons
- redhat.vscode-yaml
