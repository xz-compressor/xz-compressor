# build_html_sfx.ps1 - 生成 HTML 便携自解压单文件
# 用法: powershell -ExecutionPolicy Bypass -File build_html_sfx.ps1 -ArcFile 压缩包 [-Title 标题] [-OutFile 输出html]
param(
  [Parameter(Mandatory=$true)][string]$ArcFile,
  [string]$Title = "",
  [string]$OutFile = ""
)
$ErrorActionPreference = "Stop"
$here = Split-Path -Parent $MyInvocation.MyCommand.Path

if (-not (Test-Path -LiteralPath $ArcFile)) { throw "压缩包不存在: $ArcFile" }
$arcName = [IO.Path]::GetFileName($ArcFile)
if ([string]::IsNullOrWhiteSpace($Title)) { $Title = [IO.Path]::GetFileNameWithoutExtension($ArcFile) }

# 引擎 JS
$js = [IO.File]::ReadAllText((Join-Path $here "7zz.es6.js"))
$js = $js.Replace("export default SevenZip;", "window.SevenZip = SevenZip;")
# wasm b64
$wasmB64 = [Convert]::ToBase64String([IO.File]::ReadAllBytes((Join-Path $here "7zz.wasm")))
# 数据 b64
$dataB64 = [Convert]::ToBase64String([IO.File]::ReadAllBytes($ArcFile))

# 提取 SFX_TEMPLATE
$tpl = [IO.File]::ReadAllText((Join-Path $here "app_template.html"))
$key = 'const SFX_TEMPLATE = `'
$s = $tpl.IndexOf($key) + $key.Length
$e = $tpl.IndexOf('`', $s)
$html = $tpl.Substring($s, $e - $s)

# 填充
$html = $html.Replace('__TITLE__', $Title)
$html = $html.Replace('__ARC__', $arcName)
$html = $html.Replace('__ARC_NAME__', $arcName)
$html = $html.Replace('__ENGINE_JS__', $js)
$html = $html.Replace('__WASM_COPY__', $wasmB64)
$html = $html.Replace('__DATA_B64__', $dataB64)
# SFX 模板里 module 结束标签是转义的（用于内嵌字符串），独立文件需还原
$html = $html.Replace('<\/script>', '</script>')

# 输出
if ([string]::IsNullOrWhiteSpace($OutFile)) {
  $safe = ($Title -replace '[\\/:*?"<>|]', '_')
  $OutFile = Join-Path ([IO.Path]::GetDirectoryName((Resolve-Path -LiteralPath $ArcFile).Path)) ($safe + ".html")
}
[IO.File]::WriteAllText($OutFile, $html, (New-Object Text.UTF8Encoding($false)))
Write-Output ("自解压HTML已生成: " + $OutFile + "  (" + [math]::Round((Get-Item $OutFile).Length/1MB,2) + " MB)")
