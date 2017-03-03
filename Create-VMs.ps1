#### INPUT #############
$VMName = "mylabvm2"
########################

#######################
# PATH SETTINGS
$VMPath = "D:\VM\"                                  #SDD storage
$VMSwitch1 = "vSwitch2 - Shared"                    #Switch Name
$Parent = "E:\VM\PARENT\w2k16_std_gen2.vhdx"        #normal storage like USB
$answerFilePath = "E:\Scripts\UnattendSource.xml"   #path to your unattend file
#######################


$VHDPath1 = $VMPath + $VMName + "\Virtual Hard Disks\" + $VMName + "_disk_1.vhdx"

#create new vm
New-VM $VMname –Path D:\VM –SwitchName $VMSwitch1 -Generation 2 -NoVHD
Set-VMMemory $VMname -DynamicMemoryEnabled $true -StartupBytes 1GB -MinimumBytes 512MB -MaximumBytes 2GB -Priority 50 -Buffer 20
Set-VMProcessor $VMname -Count 2

#create diff disk
New-VHD -ParentPath $Parent -Differencing -Path $VHDPath1
Add-VMHardDiskDrive -VMName $VMName SCSI 0 0 -Path $VHDPath1

#adjust bootorder for gen2 vm
$newBootOrder = Get-VMFirmware -VMName $VMName | Select BootOrder | % { $_.BootOrder } | sort BootType
Set-VMFirmware -VMName $VMName -BootOrder $newBootOrder

$VHD = (Mount-VHD $VHDPath1 -Passthru | Get-Disk | Get-Partition | ? { $_.Type -eq "Basic"}).DriveLetter

[xml]$Unattend = Get-Content $answerFilePath   # Read the XML file into a variable
($Unattend.unattend.settings | ? { $_.pass -eq "specialize"}).component.ComputerName = $VMName
$Unattend.Save("${VHD}:\\Unattend.xml")
Sleep -Seconds 3 #workaround for Windows detection of mounted disk, before we can dismount.
Dismount-VHD $vhdPath1

Start-VM $VMName