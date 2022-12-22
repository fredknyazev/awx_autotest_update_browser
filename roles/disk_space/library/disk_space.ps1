#!powershell

# WANT_JSON
# POWERSHELL_COMMON
#!powershell

$params = Parse-Args $args;
$result = @{};
Try {
  $AvaliableSize = Get-Attr -obj $params -name AvaliableSize
  $disc_size = Get-CimInstance -ClassName Win32_LogicalDisk | where caption -eq "C:" | Select-Object -Property DeviceID,FreeSpace,Size
  $msg = @{}
  $msg.FreeSpace = $disc_size.FreeSpace
  $msg.Size = $disc_size.Size
  $result.msg = $msg
  Fail-Json $result "Less FreeSpace Current: $msg.FreeSpace"
  Exit-Json $result;
}
Catch {
  Fail-Json $result $_.Exception.Message
}