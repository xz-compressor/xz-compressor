# XZ 极速压缩工具 正式版 1.0

一款以 **xz 极限压缩**为主、覆盖 **Windows CMD / 自解压 EXE / 安卓 APK / 鸿蒙（降级方案）/ HTML 浏览器** 五端的压缩工具。当前版本（正式版 1.0，v15）在历史版本基础上补齐了：**三档压缩、多格式（gz/bzip2/tgz/tar.xz）、完整工具集（GUI/右键菜单/定时备份/校验/预设/自检等）、原生 XZ Utils 真格式、安卓端全功能对齐（AES-256 zip / tar.xz / gz / bz2 / 压缩包管理器）、单文件 HTML 浏览器端（7z-wasm 内联）、明文多文件安装向导（修改/修复/卸载维护）**，并通过了**无环境离线运行专项验证、APK 安卓 16 真机/模拟器实测、安装器安装/修复/卸载全流程验证**。

## 核心特性（正式版 1.0）

### 压缩
- **三档压缩**（移除旧的 1/5/9，只保留）：**L3 快速 / L6 标准 / L9 极限**，命令行 `--level 3|6|9`；便携版固定 L9
- **格式**：`xz`（极限，单文件/文件夹自动 tar.xz）、`zip`（通用）、`7z`（高压缩率）、`gzip(.gz)`、`bzip2(.bz2)`、`tgz(tar.gz)`
- **高级选项**：分卷压缩 `--volume`、7z 固实 `--solid`、字典大小 `--md`、线程数 `--mmt`
- **压缩文件子菜单**：主菜单 `[1]` → `[1] 压缩文件` / `[2] 压缩文件夹` / `[3] 添加压缩文件`（批量列表：Q 退出、2 添加可多选、3 按序号移除、4 确定）
- **zip / 7z / xz 都能生成 EXE 自解压与 APK 自解压**

### 打开压缩文件（管理器，主菜单 [0]）
对 zip / 7z / xz(tar.xz) / rar / exe / apk 归档：
```
[1] 查看内容列表      [2] 添加文件        [3] 解压文件      [4] 移除文件
[5] 取消加密          [6] 注释(查看/添加/移除) [7] 搜索包内文件
[8] 预览文本文件      [9] 修复 zip 中文文件名乱码       [Q] 返回
```
- 加密包解压/测试需输入正确密码；**错误密码零泄漏**（实测拒绝，不写出任何有效文件）
- xz 单文件流不支持追加/移除，会明确提示并引导先解压

### 多形式加密
- `zip`：传统 ZipCrypto 或 **AES-256**（推荐）
- `7z`：AES-256，可选**头部加密**（`-mhe=on`，文件名也加密）
- `xz`：xz 本身无加密，设密码后自动生成 **AES-256 加密容器**（`xxx.xz.enc.zip`，内含 .xz）；管理器可"取消加密"还原内部 xz
- 设密码时**二次输入确认**，防止设错

### 工具集（主菜单 [2]）
```
[0] 批量加密/改密/去密   [1] 压缩率对比报告    [2] 校验值(MD5/SHA256)
[3] 定时备份(计划任务)    [4] 资源管理器右键菜单  [5] 图形界面 GUI
[6] 历史记录            [7] 压缩预设          [8] 检查更新      [9] 自检
```

### 自解压高级定制（v11）
- 生成 EXE 自解压时可自定义：**标题、欢迎语、许可协议（解压前须同意）、默认目录、解压后自动运行的程序**
- 每次生成 **EXE 必问图标**（`0` 无图标 / `1` .ico / `2` 图片自动转 ico）
- 每次生成 **APK 必问：图标、包名、签名（默认/自定义别名·口令·CN）、安卓版本（用直观版本号 14/15/16，自动映射 API，默认 16）**

### 安卓完整版（XZ完整压缩.apk）—— 功能对齐 Windows CMD
主菜单 7 项：①压缩文件 ②解压文件 ③打开压缩包管理 ④测试完整性 ⑤选解压目录 ⑥解出内置工具库 ⑦关于/开源许可。
- **压缩（写）**：
  - `xz`（单文件，LZMA2 三档 L3/L6/L9，原生 XZ Utils 真格式）
  - `zip`（多文件/文件夹，**AES-256 加密**，zip4j）
  - `7z`（多文件/文件夹，可加密）
  - `tar.xz` / `tar.gz(tgz)`（commons-compress TarArchive）、`gz`、`bz2`
- **解压**：xz / zip / 7z（含密码）/ rar / tar.xz / .txz / tar.gz / .tgz / gz / bz2 / tar
- **压缩包管理器**：打开 zip/7z 列条目（🔒加密标记、zip 注释）、全部解压、追加文件（zip 原生 / 7z 重打包）、删除条目（多选）、zip 注释查看/写入、完整性测试
- **系统分享**（SEND / SEND_MULTIPLE）：从文件管理器多选分享即可压缩
- **SAF 自定义解压目录**：递归创建/写入用户选定的文件夹；MediaStore 同名自动加序号
- 引擎/依赖全部打包进 APK（commons-compress、zip4j、junrar、commons-io、内联 XZ for Java），随取随用；**Android 16 真机/模拟器实测通过**（压缩/解压/管理器/产物可被 PC 端 7-Zip 与 XZ Utils 互认）
- 每次生成 APK 必问：**图标（0 无 / 图片 / .ico）、包名、签名（默认/自定义）、安卓版本（直观版本号 14/15/16，自动映射 API）**；品牌（名称/版本/图标）可与 EXE 同步

### HTML 浏览器版（XZ压缩工具_HTML版.html）—— 单文件、零安装
- **单文件 HTML（约 2.4 MB），7z-wasm 引擎（7zz.wasm）内联 base64，双击即用，无需联网、无需安装任何软件**
- 浏览器内完成 `xz / 7z / zip / tar / gz / bz2` 的压缩与解压、加密、RAR 解压（unRAR 限制），文件不离开本机（File API + WASM，隐私安全）
- 提供 **HTML 便携自解压**：可把压缩包生成成带解压界面的单文件 HTML，对方用任意浏览器打开即可解压
- 支持拖拽、多文件、进度显示；关于页正确署名 7z-wasm 与各开源组件
- 客观限制：受浏览器沙箱限制，成果经"下载"落地，不能直接写任意本地路径；需支持 WASM 的现代浏览器

### 安装程序（XZ压缩工具_安装器.exe）—— 明文多文件 + 安装向导
- 把整套无环境版以**明文**（附 SHA256 校验）随安装向导释放到目标目录；安装时由安装器直接写入对应位置
- **安装向导**：欢迎页、许可协议（可自定义）、选目录、可选桌面/开始菜单快捷方式、进度条
- **已安装后再次运行进入维护模式，三选项**：**修改安装(M) / 修复安装(R) / 卸载程序(U)**
- 写注册表卸载项（DisplayName/版本/图标/卸载与静默卸载字符串），开始菜单生成卸载快捷方式；卸载完整清理文件、快捷方式、注册表
- 支持静默参数：`/S`（静默安装）、`/DIR=目录`、`/uninstall`、`/repair`、`/nodesktop`、`/nostartmenu`
- **安装程序创建器**：可自定义**软件名称、版本号、用户协议、图标**；设置后同步到生成的 **EXE 与 APK** 的名称/版本/图标
- 安装器与主程序**均不主动提示彩蛋**，保留关键词触发，由用户自行发现

### 公告发布服务器端（独立工具，可选）
- 客户端（主脚本 / 安装器）已**移除**「检查公告 / 用户反馈 / 检测更新」入口，离线使用更干净。
- 独立的公告后台在 `server/` 目录：`python server.py 8350` 起服务，管理员登录 `http://服务器:8350/admin` 写公告、查看反馈；接口 `GET /xz/announce`、`POST /xz/feedback`，含 IP 限频防刷。
- 部署到 <your-server> 后，配合隧道 14923 转发即可；详见 `server/部署说明.md`。以后若想恢复客户端公告弹窗，把 `Remote` 类加回安装器、指向该地址即可，接口不变。

### 其它
- **损坏文件修复**（主菜单 [5]）：流程"测试完整性 → 尽力提取 → 重新打包 → 再校验"，**产物校验不通过即判定失败并删除，不保留非法文件**；支持 zip/7z/xz/exe/apk/rar（rar 修复输出 zip）
- **生成后自动打开文件夹**：每次生成产物（HTML 完整版 / HTML 便携自解压 / 安卓 APK / Windows EXE / 安装器 / 鸿蒙工程模板）完成后，自动用文件资源管理器打开目标文件夹并选中产物，方便直接取用
- **所需工具下载**（主菜单 [4]）：显示引擎状态、打开 7-Zip 官网、一键下载安装
- **全对话框选路径**：取文件/文件夹/图标/许可/目录/修复对象一律弹出文件资源管理器，不再手输
- **完整错误提示 + 自动日志**（同目录 `xz-compressor.log`）；中文路径乱码免疫（`chcp 936`）

---

## 无环境运行（未装 7-Zip 的电脑也能用）

桌面 **`XZ压缩工具_无环境版`** 目录（安装器的打包源，约 294 个文件 / 17 MB）：

| 文件 / 目录 | 定位 | 说明 |
|---|---|---|
| `xz-compressor.cmd` | Windows 主脚本（CMD 完整版） | 覆盖全部功能；自带 `7z.exe/7z.dll/7z.sfx` 与原生 `tools\xz\`，双击即用，不依赖系统 7-Zip |
| `XZ完整版.exe` | Windows 完整版 | 免安装，内置 7z 引擎、GUI、安卓模板、各构建脚本 |
| `XZ完整压缩.apk` | 安卓完整版 | 安卓端完整压缩/解压，依赖打包进 APK |
| `XZ压缩工具_HTML版.html` | 浏览器版 | 单文件，7z-wasm 内联，任意现代浏览器离线即用 |
| `XZ压缩工具_安装器.exe` | 安装程序 | 明文多文件 + 安装向导，安装/修复/卸载 |
| `tools\`、`android\`、`android_full\` | 引擎与工程 | 自带 7-Zip、原生 XZ Utils、HTML 生产文件、安卓工程与默认签名 |

> 已专项验证：在**最小 PATH（仅 System32）**的干净环境下，主脚本自动调用同目录 / `tools\xz\` 自带引擎，xz 压缩成功（实测 222KB→212B，退出码 0）；zip/7z/gz/bz2 压缩、头部加密、xz 加密容器、错误密码拒绝、加密文件解压、修复判定均通过；完整版 EXE 释放后实际压缩往返一致；安装器静默安装→修复→卸载全流程干净。

> RAR 压缩已移除（仅保留 .rar 解压/修复）。

---

## 快速开始

**方式一（推荐）：拖放** — 把文件/文件夹拖到 `xz-compressor.cmd` 图标上，自动进入压缩流程。

**方式二：菜单** — 双击 `xz-compressor.cmd` 或"启动压缩工具.bat"：
```
[0] 打开压缩文件  （列表/搜索/预览/添加/解压/移除/注释/加解密）
[1] 压缩文件      （文件 / 文件夹 / 批量添加 · xz/zip/7z/gz/bz2）
[2] 工具集        （批量加密/对比/校验/定时备份/右键菜单/GUI/历史/预设/更新/自检）
[3] 创建便携程序/安装器（HTML完整版 · HTML便携自解压 · 安卓完整版 · Windows完整版 · 安装器 · 鸿蒙）
[4] 所需工具下载  （引擎状态 / 官网 / 一键安装）
[5] 修复损坏文件  （zip/7z/xz/exe/apk/rar）
[Q] 退出
```

**方式三：命令行（CLI，含 `--` 进入自动模式）**
```cmd
xz-compressor.cmd 数据.txt --format xz --level 9 --yes
xz-compressor.cmd 目录   --format 7z --level 9 --pass 密码 --solid --volume 100m --yes
xz-compressor.cmd a.txt  --format zip --level 6 --sfx exe --yes
xz-compressor.cmd --help
```
参数：`--format xz|zip|7z|gz|bz2|tgz` `--level 3|6|9` `--pass 密码` `--volume 大小` `--solid` `--md 字典` `--mmt 线程` `--sfx none|exe|apk` `--out 路径` `--yes`(自动覆盖) `--beep` `--sha256`。

---

## 技术说明

- **引擎**：7-Zip（xz/zip/7z/gz/bz2 及自解压、APK 打包）；系统 tar 打包文件夹为 tar.xz/tgz；zip 加密 `-mem=AES256`，7z 头部加密 `-mhe=on`
- **EXE 自解压**：无密码走体积小的 7z.sfx；加密/带图标走 .NET（csc）通用壳支持密码；高级定制由 `tools\makesfxcfg.ps1` 生成配置
- **GUI**：C# WinForms（`tools\XZGui.exe`），内嵌 7z 引擎；`--selftest`（系统引擎）/ `--selftest-embedded`（强制释放内嵌引擎）
- **APK 构建**：Android SDK（aapt2/d8/zipalign/apksigner）+ JDK；完整版含 commons-compress、zip4j、junrar、commons-io 与内联 org.tukaani.xz
- **客观限制**：7-Zip 官方命令行不支持密钥文件(keyfile)；7z 无 RAR 式恢复记录（`--rr` 已提示忽略）；iOS/macOS 自解压与多语言界面暂不支持
- **自动日志**：同目录 `xz-compressor.log`

### 版本历史
- v8：全对话框选路径、APK 按安卓版本号、移除 APK 便携版
- v9：加密文件解压（zip/7z，含安卓端）
- v10：压缩包管理器；zip/7z/xz 全支持 EXE/APK 自解压；多项加密/注释/列表缺陷修复
- **v11（正式版 1.0）**：三档压缩（L3/6/9）、gz/bz2/tgz、分卷/固实/字典/线程、完整工具集、GUI、自解压高级定制（标题/欢迎语/EULA/默认目录/解压后运行）、安卓 7z/xz 压缩写+系统分享+SAF 自定义解压、无环境离线专项验证、修复 `--yes` 不自动覆盖等缺陷
- v12：修复空参数闪退与 7-Zip 已安装却误报；多文件安装向导；压缩/解压进度条；隐藏彩蛋
- v13：安装器图标 + 修改/修复/卸载维护模式 + 注册表卸载项；修复自检 6 项全失败与菜单乱码
- v14：单文件 HTML 浏览器端（7z-wasm 内联）；安卓端全功能对齐 CMD（AES-256 zip / tar.xz / gz / bz2 / 压缩包管理器 / SAF）；安装器全流程实测；版权合规复核（THIRD-PARTY-LICENSES）
- **正式版 1.0（v16）**：修复维护模式“修改安装”嵌套消息循环崩溃；全局版本统一为正式版 1.0；EXE/APK 默认使用 xz.ico 图标；压缩完成后自动在资源管理器定位输出文件并清理临时中间文件；远程更新公告与用户反馈（隧道 14923→公网 8350，本地限频防刷，反馈表单引导写清步骤/现象/期望）。
- v14：原生 XZ Utils 集成（.xz 为标准 XZ 格式，不再是 7z 套皮）；安装程序创建器（自定义名称/版本/协议/图标）；鸿蒙菜单与 HarmonyOS NEXT 工程模板；工具下载增加鸿蒙入口
- **v15（正式版 1.0）**：
  - 新增**单文件 HTML 浏览器版**（7z-wasm 内联，零安装、离线、隐私不出本机）与 **HTML 便携自解压**；移除 Windows/安卓便携版生成入口
  - **安卓完整版全功能对齐 Windows CMD**：zip 升级 AES-256、新增 tar.xz/tgz/gz/bz2 压缩、压缩包管理器（追加/删除/注释/测试/加密标记）、SAF 自定义目录
  - 安装器完善：**修改/修复/卸载维护模式**、图标、静默安装/修复/卸载、注册表卸载项与完整清理；安装器与主程序均不再主动提示彩蛋（保留关键词触发）
  - 安装程序创建器的**名称/版本/图标同步到 APK 与 EXE**；APK 生成询问直观安卓版本（14/15/16 映射 API）
  - 版权合规复核：补全 XZ Utils MinGW 运行时、Java 库、7z-wasm、unRAR 等许可证与 `THIRD-PARTY-LICENSES.md`
  - 桌面**无环境版**随主程序同步；修复闪退、7-Zip 误报、自检失败、菜单乱码、压缩/解压进度条等缺陷
  - **安装器维护模式「修改安装(M)」崩溃修复**（原 `.NET InvalidOperationException: 在单个线程上开始另一个消息循环`）：改用 `Form.ShowDialog()` 启动修改安装向导，不再嵌套 `Application.Run`
  - **新增远程更新公告 + 用户反馈**（主菜单 [6] 与安装器维护模式双入口，公网 `<your-server>:<port>`，含请求体上限/IP 限流/客户端限频等防滥用措施）
  - **生成文件后自动打开目标文件夹**（HTML/APK/EXE/安装器/鸿蒙模板，`explorer /select` 选中产物）

## 开源许可与版权署名

本工具是批处理 / PowerShell / C# / Java / HTML+WASM 编排程序，自身按“现状”提供；压缩、解压与打包能力来自下列开源组件，版权归原作者所有，并遵守其各自许可。**完整声明见独立文件 [`THIRD-PARTY-LICENSES.md`](THIRD-PARTY-LICENSES.md)。**

> **自有代码许可：PolyForm Noncommercial License 1.0.0**（见 [`LICENSE`](LICENSE)）。个人学习、研究、业余及非商业组织可免费使用；任何商业用途（出售、随商业产品分发、营利组织内部使用等）须取得作者书面授权。下列第三方组件仍按其各自原许可授权，不受本非商业条款限制。

| 组件 | 用途 | 许可证 |
|---|---|---|
| XZ Utils 5.8.4（xz.exe、xzdec.exe、liblzma.dll） | 原生 `.xz` 压缩 / 解压（标准 XZ，非 7z 套皮） | Windows 二进制相关部分为 **0BSD**；静态链接 MinGW-w64 运行时 |
| MinGW-w64 运行时 | XZ 二进制依赖 | MinGW-w64 运行时许可（ISC/BSD 类，GPL 兼容），二进制分发须保留声明 |
| 7-Zip 24.09（7z.exe、7z.dll、7z.sfx） | 7z / zip / gz / bz2 / tar、自解压、APK 打包 | **LGPL v2.1+**（部分 BSD 3-Clause） |
| libarchive / bsdtar（系统 tar.exe） | tar 打包、tar.xz / tgz | BSD 2-Clause |
| 7z-wasm 1.2.0（7zz.wasm / 7zz.es6.js） | HTML 浏览器端全部压缩解压（xz/7z/zip/gz/bz2/tar/加密/RAR 解压） | **LGPL + unRAR 限制** |
| Apache Commons Compress 1.26.0 | 安卓 tar/xz/7z 处理 | Apache License 2.0 |
| Apache Commons IO 2.16.1 | 安卓文件 / 流工具 | Apache License 2.0 |
| Zip4j 2.11.5 | 安卓 ZIP 读写与 AES 加密 | Apache License 2.0 |
| junrar（com.github.junrar） | 安卓 RAR 解压 | UnRAR License（仅解压，禁止重建 RAR 算法） |

- 许可证文本随程序附带：`tools/xz/COPYING.txt`、`COPYING.0BSD.txt`、`COPYING.MinGW-w64-runtime.txt`、`AUTHORS.txt`；`tools/html/7zwasm_License.txt`、`unRarLicense.txt`；`android_full/lib/licenses/`（含 Apache、Zip4j、junrar 的 LICENSE/NOTICE）。
- 安装器默认用户协议（EULA）包含以上开源署名；在“创建安装程序”里可自定义协议文本，但分发时仍应保留署名。
- 若分发本工具（尤其无环境版已内置 7z / xz 二进制、HTML 版已内联 7z-wasm、APK 已打包 Java 库），请保留这些许可证文件与版权声明。
- 鸿蒙 HarmonyOS NEXT 工程模板（`tools/hm_template.ps1` 生成）为示例脚手架，系统 `@ohos.zlib` 仅支持 zip/gz；如需在 NEXT 上支持 `.xz/.7z`，需自行交叉编译 liblzma / 7-Zip SDK 并通过 NAPI 封装。
- RAR 仅支持解压，不提供压缩（WinRAR/RAR 为专有格式与算法；junrar 与 unRAR 许可均禁止重建 RAR 压缩算法）。

## 免责声明

- 本软件免费提供，压缩、加密、修复前请自行备份重要数据；因使用本软件造成的数据损失，由使用者自行承担。
- 请妥善保管压缩密码，密码丢失将无法恢复加密内容。
