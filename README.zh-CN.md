# VividBrightness

[English](README.md)

VividBrightness 是一个原生 macOS 菜单栏工具，通过 macOS 扩展动态范围合成管线提高兼容 XDR/EDR 显示器的实际光输出。它使用 16-bit 浮点 Metal 覆盖层，不修改显示器 Gamma 曲线。

## 功能

- 1.0x 到 2.0x 连续亮度增强
- +25%、+50%、+75% 和 +100% 四档预设
- 自动识别兼容的 XDR/EDR 显示器
- 使用 `Command + Shift + B` 全局快捷键逐级增加亮度
- 系统唤醒后自动恢复已启用的增强
- 关闭功能或退出 App 时立即移除覆盖层
- 仅驻留菜单栏，不显示 Dock 图标

## 环境要求

- macOS 13.0 或更高版本
- Xcode Command Line Tools
- 支持 Metal 的 Mac
- Liquid Retina XDR、Pro Display XDR，或其他向 macOS 提供 EDR 余量的显示器

普通 SDR 显示器可以被识别，但不会被修改。

## 构建

```bash
cd VividBrightness
make check
make build
open .build/VividBrightness.app
```

`make check` 可以在 GitHub 托管的 macOS Runner 上运行。它会检查 Shell 脚本和属性列表、构建并临时签名 App，以及编译 EDR 诊断工具。

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

测试会创建与正式 App 相同的 Metal 覆盖层，确认渲染帧持续输出，并要求 macOS 报告大于 `1.05` 的 EDR 余量。

如需在不开启覆盖层的情况下查看当前和理论 EDR 数值：

```bash
make diagnose
```

## 实现原理

VividBrightness 使用 `RGBA16Float` 和 extended-linear Display P3 创建支持 EDR 的 Metal 表面，再通过可穿透点击的全屏窗口进行乘法合成，使超过 SDR 白点的像素使用由 macOS 管理的 XDR 亮度余量。

详细设计与系统限制参见[架构说明](docs/ARCHITECTURE.md)。

## 限制与安全提示

- 锁屏、电池供电或设备温度过高时，macOS 可能降低 EDR 余量。
- 长时间高亮会增加功耗和屏幕温度。
- 界面曾显示的 EDR 余量代表系统容量，不是用户选择的增强倍数。
- 长时间使用建议选择 +25% 或 +50% 等较保守档位。
- 某些 macOS 配置下，全局快捷键可能需要“输入监控”权限；菜单栏操作不依赖该权限。

## 隐私

VividBrightness 不发起网络请求，不包含分析或遥测功能。App 只会在 macOS 用户默认值中保存用户选择的增强档位。

## 参与贡献

提交 Pull Request 前请阅读 [CONTRIBUTING.md](CONTRIBUTING.md)。安全问题请按照 [SECURITY.md](SECURITY.md) 私下报告，不要提交公开 Issue。

## 许可证

VividBrightness 使用 [MIT License](LICENSE) 开源。
