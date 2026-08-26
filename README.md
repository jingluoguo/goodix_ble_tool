# Goodix Lab

一个面向 Goodix GUS 温度手环的 BLE 联调工作台。应用使用 Flutter 构建，覆盖从扫描、连接、服务发现到 GUS UART 协议收发、实时温度和历史温度导出的完整流程。

[中文](README.md) · [English](README.en.md)

## 中文

### 功能

- 扫描名称包含 `Goodix_GUS` 或广播中带有 GUS 服务 UUID 的设备
- 连接设备并自动发现服务、订阅 TX Notify、协商 MTU（目标 247）
- 查询和同步设备时间、软件版本、硬件版本、电量、充电状态
- 开启实时温度通知，并显示有效性和摄氏温度
- 查询历史容量，读取全部历史或未上传历史
- 校验历史数据分包顺序，合并记录并按设备时间倒序展示
- 通过 TXT 文件分享或保存温度历史
- 提供 TX、RX、SYS 三类联调日志和错误状态

### 界面预览

| 首页 | 扫描设备 | 设备控制台 |
| :---: | :---: | :---: |
| ![首页预览](doc/home_page.png) | ![扫描预览](doc/scan_page.png) | ![设备信息预览](doc/device_info.png) |

### 环境要求

- Flutter SDK，Dart SDK `^3.11.5`
- Android、iOS、macOS、Windows 或 Linux 蓝牙运行环境
- 真实 BLE 设备进行联调时，需要打开系统蓝牙并授予应用蓝牙权限

检查 Flutter 环境：

```bash
flutter doctor
```

### 快速开始

```bash
git clone <repository-url>
cd goodix_ble_tool
flutter pub get
flutter run
```

查看可用设备并选择运行目标：

```bash
flutter devices
flutter run -d <device-id>
```

构建示例：

```bash
flutter build apk       # Android
flutter build ios       # iOS（需要 macOS 与 Xcode）
flutter build macos     # macOS
flutter build windows   # Windows
flutter build linux     # Linux
```

### 使用流程

1. 开启系统蓝牙，进入首页点击“扫描”。
2. 选择 `Goodix_GUS` 设备，等待服务发现和 TX Notify 订阅完成。
3. 在“设备控制台”执行版本、电量、充电状态和时间查询。
4. 点击“开启温度”接收实时温度；在“温度历史”中读取全部或未上传记录。
5. 需要留档时，使用分享或保存按钮导出 TXT 文件。

### GUS BLE 协议

| 项目 | UUID / 值 |
| --- | --- |
| Service | `A6ED0201-D344-460A-8075-B9E8EC90D71B` |
| TX（设备通知） | `A6ED0202-D344-460A-8075-B9E8EC90D71B` |
| RX（应用写入） | `A6ED0203-D344-460A-8075-B9E8EC90D71B` |
| Flow | `A6ED0204-D344-460A-8075-B9E8EC90D71B` |
| 本地数据命令 | `0x36` |

基础帧格式为：

```text
[0x00, frameId, command, subCommand, ...payload]
```

当前实现的主要命令：

| 命令 | 用途 |
| --- | --- |
| `0x11` | 软件版本 / 硬件版本 |
| `0x12` | 电量 / 充电状态 |
| `0x10` | 查询或同步设备时间 |
| `0x34` | 开启实时温度 |
| `0x36 / 0x04` | 查询历史容量 |
| `0x36 / 0x00`、`0x01` | 读取未上传 / 全部历史 |
| `0x36 / 0x02` | 停止历史上传 |

协议帧构造、解析和状态码说明集中在 [`lib/services/gus_protocol.dart`](lib/services/gus_protocol.dart)。BLE 连接、扫描和通知处理集中在 [`lib/controllers/ble_controller.dart`](lib/controllers/ble_controller.dart)。

### 项目结构

```text
lib/
├── controllers/       BLE 状态与业务流程
├── core/              主题和全局样式
├── models/            设备、温度和日志模型
├── pages/             首页与设备控制台
├── services/          BLE 封装、GUS 协议、历史导出
└── widgets/           可复用界面组件
doc/                   README 界面预览图
```

### 注意事项

- Android 12 及以上需要授予附近设备权限；较低版本通常还需要定位权限。
- iOS、macOS 和 Windows 的蓝牙权限由各平台工程配置控制，首次运行时请允许访问。
- Web 端不作为本项目的主要 BLE 运行目标；如需 Web 支持，需要额外适配浏览器 Web Bluetooth 能力。
- 历史读取依赖设备端分包协议；应用会检查首包、末包和分包序号，异常数据会记录在联调日志中。
