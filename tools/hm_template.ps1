# hm_template.ps1 -- 在桌面生成纯血鸿蒙 HarmonyOS NEXT 压缩工具工程模板（Stage 模型 / API 12）
# 说明：NEXT 不支持 APK，需用 DevEco Studio 打开本模板后补全资源并签名。
$ErrorActionPreference = "Stop"
$desktop = [Environment]::GetFolderPath("Desktop")
$root = Join-Path $desktop "鸿蒙压缩工具_工程模板"
if (Test-Path $root) { Remove-Item $root -Recurse -Force }
$dirs = @(
  "AppScope\resources\base\media",
  "AppScope\resources\base\element",
  "entry\src\main\ets\entryability",
  "entry\src\main\ets\pages",
  "entry\src\main\resources\base\media",
  "entry\src\main\resources\base\element",
  "entry\src\main\resources\zh_CN\element"
)
foreach ($d in $dirs) { New-Item -ItemType Directory -Force -Path (Join-Path $root $d) | Out-Null }

$utf8 = New-Object System.Text.UTF8Encoding($false)
function WF($rel, $text) {
  $path = Join-Path $root $rel
  [IO.File]::WriteAllText($path, $text.Replace("`r`n", "`n"), $utf8)
}

WF "build-profile.json5" @'
{
  "app": {
    "signingConfigs": [],
    "products": [
      {
        "name": "default",
        "signingConfig": "default",
        "compatibleSdkVersion": "5.0.0(12)",
        "runtimeOS": "HarmonyOS"
      }
    ],
    "buildModeSet": [ { "name": "debug" }, { "name": "release" } ]
  },
  "modules": [
    { "name": "entry", "srcPath": "./entry", "targets": [ { "name": "default", "applyToProducts": ["default"] } ] }
  ]
}
'@

WF "oh-package.json5" @'
{
  "modelVersion": "5.0.0",
  "name": "xzcompressor_hm",
  "version": "0.1.0",
  "description": "鸿蒙 HarmonyOS NEXT 压缩/解压工具模板",
  "dependencies": {},
  "devDependencies": {
    "@ohos/hypium": "1.0.19"
  }
}
'@

WF "AppScope\app.json5" @'
{
  "app": {
    "bundleName": "com.xzport.hm",
    "vendor": "xzport",
    "versionCode": 1,
    "versionName": "0.1.0",
    "icon": "$media:app_icon",
    "label": "$string:app_name"
  }
}
'@

WF "AppScope\resources\base\element\string.json" @'
{
  "string": [
    { "name": "app_name", "value": "XZ压缩工具" }
  ]
}
'@

WF "entry\build-profile.json5" @'
{
  "apiType": "stageMode",
  "buildOption": {},
  "targets": [
    {
      "name": "default",
      "runtimeOS": "HarmonyOS"
    }
  ]
}
'@

WF "entry\oh-package.json5" @'
{
  "name": "entry",
  "version": "1.0.0",
  "description": "entry module",
  "main": "",
  "author": "",
  "license": "Apache-2.0",
  "dependencies": {}
}
'@

WF "entry\src\main\module.json5" @'
{
  "module": {
    "name": "entry",
    "type": "entry",
    "description": "$string:module_desc",
    "mainElement": "EntryAbility",
    "deviceTypes": ["phone", "tablet"],
    "deliveryWithInstall": true,
    "installationFree": false,
    "pages": "$profile:main_pages",
    "abilities": [
      {
        "name": "EntryAbility",
        "srcEntry": "./ets/entryability/EntryAbility.ets",
        "description": "$string:EntryAbility_desc",
        "icon": "$media:app_icon",
        "label": "$string:EntryAbility_label",
        "startWindowIcon": "$media:app_icon",
        "startWindowBackground": "$color:start_window_background",
        "exported": true,
        "skills": [
          {
            "entities": ["entity.system.home"],
            "actions": ["action.system.home"]
          }
        ]
      }
    ],
    "requestPermissions": [
      { "name": "ohos.permission.READ_MEDIA", "reason": "$string:perm_media", "usedScene": { "abilities": ["EntryAbility"], "when": "inuse" } },
      { "name": "ohos.permission.WRITE_MEDIA", "reason": "$string:perm_media", "usedScene": { "abilities": ["EntryAbility"], "when": "inuse" } }
    ]
  }
}
'@

New-Item -ItemType Directory -Force -Path (Join-Path $root "entry\src\main\resources\base\profile") | Out-Null
WF "entry\src\main\resources\base\profile\main_pages.json" @'
{
  "src": [
    "pages/Index"
  ]
}
'@

WF "entry\src\main\resources\base\element\string.json" @'
{
  "string": [
    { "name": "module_desc", "value": "XZ压缩工具" },
    { "name": "EntryAbility_desc", "value": "XZ压缩工具" },
    { "name": "EntryAbility_label", "value": "XZ压缩工具" },
    { "name": "perm_media", "value": "选择并解压压缩文件" }
  ]
}
'@

WF "entry\src\main\resources\zh_CN\element\color.json" @'
{
  "color": [
    { "name": "start_window_background", "value": "#FFFFFF" }
  ]
}
'@

WF "entry\src\main\resources\base\element\color.json" @'
{
  "color": [
    { "name": "start_window_background", "value": "#FFFFFF" }
  ]
}
'@

WF "entry\src\main\ets\entryability\EntryAbility.ets" @'
import { AbilityConstant, UIAbility, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';

export default class EntryAbility extends UIAbility {
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    hilog.info(0x0000, 'XZ', 'Ability onCreate');
  }
  onDestroy(): void {}
  onWindowStageCreate(windowStage: window.WindowStage): void {
    windowStage.loadContent('pages/Index', (err) => {
      if (err.code) { hilog.error(0x0000, 'XZ', 'loadContent failed: %{public}s', JSON.stringify(err)); }
    });
  }
  onWindowStageDestroy(): void {}
  onForeground(): void {}
  onBackground(): void {}
}
'@

WF "entry\src\main\ets\pages\Index.ets" @'
import { filePicker } from '@kit.CoreFileKit';
import { zlib } from '@kit.BasicServicesKit';
import { fileIo as fs } from '@kit.CoreFileKit';
import { common } from '@kit.AbilityKit';
import { promptAction } from '@kit.ArkUI';

@Entry
@Component
struct Index {
  @State srcFile: string = '';
  @State outDir: string = '';
  @State log: string = '请选择要解压的压缩文件（.zip / .gz；.7z/.xz 需移植 native 库，见 README）';

  // 选择压缩文件
  async pickFile() {
    try {
      const doc = new filePicker.DocumentSelectOptions();
      doc.maxSelectNumber = 1;
      doc.fileSuffixFilters = ['.zip', '.gz', '.tar', '.7z', '.xz'];
      const ctx = getContext(this) as common.UIAbilityContext;
      const res = await filePicker.DocumentViewPicker(ctx).select(doc);
      if (res && res.length > 0) { this.srcFile = res[0]; this.log = '已选文件：' + this.srcFile; }
    } catch (e) { this.log = '选择文件失败：' + JSON.stringify(e); }
  }

  // 选择解压目标目录
  async pickDir() {
    try {
      const ctx = getContext(this) as common.UIAbilityContext;
      const opt = new filePicker.DocumentSelectOptions();
      opt.maxSelectNumber = 1;
      opt.selectMode = filePicker.DocumentSelectMode.FOLDER;
      const res = await filePicker.DocumentViewPicker(ctx).select(opt);
      if (res && res.length > 0) { this.outDir = res[0]; this.log = '目标目录：' + this.outDir; }
    } catch (e) { this.log = '选择目录失败：' + JSON.stringify(e); }
  }

  // 解压（@ohos.zlib 官方支持 zip / gz）
  doExtract() {
    if (!this.srcFile || !this.outDir) {
      promptAction.showToast({ message: '请先选择文件和目标目录' });
      return;
    }
    if (!fs.existsSync(this.outDir)) { fs.mkdirSync(this.outDir, true); }
    this.log = '正在解压...';
    zlib.decompressFile(this.srcFile, this.outDir, (err) => {
      if (err) {
        this.log = '解压失败：' + JSON.stringify(err);
      } else {
        this.log = '解压完成：' + this.outDir;
        promptAction.showToast({ message: '解压完成' });
      }
    });
  }

  build() {
    Column({ space: 16 }) {
      Text('XZ 压缩工具（鸿蒙版）').fontSize(22).fontWeight(FontWeight.Bold).margin({ top: 24 })
      Button('1. 选择压缩文件').width('86%').onClick(() => this.pickFile())
      Button('2. 选择解压目标目录').width('86%').onClick(() => this.pickDir())
      Button('3. 开始解压').width('86%').type(ButtonType.Capsule).backgroundColor('#5B4BD8').onClick(() => this.doExtract())
      Text(this.log).fontSize(14).width('86%').padding(12).border({ width: 1, color: '#DDDDDD' })
    }
    .width('100%').height('100%').alignItems(HorizontalAlign.Center)
  }
}
'@

WF "README.md" @'
# XZ 压缩工具 · 鸿蒙 HarmonyOS NEXT 工程模板

## 重要边界（务必先读）
- 纯血鸿蒙 **HarmonyOS NEXT（5.0+）不再兼容安卓 APK**，只能安装/运行 HAP/APP，
  且必须用华为官方 **DevEco Studio + HarmonyOS SDK** 编译、用华为账号签名。
- 因此 Windows 端的“生成 APK”无法在 NEXT 上直接安装；
  - HarmonyOS 4.x 及更早（兼容安卓/AOSP）：直接用主程序生成的 **APK** 即可。
  - HarmonyOS NEXT：请用本模板在 DevEco Studio 中编译。

## 如何使用
1. 安装并打开 DevEco Studio（主菜单“工具下载”里有官网入口）。
2. 推荐先用 DevEco Studio 向导新建一个 Empty Ability 工程（Stage 模型，API 12），
   再用本目录 `entry/src/main/ets/pages/Index.ets` 覆盖其同名页面，
   并对照 `module.json5` 补好文件选择/媒体权限与 profile。
   （也可直接尝试“打开本目录”，若 DevEco 报资源缺失，按提示补全图标/资源即可。）
3. 连接鸿蒙手机或使用模拟器，点 Run 运行；发布用 Build > Build Hap/APP 并签名。

## 已实现
- 文件选择器（document filePicker）选择压缩文件
- 目录选择器选择解压目标
- 调用系统 `@ohos.zlib` 解压 **.zip / .gz**
- 基础 ArkTS 界面（选文件 / 选目录 / 解压 / 日志）

## 关于 .7z / .xz
系统 `@ohos.zlib` 仅支持 zip/gz。要在 NEXT 上支持 **.xz / .7z / .tar.xz**，
需通过 NDK 移植原生 C/C++ 库：
- xz / tar.xz：移植 **liblzma / XZ Utils**（开源，0BSD/GPL）
- 7z：移植 **7-Zip SDK（LZMA SDK）**（LGPL/BSD）
用 NAPI/ArkTS N-API 封装为 .so，在 ArkTS 中调用解压。
Windows 端已附带的 XZ Utils / 7-Zip 为 Windows 二进制，不能直接用于鸿蒙，
但可复用其 C/C++ 源码交叉编译为 HarmonyOS arm64 目标。

## 版权与署名
- 本模板仅为示例脚手架，按“现状”提供。
- 集成或移植 XZ Utils（GPL 命令行；liblzma 为 0BSD）、7-Zip（LGPL/BSD）时，
  请保留其开源许可与版权声明。
'@

Write-Output "OK:$root"
