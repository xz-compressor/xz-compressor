# build_html.ps1 - 构建单文件离线 HTML 压缩工具（完整版）
# 用法: powershell -ExecutionPolicy Bypass -File build_html.ps1 [-AppName 名称] [-AppVersion 版本] [-OutFile 输出路径]
param(
  [string]$AppName = "XZ压缩工具",
  [string]$AppVersion = "早期测试版 0.1",
  [string]$OutFile = ""
)
$ErrorActionPreference = "Stop"
$here = Split-Path -Parent $MyInvocation.MyCommand.Path

$js = [IO.File]::ReadAllText((Join-Path $here "7zz.es6.js"))
$js = $js.Replace("export default SevenZip;", "window.SevenZip = SevenZip;")

$wasm = [IO.File]::ReadAllBytes((Join-Path $here "7zz.wasm"))
$wasmB64 = [Convert]::ToBase64String($wasm)
$jsB64 = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($js))

$tpl = [IO.File]::ReadAllText((Join-Path $here "app_template.html"))
$html = $tpl.Replace("/*__SEVENZIP_JS__*/", $js)
$html = $html.Replace("__ENGINE_JS_B64__", $jsB64)
$html = $html.Replace("__WASM_B64__", $wasmB64)
$html = $html.Replace("__APP_NAME__", $AppName)
$html = $html.Replace("__APP_VERSION__", $AppVersion)

if ([string]::IsNullOrWhiteSpace($OutFile)) {
  $root = (Get-Item (Join-Path $here "..\..")).FullName
  $OutFile = Join-Path $root "XZ压缩工具_HTML版.html"
}
[IO.File]::WriteAllText($OutFile, $html, (New-Object Text.UTF8Encoding($false)))
Write-Output ("HTML 已生成: " + $OutFile + "  (" + [math]::Round((Get-Item $OutFile).Length/1MB,2) + " MB)")
