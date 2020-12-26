#!powershell

# WANT_JSON
# POWERSHELL_COMMON
#!powershell

$result = @{};
Set-Attr $result "msg" "Init msg";
Try {
  $infoversion = Get-ComputerInfo | select WindowsProductName, WindowsVersion, OsHardwareAbstractionLayer
  $myObject | ConvertTo-Json -depth 1- | Set-Content -Path $Path
  $msg = @{};
  msg.WindowsProductName = $infoversion.WindowsProductName
  msg.WindowsVersion = $infoversion.WindowsVersion
  msg.OsHardwareAbstractionLayer = $infoversion.OsHardwareAbstractionLayer
  $result.msg = $msg
  Exit-Json $result;
}
Catch {
  Fail-Json $result $_.Exception.Message
}