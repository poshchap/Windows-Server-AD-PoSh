##########################################################################################################
<#
.SYNOPSIS
    Mirrors an XML dump of a source domain's OU hierarchy to a target test domain.
    
.DESCRIPTION
    Creates the OU structure contained in a backup XML file in a target domain. Does not create OUs if 
    they already exist.  
    
    Intended to be used with a sister script that dumps the OU structure from a source domain.

    Logs all script actions to a date and time named log.

    Requirements:

        * PowerShell ActiveDirectory Module
        * An XML backup created by partner Dump_OU_Structure.ps1 script
        * Trace32.exe (SMS Trace) or CMTrace.exe (Configuration Manager Trace Log Tool) to view script log

    NB - there will be an error written to screen following the test for the existence of an OU. This may 
         result in a lot of red text.

.EXAMPLE
    .\Mirror_OU_Structure.ps1 -Domain contoso.com -BackupXml .\150410093716_HALO_OU_Dump.xml

    Creates the OU structure contained in the 150410093716_HALO_OU_Dump.xml backup file in the contoso.com
    domain. Does not create OUs if they already exist. 

    Writes a log file of all script actions.

.OUTPUTS
    Date and time stamped log file, e.g. 150410110533_AD_OU_Mirror.log, for use with Trace32.exe (SMS Trace) 
    or CMTrace.exe (Configuration Manager Trace Log Tool)

    SMS Trace - http://www.microsoft.com/en-us/download/details.aspx?id=18153
    CM Trace - Installation directory on Configuration Manager 2012 Site Server - <Install Directory>\tools\


    EXIT CODES:  1 - Report file not found
                 2 - Custom XML OU file not found

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

#Requires -version 3
#Requires -modules ActiveDirectory


#Define and validate parameters
[CmdletBinding()]
Param(
      #The target domain
      [parameter(Mandatory=$True,Position=1)]
      [ValidateScript({Get-ADDomain -Identity $_})] 
      [String]$Domain,

      #The source backup file 
      [parameter(Mandatory=$True,Position=2)]
      [ValidateScript({Test-Path -Path $_})]
      [String]$BackupXml
      )


#Set strict mode to identify typographical errors (uncomment whilst editing script)
Set-StrictMode -version Latest



##########################################################################################################

##############################
## FUNCTION - Log-ScriptEvent
##############################

<#
   Write a line of data to a script log file in a format that can be parsed by Trace32.exe / CMTrace.exe

   The severity of the logged line can be set as:

        1 - Information
        2 - Warning
        3 - Error

   Warnings will be highlighted in yellow. Errors are highlighted in red.

   The tools:

   SMS Trace - http://www.microsoft.com/en-us/download/details.aspx?id=18153
   CM Trace - Installation directory on Configuration Manager 2012 Site Server - <Install Directory>\tools\
#>

Function Log-ScriptEvent {

    #Define and validate parameters
    [CmdletBinding()]
    Param(
          #Path to the log file
          [parameter(Mandatory=$True)]
          [String]$NewLog,

          #The information to log
          [parameter(Mandatory=$True)]
          [String]$Value,

          #The source of the error
          [parameter(Mandatory=$True)]
          [String]$Component,

          #The severity (1 - Information, 2- Warning, 3 - Error)
          [parameter(Mandatory=$True)]
          [ValidateRange(1,3)]
          [Single]$Severity
          )


    #Obtain UTC offset
    $DateTime = New-Object -ComObject WbemScripting.SWbemDateTime 
    $DateTime.SetVarDate($(Get-Date))
    $UtcValue = $DateTime.Value
    $UtcOffset = $UtcValue.Substring(21, $UtcValue.Length - 21)


    #Create the line to be logged
    $LogLine =  "<![LOG[$Value]LOG]!>" +`
                "<time=`"$(Get-Date -Format HH:mm:ss.fff)$($UtcOffset)`" " +`
                "date=`"$(Get-Date -Format M-d-yyyy)`" " +`
                "component=`"$Component`" " +` 
                "context=`"$([System.Security.Principal.WindowsIdentity]::GetCurrent().Name)`" " +`
                "type=`"$Severity`" " +`
                "thread=`"$([Threading.Thread]::CurrentThread.ManagedThreadId)`" " +`
                "file=`"`">"

    #Write the line to the passed log file
    Add-Content -Path $NewLog -Value $LogLine

}   #End of Function Log-ScriptEvent


##########################################################################################################

########
## Main
########

#Create a variable to represent a new script log, constructing the report name from date details
$NewReport = ".\$(Get-Date -Format yyMMddHHmmss)_AD_OU_Mirror.log" 

#Make sure the script log has been created
if (New-Item -ItemType File -Path $NewReport) {

    ##Start writing to the script log (Start_Script)
    Log-ScriptEvent $NewReport ("=" * 90) "Start-Script" 1
    Log-ScriptEvent $NewReport "TARGET_DOMAIN: $Domain" "Start_Script" 1
    Log-ScriptEvent $NewReport "BACKUP_SOURCE: $BackupXml" "Start_Script" 1
    Log-ScriptEvent $NewReport ("=" * 90) "Start_Script" 1
    Log-ScriptEvent $NewReport " " " " 1

    #Instantiate an object for the target domain
    $TargetDomain = Get-ADDomain -Identity $Domain

    #Obtain the target domain FQDN
    $TargetDomainFqdn = $TargetDomain.DNSRoot

    #Obtain the target domain DN
    $TargetDomainDn = $TargetDomain.DistinguishedName

    #Obtain the target domain PDCe
    $TargetPdc = $TargetDomain.PDCEmulator

    #Import the OU information contained in the XML file
    $OuInfo = Import-Clixml -Path $BackupXml -ErrorAction SilentlyContinue

    #Make sure we have custom OU info
    if ($OuInfo) {

        #Log custom XML import success
        Log-ScriptEvent $NewReport "Custom OU objects successfully imported from $BackupXml" "Import_OUs" 1
        Log-ScriptEvent $NewReport " " " " 1 

        #Obtain the source domain DN from the first custom OU object
        $SourceDomainDn = ($OuInfo | Select -First 1).DomainDn

        #Create a counter
        $i = 0

        #Loop through each of the OUs
        foreach ($Ou in $OuInfo) {

            #Replace the domain DN with the target filter DN for our OU
            $TargetOuDn = $Ou.DistinguishedName –Replace $SourceDomainDn,$TargetDomainDn

            #Replace the domain DN with the target filter DN for our parent path
            $TargetParentDn = $Ou.ParentDn –Replace $SourceDomainDn,$TargetDomainDn

            #Test that the parent exists
            Try {$TargetParent = Get-ADObject -Identity $TargetParentDn -Server $TargetPdc}
            Catch{}

            #Check to see that the parent OU already exists
            if ($TargetParent) {

                #Log that object exists
                Log-ScriptEvent $NewReport "`"$TargetParentDn`" parent already exists in $Domain - checking for child OU..." "Import_OUs" 1

                #Test that the OU doesn't already exist
                Try {$TargetOu= Get-ADObject -Identity $TargetOuDn -Server $TargetPdc}
                Catch {}

                #Check to see if the target OU already exists
                if ($TargetOu) {

                    #Log that object exists
                    Log-ScriptEvent $NewReport "`"$TargetOuDn`" already exists in $Domain" "Import_OUs" 1
                    Log-ScriptEvent $NewReport " " " " 1 

                }   #End of if ($TargetOu)

                else {

                    #Log that object does not exist
                    Log-ScriptEvent $NewReport "`"$TargetOuDn`" does not exist in $Domain - attempting to create OU..." "Import_OUs" 1


                    #Create the OU
                    $NewOu = New-ADOrganizationalUnit -Name $Ou.Name `                                                      -Path $TargetParentDn `                                                      -Server $TargetPdc `                                                      -ErrorAction SilentlyContinue

                        #Check the success of the New-ADOrganizationalUnit cmdlet
                        if ($?) {

                            #Log success of New-ADOrganizationalUnit cmdlet
                            Log-ScriptEvent $NewReport "Creation of `"$TargetOuDn`" succeeded." "Import_OUs" 1
                            Log-ScriptEvent $NewReport " " " " 1    


                        }   #End of if ($?)

                        else {

                            #Log failure of New-ADOrganizationalUnit cmdlet
                            Log-ScriptEvent $NewReport "Creation of `"$TargetOuDn`" failed. $($Error[0].exception.message)" "Import_OUs" 3
                            Log-ScriptEvent $NewReport " " " " 1    


                        }   #End of else ($?)


                }   #End of else ($TargetOu)


            }   #End of if ($TargetParent)
            else {

                #Log that object doesn't exist
                Log-ScriptEvent $NewReport "$TargetParentDn parent does not exist in $Domain" "Import_OUs" 3

            }   #End of else ($TargetParent)


            #Spin up a progress bar for each filter processed
            Write-Progress -Activity "Importing OUs to $TargetDomainFqdn" -Status "Processed: $i" -PercentComplete -1

            #Increment the filter counter
            $i++

            #Nullify key variables
            $TargetOu = $null
            $TargetParent = $null


        }   #End of foreach($Ou in $Ous)

    }   #End of if ($OuInfo)

    else {

    #Log failure to import custom OU XML object
    Log-ScriptEvent $NewReport "$BackupXml import failed" "Import_OUs" 3
    Log-ScriptEvent $NewReport "Script execution stopped" "Import_OUs" 1
    Log-ScriptEvent $NewReport ("=" * 90) "Import_OUs" 1
    Write-Error "$BackupXml not found. Script execution stopped."
    Exit 2

    }   #End of else ($OuInfo)


    #Close of the script log
    Log-ScriptEvent $NewReport " " " " 1 
    Log-ScriptEvent $NewReport ("=" * 90) "Finish_Script" 1
    Log-ScriptEvent $NewReport "OUs_PROCESSED: $i" "Finish_Script" 1
    Log-ScriptEvent $NewReport ("=" * 90) "Finish_Script" 1


}   #End of if (New-Item -ItemType File -Path $NewReport)

else {

    #Write a custom error
    Write-Error "$NewReport not found. Script execution stopped."
    Exit 1

}   #End of else (New-Item -ItemType File -Path $NewReport)