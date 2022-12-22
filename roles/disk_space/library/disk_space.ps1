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
  if (($disc_size.FreeSpace / $disc_size.Size) -lt ($AvaliableSize * 0.01))
  {
    $gigabyte = $disc_size.FreeSpace / 1024 / 1024 / 1024
    Fail-Json $result "$gigabyte GB"
  }
  Exit-Json $result;
}
Catch {
  Fail-Json $result $_.Exception.Message
}