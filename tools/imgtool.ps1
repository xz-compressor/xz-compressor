# imgtool.ps1 -- 图片/图标转换工具 (png/jpg/bmp/gif -> ico 或 png)
# 用法: powershell -ExecutionPolicy Bypass -File imgtool.ps1 <src> <out> <mode>
#   mode=ico : 输出单尺寸 256x256 .ico (exe 图标)
#   mode=png : 输出 512x512 .png (安卓 mipmap 图标)
param(
  [string]$src,
  [string]$out,
  [string]$mode
)
$ErrorActionPreference = 'Stop'
if (-not (Test-Path $src)) { Write-Output "ERR:源文件不存在 $src"; exit 1 }
Add-Type -AssemblyName System.Drawing
$bmp = [System.Drawing.Bitmap]::FromFile($src)
$size = if ($mode -eq 'ico') { 256 } else { 512 }
$nb = New-Object System.Drawing.Bitmap($size, $size)
$g = [System.Drawing.Graphics]::FromImage($nb)
$g.Clear([System.Drawing.Color]::Transparent)
$g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
$g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
$g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
$g.DrawImage($bmp, 0, 0, $size, $size)
$g.Dispose()
try {
  if ($mode -eq 'ico') {
    $h = $nb.GetHicon()
    $ic = [System.Drawing.Icon]::FromHandle($h)
    $fs = [IO.File]::Create($out)
    $ic.Save($fs)
    $fs.Close()
    $ic.Dispose()
  } else {
    $nb.Save($out, [System.Drawing.Imaging.ImageFormat]::Png)
  }
  Write-Output "OK:$out"
} finally {
  $nb.Dispose()
  $bmp.Dispose()
}
