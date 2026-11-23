# Xboard-Node Nowhere 节点扩展

当前节点扩展：**0.15.1**。支持 **Linux x86_64（amd64）＋systemd**。

本仓库提供 Xboard-Node、xbctl、节点端 Nowhere 扩展代理与定制多用户内核，以及对应节点源码。支持同端口多用户独立密钥、用户权限同步、限速、设备限制和流量回传，接入 systemd 与 xbctl 管理。

## 一键安装

复制服务器管理页面生成的安装命令到目标服务器执行，或使用以下形式（替换示例参数）：

```bash
curl -fsSL https://raw.githubusercontent.com/xsllqs/xboard-nowhere-extension/main/install.sh | sudo bash -s -- machine \
  --panel https://panel.example.com \
  --token YOUR_MACHINE_TOKEN \
  --machine-id 123
```

脚本从本仓库下载 Xboard-Node、xbctl 和节点扩展，校验 SHA-256，检查接入认证，自动配置服务及开机自启。无需另外导出扩展凭据。系统依赖使用 apt/dnf/yum；请提前准备节点证书文件。命令包含服务器接入 token，请勿公开。

先检查再安装：

```bash
curl -fL https://raw.githubusercontent.com/xsllqs/xboard-nowhere-extension/main/install.sh -o /root/install-nowhere-extension.sh
bash /root/install-nowhere-extension.sh machine --panel https://panel.example.com --token YOUR_MACHINE_TOKEN --machine-id 123 --check
bash /root/install-nowhere-extension.sh machine --panel https://panel.example.com --token YOUR_MACHINE_TOKEN --machine-id 123
```

`--check` 只下载校验并检查认证，不修改服务和配置。

## 已安装节点升级

先重新下载最新脚本，然后执行：

```bash
bash /root/install-nowhere-extension.sh machine --check
bash /root/install-nowhere-extension.sh machine
```

脚本读取已保存的服务器接入参数。只安装或升级节点 Nowhere 扩展可使用 `node` 模式：

```bash
bash /root/install-nowhere-extension.sh node --check
bash /root/install-nowhere-extension.sh node
```

首次单独安装扩展时需附带 `--panel`、`--machine-id` 和 `--secret-file`。主程序与扩展安装器分别备份原文件，保留实时计量状态。官方 `xbctl upgrade` 沿用其上游升级逻辑；要使用本仓库固定版本，请运行仓库脚本的 `machine` 模式。

## 管理命令

```bash
xbctl status
xbctl nowhere status
xbctl nowhere logs
xbctl nowhere restart
```

## 下载及源码

| 内容 | 下载 | 校验 |
|---|---|---|
| Nowhere 节点扩展 0.15.1 | [节点包](https://raw.githubusercontent.com/xsllqs/xboard-nowhere-extension/refs/tags/v0.15.1/packages/node-nowhere/0.15.1/xboard-node-nowhere-extension-0.15.1.tar.gz) | [SHA256SUMS](packages/node-nowhere/0.15.1/SHA256SUMS) |
| Xboard-Node + xbctl | [Linux amd64 包](https://raw.githubusercontent.com/xsllqs/xboard-nowhere-extension/refs/tags/v0.15.1/packages/xboard-node/0a29338e-go1.26.11/xboard-node-0a29338e-go1.26.11-linux-amd64.tar.gz) | [SHA256SUMS](packages/xboard-node/0a29338e-go1.26.11/SHA256SUMS) |
| Xboard-Node 对应源码 | [源码归档](https://raw.githubusercontent.com/xsllqs/xboard-nowhere-extension/refs/tags/v0.15.1/packages/xboard-node/0a29338e-go1.26.11/xboard-node-source.tar.gz) | [构建信息](packages/xboard-node/0a29338e-go1.26.11/build.json) |

Xboard-Node 保持上游提交 `0a29338e1f102a462363ce3527417029f89bab28` 的代码，使用 Go **1.26.11** 构建。节点扩展包内 `sources/` 提供 Nowhere 内核与代理对应源码。各组件保留其许可证，Nowhere 内核采用 GPL-3.0-only。[当前版本信息](latest.json)。
