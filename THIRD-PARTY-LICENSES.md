# 第三方组件与开源许可声明

XZ 极速压缩工具（早期测试版 0.1）是批处理 / PowerShell / C# / Java / HTML+WASM 编排程序，自身脚本与源码按“现状（AS IS）”提供。压缩、解压与打包能力来自下列开源组件，版权归各自原作者所有，并遵守其各自许可证。

**分发时请保留本文件及各组件附带的许可证文本。**

---

## 一、Windows / CMD 端

| 组件 | 版本 | 用途 | 许可证 | 许可证文件 |
|---|---|---|---|---|
| XZ Utils（xz.exe、xzdec.exe、liblzma.dll） | 5.8.4 | 原生 `.xz` 单文件压缩 / 解压（标准 XZ 格式，非 7z 套皮） | Windows 二进制相关部分为 **0BSD**（BSD Zero Clause）；MinGW-w64 构建静态链接运行时 | `tools\xz\COPYING.0BSD.txt`、`tools\xz\COPYING.txt`、`tools\xz\AUTHORS.txt` |
| MinGW-w64 运行时 | — | XZ Utils Windows 二进制静态链接的 C 运行时 | MinGW-w64 运行时许可（ISC/BSD 类，FSF 认证 GPL 兼容），**二进制分发必须保留其声明** | `tools\xz\COPYING.MinGW-w64-runtime.txt` |
| 7-Zip（7z.exe、7z.dll、7z.sfx） | 24.09 | 7z / zip / gz / bzip2 / tar、自解压、APK 打包 | **GNU LGPL v2.1 或更高**（部分代码为 BSD 3-Clause） | 见 7-Zip 安装目录 `License.txt`，及 7-Zip 官网 https://www.7-zip.org/ |
| libarchive / bsdtar（Windows 自带 tar.exe） | 系统自带 | 文件夹打包为 tar.xz / tgz | BSD 2-Clause | https://libarchive.org/ |

> 说明：XZ Utils 的 Windows 官方二进制包明确声明“与本二进制包相关的源码部分采用 0BSD”，且使用 MinGW-w64 构建时未使用 GNU getopt_long，因此 **LGPL v2.1 不适用于该二进制**；但分发时必须附带 MinGW-w64 运行时许可证（`COPYING.MinGW-w64-runtime.txt`）。

## 二、HTML / 浏览器端

| 组件 | 版本 | 用途 | 许可证 | 许可证文件 |
|---|---|---|---|---|
| 7z-wasm（7zz.es6.js、7zz.wasm，由 7-Zip 24.09 经 Emscripten 编译） | 1.2.0 | 浏览器本地 xz/7z/zip/gz/bz2/tar 压缩解压、加密、RAR 解压 | **GNU LGPL + unRAR restriction**（须同时遵守 LGPL 与 unRAR 限制） | `tools\html\7zwasm_License.txt`、`tools\html\unRarLicense.txt` |

- HTML 版所有运算在浏览器本地完成，文件不上传服务器。
- 7z-wasm 中 RAR 解压器使用了 unRAR 源码，**不得用于重建 RAR 压缩算法**；本工具仅支持 `.rar` 解压，不提供 RAR 压缩。
- 项目主页：https://github.com/nicolo-ribaudo/7z-wasm （npm 包 `7z-wasm`）。

## 三、安卓端（完整版 APK，打包进 assets）

| 组件 | 版本 | 用途 | 许可证 | 许可证文件 |
|---|---|---|---|---|
| Apache Commons Compress | 1.26.0 | tar/xz/7z 等归档与压缩 | **Apache License 2.0** | `android_full\lib\licenses\commons-compress.license.txt`、`.notice.txt` |
| Apache Commons IO | 2.16.1 | 文件 / 流工具 | **Apache License 2.0** | `android_full\lib\licenses\commons-io.license.txt`、`.notice.txt` |
| Zip4j | 2.11.5 | ZIP 读写与 AES 加密 | **Apache License 2.0**（1.0 起所有版本均为 Apache 2.0） | `android_full\lib\licenses\zip4j.license.txt` |
| junrar（com.github.junrar） | — | RAR 归档解压 | **UnRAR License**（Alexander Roshal）：可免费用于处理 RAR 归档，**不得用于重建 RAR 压缩算法** | `android_full\lib\licenses\junrar.unrar-license.txt` |

> 安卓完整版仅做 `.rar` 解压，不实现 RAR 压缩，符合 UnRAR 许可。上述 jar 内的 Apache LICENSE/NOTICE 文本随 APK 一并打包。

## 四、自有代码

- 主脚本 `xz-compressor.cmd`、`tools\*.ps1`、`tools\*.py`、C# 启动器与 GUI（`tools\XZGui.cs` 等）、安装器（`tools\obf_installer.cs`、`obf_pack.ps1`）、安卓工程 Java 源码（`android_full\src`、`android\src`）、鸿蒙工程模板生成器（`tools\hm_template.ps1`）、HTML 界面（`tools\html\app_template.html`，不含 7z-wasm 引擎）均为本工具原创编排代码，按“现状”免费提供。

## 五、合规要点（分发须知）

1. **7-Zip（LGPL）**：可商业使用、可随软件分发；如修改其本身需按 LGPL 公开对 7-Zip 的修改。本工具以独立可执行文件 / 原样 DLL 形式调用，未修改 7-Zip。
2. **7z-wasm（LGPL + unRAR）**：HTML 单文件已内联 7z-wasm 引擎，LGPL 允许以聚合形式分发；须保留其许可证署名（已在 HTML“关于”页与本文件保留）。7z-wasm 为未修改的官方构建产物，其“可获取完整对应源码”的途径为 npm 包 `7z-wasm` 与 7-Zip 官网。
3. **XZ Utils（0BSD）**：极宽松，几乎无限制；但 MinGW-w64 运行时要求二进制分发保留其版权许可声明（已随 `tools\xz\` 附带）。
4. **Apache 2.0（Commons / Zip4j）**：可自由使用、修改、分发（含商业），须保留 LICENSE/NOTICE 与版权声明（已随 APK 打包）。
5. **junrar / unRAR**：可免费分发与用于 RAR 解压，但**严禁用于开发 RAR/WinRAR 兼容压缩器或重建 RAR 压缩算法**。本工具不提供 RAR 压缩功能（菜单中已移除 RAR 压缩）。
6. **RAR 压缩已明确移除**：本工具不创建 `.rar` 文件，仅支持解压既有 `.rar`。

## 六、免责声明

本工具及第三方组件均按“现状”提供，不附带任何明示或默示担保。在任何情况下，作者均不对因使用或无法使用本工具造成的数据丢失、损坏、利润损失或其他损失负责。请在压缩重要数据前自行备份、并在压缩后校验完整性。
