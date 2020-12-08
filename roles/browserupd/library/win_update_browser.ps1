#!powershell

# WANT_JSON
# POWERSHELL_COMMON
#!powershell

$ololo = Import-Module Ansible.ModuleUtils.Legacy -Force
$params = Parse-Args $args;
$result = @{};
Set-Attr $result "changed" $false;
$action = Get-Attr -obj $params -name action -failifempty $true -emptyattributefailmessage "missing required argument: action"
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
    Invoke-Method $View Execute
    $Record = Invoke-Method $View Fetch
    if ($Record) {
        Write-Output (Get-Property $Record StringData 1)
    }
    Invoke-Method $View Close @()
    Remove-Variable -Name Record, View, Database, Installer
}
Function Kill-Process {
  $processname = Get-Attr -obj $params -name processname -failifempty $true -emptyattributefailmessage "missing required argument: processname"
  $processlist = @() 
  $processlist += (Get-Process -name $processname -ErrorAction SilentlyContinue | where {-not $_.HasExited})
  if ($processlist){
    $exe = $processname + ".exe"
    $taskkill = "C:\Windows\System32\taskkill.exe"
    $params = "/im $exe /f"
    $params1 = $params.Split(" ")
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
Function Disable-Chrome-AutoUpdate {
  $Key = "HKEY_LOCAL_MACHINE\SOFTWARE\Wow6432Node\Policies\Google\Update"
  if  (-Not ( Test-Path "Registry::$Key")){
    New-Item -Path "Registry::$Key" -ItemType RegistryKey -Force
  }
  if ((Get-ItemProperty -Path "Registry::$Key" | select -ExpandProperty UpdateDefault) -eq 0){
    $result.changed = $false
  }
  else {
    Set-ItemProperty -path "Registry::$Key" -Name "UpdateDefault" -Type DWord -Value 0
    $result.changed = $true
  }
}

Function Install-FF {
  $msg = @{}
  $browserexe = Get-Attr -obj $params -name browserexe -default 'C:\Program Files\Mozilla Firefox\firefox.exe'
  if (test-path $browserexe){
    $ffversion = [system.version]::Parse((get-item $browserexe).VersionInfo.ProductVersion)
  }
  else {
    $ffversion = [system.version]::Parse("0.0")
  }
  $msg.currentversion = $ffversion.ToString()
  $browserdistr = Get-Attr -obj $params -name browserdistr -failifempty $browserdistr -emptyattributefailmessage "missing required argument: browserdistr"
  if (test-path $browserdistr){
    $copydistr = Copy-Item -Path $browserdistr -Destination "C:\Windows\Temp" -PassThru
    if (-not $copydistr.fullname){
      Fail-Json $result "failed to copy distr from $browserdistr to $copydistr"
    }
    $browserdistr = $copydistr.fullname
    $distrversion = [system.version]::Parse((get-item $browserdistr | select -ExpandProperty BaseName).Split(" ")[-1])
  }
  else {
    Fail-Json $result "FF distr not found on path $browserdistr"
  } 
  if ($distrversion -gt $ffversion){
    $params = "/S /MaintenanceService=false"
    $params1 = $params.Split(" ")
    & "$browserdistr" $params1
    $repeats = 0
    while (($ffversion -ne $distrversion) -and ($repears -le 10)) {
        Start-Sleep -Seconds 5
        $ffversion = [system.version]::Parse((get-item $browserexe).VersionInfo.ProductVersion)
        $repeats += 1
    }
    Remove-Item -Path $copydistr.fullname -Force
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
  $result.msg = $msg
}
Function Install-Chrome{
  $msg = @{}
  $browserexe = Get-Attr -obj $params -name browserexe -default 'C:\Program Files (x86)\Google\Chrome\Application\chrome.exe'
  if (test-path $browserexe){
    $chromeversion = [system.version]::Parse((get-item $browserexe).VersionInfo.ProductVersion)
  }
  else {
    $chromeversion = [system.version]::Parse("0.0")
  }
  $msg.currentversion = $chromeversion.ToString()
  $browserdistr = Get-Attr -obj $params -name browserdistr -failifempty $browserdistr -emptyattributefailmessage "missing required argument: browserdistr"
  if (test-path $browserdistr){
    $copydistr = Copy-Item -Path $browserdistr -Destination "C:\Windows\Temp" -PassThru
    if (-not $copydistr.fullname){
      Fail-Json $result "failed to copy distr from $browserdistr to $copydistr"
    }
    $browserdistr = $copydistr.fullname
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
    Start-Process msiexec.exe -ArgumentList $MSIArguments -Wait -NoNewWindow
    $repeats = 0
    while (($chromeversion -ne $distrversion) -and ($repears -le 10)) {
        Start-Sleep -Seconds 5
        $chromeversion = [system.version]::Parse((get-item $browserexe).VersionInfo.ProductVersion)
        $repeats += 1
    }
    Remove-Item -Path $copydistr.fullname -Force
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
  $msg.distrversion = $distrversion.ToString()
  $result.msg = $msg
}
Function Copy-Webdriver{
  $webdriver = Get-Attr -obj $params -name webdriver -default $null
  $webdriver_path = Get-Attr -obj $params -name webdriver_path -default $null
  if ($webdriver -ne $null -and $webdriver_path -ne $null) {
      $driver_name = Split-Path $webdriver -leaf
      $old_driver_name = "$($webdriver_path)\old_$($driver_name)"
      if (test-path $old_driver_name)
      {
        Remove-Item $old_driver_name
      }
      $webdriver_file_path = "$($webdriver_path)\$($driver_name)"
      if (test-path $webdriver_file_path)
      {
        Rename-Item $webdriver_file_path -NewName "old_$($driver_name)" -Force
      }
      $processname = ""
      if ($chromeinstall -eq 1)
      {
        $processname = "chromedriver"
      }
      if ($ffinstall -eq 1)
      {
        $processname = "geckodriver"
      }
      $processlist = @()
      $processlist += (Get-Process -name $processname -ErrorAction SilentlyContinue | where {-not $_.HasExited})
      if ($processlist){
        $exe = $processname + ".exe"
        $taskkill = "C:\Windows\System32\taskkill.exe"
        $params = "/im $exe /f"
        $params1 = $params.Split(" ")
        Start-Process $taskkill -ArgumentList $params1 -Wait -NoNewWindow
        start-sleep -Seconds 10
        $processlist = @()
        $processlist += (Get-Process -name $processname -ErrorAction SilentlyContinue | where {-not $_.HasExited})
        if ($processlist){
          Fail-Json $result "failed to kill $processname"
        }
        }
      Copy-Item $webdriver -Destination $webdriver_path -Force
      $result.msg.webdriver_update = "success"
    }
}
Try {
  switch ($action) {
    Kill {Kill-Process}
    FFInstall {if ($ffinstall -eq 1){Install-FF}}
    ChromeInstall {if ($chromeinstall -eq 1){Install-Chrome}}
    FFUpdatesDisabled {if ($ffinstall -eq 1){Disable-FF-AutoUpdate}}
    ChromeUpdatesDisabled {if ($chromeinstall -eq 1){Disable-Chrome-AutoUpdate}}
    FFInstallFull {if ($ffinstall -eq 1){Kill-Process; Disable-FF-AutoUpdate; Install-FF; Copy-Webdriver}}
    ChromeInstallFull {if ($chromeinstall -eq 1){Kill-Process; Install-Chrome; Copy-Webdriver; Disable-Chrome-AutoUpdate}}
    CopyWebdriver {if (($chromeinstall -eq 1) -or ($ffinstall -eq 1)) {Copy-Webdriver}}
  }
  Exit-Json $result;
}
Catch {
  Fail-Json $result $_.Exception.Message
}