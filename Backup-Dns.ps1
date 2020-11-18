##########################################################################################################
<#
.SYNOPSIS
    Backup all DNS Zones defined on a Windows 2008+ DNS Server
    
.DESCRIPTION
    Creates a date and time named backup folder of a DNS servers zones. 

    Requirements: 
        * Windows 2008/R2 + DNS Management console installed
        * Run locally

    Original by Griffon - http://c-nergy.be/blog/?p=1837

.EXAMPLE
    .\Backup-Dns.ps1

    Backup all DNS Zones defined on the server on which the script was executed.

.OUTPUTS
    Date and time stamped backup folder, e.g. C:\Windows\system32\dns\backup\160303090223,
    containing a file for each zone found.

.NOTES
    THIS CODE-SAMPLE IS PROVIDED "AS IS" WITHOUT WARRANTY OF ANY KIND, EITHER EXPRESSED 
    OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE IMPLIED WARRANTIES OF MERCHANTABILITY AND/OR 
    FITNESS FOR A PARTICULAR PURPOSE.

    This sample is not supported under any Microsoft standard support program or service. 
    The script is provided AS IS without warranty of any kind. Microsoft further disclaims all
    implied warranties including, without limitation, any implied warranties of merchantability
    or of fitness for a particular purpose. The entire risk arising out of the use or performance
    of the sample and documentation remains with you. In no event shall Microsoft, its authors,
    or anyone else involved in the creation, production, or delivery of the script be liable for 
    any damages whatsoever (including, without limitation, damages for loss of business profits, 
    business interruption, loss of business information, or other pecuniary loss) arising out of 
    the use of or inability to use the sample or documentation, even if Microsoft has been advised 
    of the possibility of such damages, rising out of the use of or inability to use the sample script, 
    even if Microsoft has been advised of the possibility of such damages. 
#>
##########################################################################################################

#################################
## Script Options and Parameters
#################################

#Requires -version 2

#Set strict mode to identify typographical errors (uncomment whilst editing script)
#Set-StrictMode -version Latest

#Version : 0.4 – Integrated comments - Jeffrey Hicks

<#
 Version : 0.5 – Added error checking, date / time stamped output folder, comment based help and
                 removed Invoke-Expression - Ian Farr 03/2016
#>

#Original by Griffon - http://c-nergy.be/blog/?p=1837

##########################################################################################################


#Get Name of the server with env variable
$DnsServer = $env:computername

#Define date / time variable
$DateTime = Get-Date -Format yyMMddHHmmss

#Define folder where to store backup
$BckPath =”c:\windows\system32\dns\backup\$DateTime"

#Create backup folder
$Create = New-Item -Path $BckPath -ItemType Directory -ErrorAction SilentlyContinue

if ($Create) {

    #Define file name for Dns Settings
    $File = Join-Path $BckPath “input.csv”


    #Get DNS settings using WMI
    $List = Get-WmiObject -ComputerName $DnsServer -Namespace root\MicrosoftDNS -Class MicrosoftDNS_Zone

    if ($List) {

        #Export information into input.csv file
        $List | Select-Object Name,ZoneType,AllowUpdate,@{Name=”MasterServers”;Expression={$_.MasterServers}},DsIntegrated | Export-csv $File -NoTypeInformation


        #Call Dnscmd.exe to export dns zones
         $List | ForEach-Object {

             $ZonePath = ”backup\$($DateTime)\$($_.Name).dns"
             &"C:\Windows\system32\dnscmd.exe" $DnsServer `/ZoneExport $_.Name $ZonePath
 
         }   #end of ForEach-Object

    }   #end of if ($List)
    else {

    Write-Error "Failed to obtain DNS WMI object... exiting script"

    }   #end of else ($List)

}   #end of if ($Create)
else {

    Write-Error "Failed to create backup folder... exiting script"

}   #end of else ($Create)