#!powershell

# WANT_JSON
# POWERSHELL_COMMON
#!powershell

$result = @{};
Try {
  $WindowsProductName = Get-Attr -obj $params -name WindowsProductName
  $WindowsVersion = Get-Attr -obj $params -name WindowsVersion
  $OsHardwareAbstractionLayer = Get-Attr -obj $params -name OsHardwareAbstractionLayer
  $infoversion = Get-ComputerInfo | select WindowsProductName, WindowsVersion, OsHardwareAbstractionLayer
  $msg = @{}
  $msg.WindowsProductName = $infoversion.WindowsProductName
  $msg.WindowsVersion = $infoversion.WindowsVersion
  $msg.OsHardwareAbstractionLayer = $infoversion.OsHardwareAbstractionLayer
  $result.msg = $msg
  if ($infoversion.WindowsProductName -ne $WindowsProductName)
  {
    Fail-Json $result "Changed WindowsProductName"
  }
  if ($infoversion.WindowsVersion -ne WindowsVersion)
  {
    Fail-Json $result "Changed WindowsVersion"
  }
  if ($infoversion.OsHardwareAbstractionLayer -ne OsHardwareAbstractionLayer)
  {
    Fail-Json $result "Changed OsHardwareAbstractionLayer"
  }
  Exit-Json $result;
}
Catch {
  Fail-Json $result $_.Exception.Message
}