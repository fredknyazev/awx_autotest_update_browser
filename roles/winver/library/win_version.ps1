#!powershell

# WANT_JSON
# POWERSHELL_COMMON
#!powershell

$result = @{};
Try {
  $infoversion = Get-ComputerInfo | select WindowsProductName, WindowsVersion, OsHardwareAbstractionLayer
  $msg = @{}
  msg.windowsproductname = $infoversion.WindowsProductName
  msg.windowsversion = $infoversion.WindowsVersion
  msg.oshardwareabstractionlayer = $infoversion.OsHardwareAbstractionLayer
  $result.msg = $msg
  Exit-Json $result;
}
Catch {
  Fail-Json $result $_.Exception.Message
}