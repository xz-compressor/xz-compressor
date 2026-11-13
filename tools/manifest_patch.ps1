param($mf, $pkg, $icon, $appnm)
$t = [IO.File]::ReadAllText($mf)
$t = $t.Replace('package="com.xzfull"', 'package="' + $pkg + '"')
$t = $t.Replace('package="com.xzport"', 'package="' + $pkg + '"')
if ($appnm -ne '') {
  $t = $t.Replace('android:label="XZ便携压缩"', 'android:label="' + $appnm + '"')
  $t = $t.Replace('android:label="XZ完整压缩"', 'android:label="' + $appnm + '"')
}
if ($icon -ne '') { $t = $t.Replace('<application', '<application android:icon="@mipmap/icon"') }
[IO.File]::WriteAllText($mf, $t, (New-Object Text.UTF8Encoding $false))
