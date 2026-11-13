param($cs, $brand, $ver)
# 替换 C# 启动器内嵌窗口标题为品牌名+版本
$t = [IO.File]::ReadAllText($cs, [Text.Encoding]::UTF8)
$t = $t.Replace('XZ完整版压缩工具 早期测试版 0.1', ($brand + ' ' + $ver))
[IO.File]::WriteAllText($cs, $t, (New-Object Text.UTF8Encoding($false)))
