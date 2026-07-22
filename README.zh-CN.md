<p align="center">
  <img src="docs/assets/social-preview.png" alt="VividBrightness - macOS XDR 亮度增强工具" width="100%">
</p>

<h1 align="center">VividBrightness</h1>

<p align="center"><strong>开源的 macOS XDR/EDR 屏幕亮度增强工具。</strong></p>

<p align="center">
  <a href="https://github.com/cold-summer/VividBrightness/releases/latest"><img alt="最新版本" src="https://img.shields.io/github/v/release/cold-summer/VividBrightness?sort=semver"></a>
  <a href="https://github.com/cold-summer/VividBrightness/actions/workflows/ci.yml"><img alt="CI 状态" src="https://github.com/cold-summer/VividBrightness/actions/workflows/ci.yml/badge.svg"></a>
  <img alt="支持 macOS 13 或更高版本" src="https://img.shields.io/badge/macOS-13%2B-111111?logo=apple">
  <a href="LICENSE"><img alt="MIT License" src="https://img.shields.io/badge/license-MIT-2f855a"></a>
</p>

<p align="center">
  <a href="https://github.com/cold-summer/VividBrightness/releases/latest"><strong>下载最新版 DMG</strong></a>
  ·
  <a href="README.md">English</a>
</p>

VividBrightness 是一个原生 macOS 菜单栏 App，用于提升兼容 XDR/EDR 屏幕的实际光输出。它通过 Apple 扩展动态范围合成管线和 16-bit 浮点 Metal 覆盖层，为 MacBook Pro Liquid Retina XDR 及其他受支持显示器提供最高 2.0x 的亮度增强，不修改显示器 Gamma 曲线。

<p align="center">
  <img src="docs/assets/app-window.png" alt="VividBrightness 菜单栏 XDR 亮度控制与预设档位" width="360">
</p>

## 为什么选择 VividBrightness？

- **真实 XDR/EDR 光输出：**使用显示器亮度余量，而不是通过修改 Gamma 让画面看起来更亮。
- **精确控制：**支持 1.0x 到 2.0x 连续调节，以及 +25%、+50%、+75% 和 +100% 预设。
- **原生轻量：**基于 AppKit 和 Metal，仅驻留菜单栏，不包含分析、遥测和网络请求。
- **自动识别显示器：**只对向 macOS 提供 EDR 余量的屏幕生效。
- **可靠的状态管理：**系统唤醒后自动恢复，关闭功能或退出 App 时立即移除覆盖层。

## 兼容性

| 要求 | 支持情况 |
| --- | --- |
| macOS | macOS 13.0 或更高版本 |
| Release 二进制 | Apple Silicon (`arm64`) |
| 内置显示器 | 配备 Liquid Retina XDR 的 MacBook Pro |
| 外接显示器 | Pro Display XDR，以及向 macOS 提供 EDR 余量的显示器 |
| 普通 SDR 显示器 | 可以识别，但不会修改 |

需要支持 Metal 的 Mac。实际可用亮度由 macOS 和显示器共同决定，App 无法让不支持 EDR 的硬件获得额外亮度余量。

## 下载与安装

1. 从 [GitHub 最新 Release](https://github.com/cold-summer/VividBrightness/releases/latest) 下载 Apple Silicon 版 `.dmg`。
2. 打开 DMG，将 `VividBrightness.app` 拖入 Applications 文件夹。
3. 当前二进制使用临时签名，未经 Apple 公证，因此需要在“终端”执行一次：

```bash
xattr -dr com.apple.quarantine /Applications/VividBrightness.app
open /Applications/VividBrightness.app
```

Release 中同时提供 ZIP 备用版本和 SHA-256 校验文件。校验下载内容：

```bash
shasum -a 256 -c VividBrightness-v1.0.0-macOS-arm64.dmg.sha256
```

## 实现原理

VividBrightness 使用 `RGBA16Float` 和 extended-linear Display P3 创建支持 EDR 的 Metal 表面，再通过可穿透点击的全屏窗口进行乘法合成，使超过 SDR 白点的像素使用由 macOS 管理的 XDR 亮度余量。

这是 XDR/EDR 亮度增强，不是对比度滤镜或软件 Gamma 调整。渲染管线、生命周期和系统限制参见[架构说明](docs/ARCHITECTURE.md)。

## 从源码构建

安装 Xcode Command Line Tools 后执行：

```bash
git clone https://github.com/cold-summer/VividBrightness.git
cd VividBrightness
make check
make build
open .build/VividBrightness.app
```

无需修改仓库文件即可覆盖构建信息：

```bash
BUNDLE_IDENTIFIER=io.github.example.VividBrightness \
MARKETING_VERSION=1.0.0 \
BUILD_NUMBER=1 \
SIGN_IDENTITY="Developer ID Application: Example" \
make build
```

## 真机测试

真实 EDR 集成测试必须在已解锁且连接兼容 XDR/EDR 显示器的 Mac 上运行：

```bash
make test-edr
```

如需在不开启覆盖层的情况下查看当前和理论 EDR 余量：

```bash
make diagnose
```

## 限制与安全提示

- 锁屏、电池供电或设备温度过高时，macOS 可能降低 EDR 余量。
- 长时间高亮会增加功耗和屏幕温度；长期使用建议选择 +25% 或 +50%。
- EDR 余量代表系统容量，不是用户选择的增强倍数。
- 某些系统中，全局快捷键 `Command + Shift + B` 可能需要“输入监控”权限；菜单栏控制不依赖该权限。

## 参与贡献

提交 Pull Request 前请阅读 [CONTRIBUTING.md](CONTRIBUTING.md)。安全问题请按照 [SECURITY.md](SECURITY.md) 私下报告，不要提交公开 Issue。

VividBrightness 使用 [MIT License](LICENSE) 开源。
