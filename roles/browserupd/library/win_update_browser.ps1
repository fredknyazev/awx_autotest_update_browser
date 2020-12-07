#!powershell

# WANT_JSON
# POWERSHELL_COMMON
#!powershell

$ololo = Import-Module Ansible.ModuleUtils.Legacy -Force
$params = Parse-Args $args;
$result = @{};
Set-Attr $result "changed" $false;
$state = Get-Attr -obj $params -name state -failifempty $true -emptyattributefailmessage "missing required argument: state"
$ffinstall = Get-Attr -obj $params -name ffinstall -default 0
$chromeinstall = Get-Attr -obj $params -name chromeinstall -default 0

function Get-MsiProductVersion {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [ValidateScript({$_ | Test-Path -PathType Leaf})]
        [string]
        $Path
    )    
    function Get-Property ($Object, $PropertyName, [object[]]$ArgumentList) {
        return $Object.GetType().InvokeMember($PropertyName, 'Public, Instance, GetProperty', $null, $Object, $ArgumentList)
    }

    function Invoke-Method ($Object, $MethodName, $ArgumentList) {
        return $Object.GetType().InvokeMember($MethodName, 'Public, Instance, InvokeMethod', $null, $Object, $ArgumentList)
    }
    $ErrorActionPreference = 'Stop'
    Set-StrictMode -Version Latest
    #http://msdn.microsoft.com/en-us/library/aa369432(v=vs.85).aspx
    $msiOpenDatabaseModeReadOnly = 0
    $Installer = New-Object -ComObject WindowsInstaller.Installer
    $Database = Invoke-Method $Installer OpenDatabase  @($Path, $msiOpenDatabaseModeReadOnly)
    $View = Invoke-Method $Database OpenView  @("SELECT Value FROM Property WHERE Property='ProductVersion'")
    #$View = Invoke-Method $Database OpenView  @("SELECT Value FROM Property WHERE Property='Comments'")
    Invoke-Method $View Execute
    $Record = Invoke-Method $View Fetch
    if ($Record) {
        Write-Output (Get-Property $Record StringData 1)
        #Write-Output (Get-Property $Record StringData)
    }
    Invoke-Method $View Close @()
    Remove-Variable -Name Record, View, Database, Installer
}
Function Kill-Process {
  $processname = Get-Attr -obj $params -name processname -failifempty $true -emptyattributefailmessage "missing required argument: processname"
  $processlist = @() 
  $processlist += (Get-Process -name $processname -ErrorAction SilentlyContinue | where {-not $_.HasExited})
  if ($processlist){
    #Get-Process -name $processname | where {-not $_.HasExited} | Stop-Process -Force -ErrorAction SilentlyContinue
    $exe = $processname + ".exe"
    $taskkill = "C:\Windows\System32\taskkill.exe"
    $params = "/im $exe /f"
    $params1 = $params.Split(" ")
    #$qq = & "$taskkill" $params1
    Start-Process $taskkill -ArgumentList $params1 -Wait -NoNewWindow
    start-sleep -Seconds 10
    $processlist = @() 
    $processlist += (Get-Process -name $processname -ErrorAction SilentlyContinue | where {-not $_.HasExited})
    if ($processlist){
      Fail-Json $result "failed to kill $processname"      
    }
    else {
      $result.changed = $true
    }
  }
  else {
    $result.changed = $false
  }
}
Function Disable-FF-AutoUpdate {
  $Key = "HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Mozilla\Firefox"
  if  (-Not ( Test-Path "Registry::$Key")){
    New-Item -Path "Registry::$Key" -ItemType RegistryKey -Force
  }
  if ((Get-ItemProperty -Path "Registry::$Key" | select -ExpandProperty DisableAppUpdate) -eq 1){
    $result.changed = $false
  }
  else {
    Set-ItemProperty -path "Registry::$Key" -Name "DisableAppUpdate" -Type DWord -Value 1
    $result.changed = $true
  }
}

Function Install-FF {
  $msg = @{}
  $browserexe = Get-Attr -obj $params -name browserexe -default 'C:\Program Files\Mozilla Firefox\firefox.exe'
  if (test-path $browserexe){
    #$ffversion = ((get-item $browserexe).VersionInfo.ProductVersion).Split(".")[0]
    $ffversion = [system.version]::Parse((get-item $browserexe).VersionInfo.ProductVersion)
  }
  else {
    $ffversion = [system.version]::Parse("0.0")
  }
  $msg.currentversion = $ffversion.ToString()
  $copypath = "C:\windows\temp"
  $browserdistr = Get-Attr -obj $params -name browserdistr -failifempty $browserdistr -emptyattributefailmessage "missing required argument: browserdistr"
  $copydistr = Copy-Item -Path $browserdistr -Destination "C:\Windows\Temp" -PassThru
  if (-not $copydistr.fullname){
    Fail-Json $result "failed to copy distr from $browserdistr to $copydistr"
  }
  $browserdistr = $copydistr.fullname
  
  if (test-path $browserdistr){
    #$distrversion = ((get-item $browserdistr | select -ExpandProperty BaseName).Split(" ")[-1]).Split(".")[0]
    $distrversion = [system.version]::Parse((get-item $browserdistr | select -ExpandProperty BaseName).Split(" ")[-1])
  }
  else {
    Fail-Json $result "FF distr not found on path $browserdistr"
  } 
  if ($distrversion -gt $ffversion){
    $params = "/S /MaintenanceService=false"
    $params1 = $params.Split(" ")
    & "$browserdistr" $params1
    Start-Sleep -Seconds 20
    Remove-Item -Path $copydistr.fullname -Force
    #$ffversion = ((get-item $browserexe).VersionInfo.ProductVersion).Split(".")[0]
    $ffversion = [system.version]::Parse((get-item $browserexe).VersionInfo.ProductVersion)
    if ($ffversion -eq $distrversion){
      $result.changed = $true
    }
    else {
      Fail-Json $result "failed to update FF, current version is $ffversion, dist version is $distrversion"
    }
  }
  else {
    $result.changed = $false
  }
  $msg.newversion = $ffversion.ToString()
  $msg.distrversion = $distrversion.ToString()
  #$result.msg = ($msg | ConvertTo-Json | % {[Regex]::Replace($_, "\\u(?<Value>[a-zA-Z0-9]{4})", {param($m) ([char]([int]::Parse($m.Groups['Value'].Value, [System.Globalization.NumberStyles]::HexNumber))).ToString()})}).Replace('\\n','\n').Replace('\\r','\r')
  $result.msg = $msg
}
Function Install-Chrome{
  $msg = @{}
  $browserexe = Get-Attr -obj $params -name browserexe -default 'C:\Program Files (x86)\Google\Chrome\Application\chrome.exe'
  if (test-path $browserexe){
    #$chromeversion = ((get-item $browserexe).VersionInfo.ProductVersion).Split(".")[0]
    $chromeversion = [system.version]::Parse((get-item $browserexe).VersionInfo.ProductVersion)
  }
  else {
    $chromeversion = [system.version]::Parse("0.0")
  }
  $msg.currentversion = $chromeversion.ToString()
  #$browserdistr = Get-Attr -obj $params -name browserdistr -failifempty $browserdistr -emptyattributefailmessage "missing required argument: browserdistr"
  $copypath = "C:\windows\temp"
  $browserdistr = Get-Attr -obj $params -name browserdistr -failifempty $browserdistr -emptyattributefailmessage "missing required argument: browserdistr"
  $copydistr = Copy-Item -Path $browserdistr -Destination "C:\Windows\Temp" -PassThru
  if (-not $copydistr.fullname){
    Fail-Json $result "failed to copy distr from $browserdistr to $copydistr"
  }
  $browserdistr = $copydistr.fullname
  if (test-path $browserdistr){
    #$distrmsiversion = (Get-MsiProductVersion -Path $browserdistr | where {$_}).Split(".")[0]
    $path1 = $browserdistr
    $shell = New-Object -COMObject Shell.Application
    $folder = Split-Path $path1
    $file = Split-Path $path1 -Leaf
    $shellfolder = $shell.Namespace($folder)
    $shellfile = $shellfolder.ParseName($file)
    $a = (0..287 | Foreach-Object { '{0} = {1}' -f $_, $shellfolder.GetDetailsOf($null, $_) })
    $comments = @()
    $comments += ($a | where {($_.Contains("Комментарии")) -or ($_.Contains("Comments"))})
    $commentstringnumber = ($comments[0].Split("="))[0].Trim()
    #$distrversion = (($shellfolder.GetDetailsOf($shellfile, $commentstringnumber)).Split("."))[0]
    $distrversion = [system.version]::Parse((($shellfolder.GetDetailsOf($shellfile, $commentstringnumber)).Split(" "))[0])
  }
  else {
    Fail-Json $result "Chrome distr not found on path $browserdistr"
  } 

  if ($distrversion -gt $chromeversion){
    $MSIArguments = @(
      "/i"
      ('"{0}"' -f $browserdistr)
      "/qn"
      "/norestart"
    )
    #$params1 = $params.Split(" ")
    Start-Process msiexec.exe -ArgumentList $MSIArguments -Wait -NoNewWindow
    Start-Sleep -Seconds 20
    Remove-Item -Path $copydistr.fullname -Force
    #$chromeversion = ((get-item $browserexe).VersionInfo.ProductVersion).Split(".")[0]
    $chromeversion = [system.version]::Parse((get-item $browserexe).VersionInfo.ProductVersion)
    if ($chromeversion -eq $distrversion){
      $result.changed = $true
    }
    else {
      Fail-Json $result "failed to update Chrome, current version is $chromeversion, distr version is $distrversion"
    }
  }
  else {
    $result.changed = $false
  }
  $msg.newversion = $chromeversion.ToString()
  #$msg.browserexe = $browserexe
  #$msg.browserdistr = $browserdistr
  $msg.distrversion = $distrversion.ToString()
  #$msg.msiversion = $distrmsiversion
  #$result.msg = ($msg | ConvertTo-Json | % {[Regex]::Replace($_, "\\u(?<Value>[a-zA-Z0-9]{4})", {param($m) ([char]([int]::Parse($m.Groups['Value'].Value, [System.Globalization.NumberStyles]::HexNumber))).ToString()})}).Replace('\\n','\n').Replace('\\r','\r')
  $result.msg = $msg
}
Try {
  switch ($state) {
    kill {Kill-Process}
    ffinstall {if ($ffinstall -eq 1){Install-FF}}
    chromeinstall {if ($chromeinstall -eq 1){Install-Chrome}}
    FFUpdatesDisabled {if ($ffinstall -eq 1){Disable-FF-AutoUpdate}}
    ffinstallFull {if ($ffinstall -eq 1){kill-Process; Disable-FF-AutoUpdate; Install-FF}}
    cromeinstallFull {if ($chromeinstall -eq 1){Kill-Process; Install-Chrome}}
  }
  Exit-Json $result;
}
Catch {
  Fail-Json $result $_.Exception.Message
}