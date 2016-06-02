###################################
#SCOM 2012 User Roles
#Author: Michiel Wouters
#Version: 0.9
#ShowUserRoleScope.ps1
#Date: 2016-06-01
#
###################################

[CmdletBinding()]
Param(
  [Parameter(Mandatory=$True,Position=1)]
   [string]$computerName,
	
   [Parameter(Mandatory=$False)]
   [string]$UserRoleNameMatch="*"
)

New-SCOMManagementGroupConnection -ComputerName $computerName
$mg = Get-SCOMManagementGroup

function GetFolderHierarchy($folderId,$folderpath) {

    $parentfolderid = $null
    $tmpfolder = $mg.GetMonitoringFolder($folderId)   
    $tmpfolderdisplayname = $tmpfolder.DisplayName

    if ($folderpath -eq "" -Or $folderpath -eq $null) {
        $folderpath = $tmpfolderdisplayname
    } else {
        $folderpath = $tmpfolderdisplayname + "\" + $folderpath
    }

    $parentfolderid = $tmpfolder.ParentFolder.id.Guid

    if ($parentfolderid -ne "" -And $parentfolderid -ne $null -And $tmpfolder.name -ne "Microsoft.SystemCenter.Monitoring.ViewFolder.Root") {
        GetFolderHierarchy $parentfolderid $folderpath
    } else { 
        return $folderpath
    }

}

function GetViewHierarchy($viewId) { 

    $tmpview = $mg.GetMonitoringView($viewId)
    $parentfolderid = $tmpview.ParentFolderIds.Guid | Select -First 1
    if($parentfolderid -ne "" -And $parentfolderid -ne $null) {
        $fullpath = GetFolderHierarchy $parentfolderid
        return $fullpath + "\" + $tmpview.DisplayName
    }    
}


Get-SCOMUserRole -DisplayName "$UserRoleNameMatch" | Select -First 10 | Sort-Object DisplayName | foreach { 
  If($_.IsSystem -ne $true)
  {
    Write-Output "-- $($_.DisplayName) --"
    Write-Output "  Groups:"
    If($_.Scope.Objects -ne $null){
      $_.Scope.Objects | foreach {Get-SCOMClass -Id $_} | Sort-Object DisplayName | % {Write-Output "    $($_.displayName)"}
    }
    Write-Output "  Classes:"
    If ($_.Scope.Classes -ne $null) {
      $_.Scope.Classes | foreach {Get-SCOMClass -Id $_} | Sort-Object DisplayName | % {Write-Output "    $($_.displayName)"}
    }

    Write-Output "  Views:"
    If($_.Scope.Views -ne $null){
        $views = ($_.Scope.Views | ? { $_.Second -eq $False }).First.Guid
        $views | % {  GetViewHierarchy($_) } | Sort | % { Write-Output "    $_"}
        $view = $null
    }

    Write-Output "  Tasks:"
    If($_.Scope.NonCredentialTasks -ne $null){
        $Tasks = ($_.Scope.NonCredentialTasks | ? { $_.Second -eq $False }).First.Guid
        if($Tasks.Count -gt 0) {
                $Tasks | % { Get-SCOMTask -Id $_} | Select DisplayName, @{ Label = "Target";Expression={$_.Target.Id | Get-SCOMClass | % { $_.DisplayName}}} | Sort DisplayName | % { Write-Output "    $($_.DisplayName) (target: $($_.Target))" }
        }
        $Tasks = $null
    }
  }
}
