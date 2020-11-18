##########################################################################################################
<#
.SYNOPSIS
    Mirrors an XML dump of a source domain's user accounts to a target test domain.
    
.DESCRIPTION
    Creates user accounts contained in a backup XML file in a target domain. Does not create users if 
    they already exist. Does not create users if the parent OU does not already exist.  
    
    Intended to be used with a sister script that dumps the user accounts from a source domain.

    Logs all script actions to a date and time named log.

    Requirements:

        * PowerShell ActiveDirectory Module
        * An XML backup created by partner Dump_Users.ps1 script
        * Trace32.exe (SMS Trace) or CMTrace.exe (Configuration Manager Trace Log Tool) to view script log

.EXAMPLE
    .\Mirror_Users.ps1 -Domain contoso.com -BackupXml .\150410093716_HALO_User_Dump.xml

    Creates the user accounts contained in the 150410093716_HALO_User_Dump.xml backup file in the contoso.com
    domain. Does not create users if they already exist. Does not create users if the parent OU does not
    already exist.  

    Writes a log file of all script actions.

.EXAMPLE
    .\Mirror_Users.ps1 -Domain contoso.com 
                       -BackupXml .\150410093716_HALO_User_Dump.xml
                       -TargetOu "OU=Test Users,DC=Halo,DC=Net"

    Creates the user accounts contained in the 150410093716_HALO_OU_Dump.xml backup file in the contoso.com
    domain. Creates Users in the 'Test Users' OU. Does not create users if they already exist. Does not 
    create users if the target OU does not exist.

    Writes a log file of all script actions.

.OUTPUTS
    Date and time stamped log file, e.g. 150410110533_AD_User_Mirror.log, for use with Trace32.exe (SMS Trace) 
    or CMTrace.exe (Configuration Manager Trace Log Tool)

    SMS Trace - http://www.microsoft.com/en-us/download/details.aspx?id=18153
    CM Trace - Installation directory on Configuration Manager 2012 Site Server - <Install Directory>\tools\


    EXIT CODES:  1 - Report file not found
                 2 - Custom XML User file not found

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
      [String]$BackupXml,

      #Optional target OU 
      [parameter(Position=3)]
      [ValidateScript({Get-ADOrganizationalUnit -Identity $_})]
      [String]$TargetOu
      )


#Set strict mode to identify typographical errors (uncomment whilst editing script)
#Set-StrictMode -version Latest



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
$NewReport = ".\$(Get-Date -Format yyMMddHHmmss)_AD_User_Mirror.log" 

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

    #Import the OU information contained in the XML file
    $UserInfo= Import-Clixml -Path $BackupXml -ErrorAction SilentlyContinue

    #Make sure we have custom user info
    if ($UserInfo) {

        #Log custom XML import success
        Log-ScriptEvent $NewReport "Custom User objects successfully imported from $BackupXml" "Mirror_Users" 1
        Log-ScriptEvent $NewReport " " " " 1 

        #Obtain the source domain DN from the first custom user object
        $SourceDomainDn = ($UserInfo| Select -First 1).DomainDn

        #Create counters
        $i = 0    # users processed
        $j = 0    # users matched
        $k = 0    # user created
        $l = 0    # BUILTIN matched
        $m = 0    # user creation failed

        #Loop through each of the custom user objects
        foreach ($User in $UserInfo) {
            
            #Check for know accounts
            Switch -Wildcard ($User.SamAccountName) {

                "Administrator" {

                    #Log that BUILTIN account found
                    Log-ScriptEvent $NewReport "`"$(($User).SamAccountName)`" BUILTIN Administrator account matched in $Domain" "Mirror_Users" 1
                    Log-ScriptEvent $NewReport " " " " 1 

                    #Increment user processed and BUILTIN matched counters
                    $i++
                    $l++

                }

                "Guest" {

                    #Log that BUILTIN account found
                    Log-ScriptEvent $NewReport "`"$(($User).SamAccountName)`" BUILTIN Guest account matched in $Domain" "Mirror_Users" 1
                    Log-ScriptEvent $NewReport " " " " 1 

                    #Increment user processed and BUILTIN matched counters
                    $i++
                    $l++
                }

                "krbtgt*" {

                    #Log that BUILTIN account found
                    Log-ScriptEvent $NewReport "`"$(($User).SamAccountName)`" BUILTIN krbtgt account matched in $Domain" "Mirror_Users" 1
                    Log-ScriptEvent $NewReport " " " " 1 

                    #Increment user processed and BUILTIN matched counters
                    $i++
                    $l++
                }

                "*$" {

                    #Log that BUILTIN account found
                    Log-ScriptEvent $NewReport "`"$(($User).SamAccountName)`" BUILTIN TDO account matched in $Domain" "Mirror_Users" 1
                    Log-ScriptEvent $NewReport " " " " 1 

                    #Increment user processed and BUILTIN matched counters
                    $i++
                    $l++
                }

                Default {

                    #Test that the user SamAccountName doesn't already exist
                    try {$TargetUserSAM = Get-ADUser -Identity $User.SamAccountName -Server $TargetDomainFqdn}
                    catch {}

                    #If we have a user then onwards...
                    if ($TargetUserSAM) {

                        #Log that object exists
                        Log-ScriptEvent $NewReport "SamAccountName - `"$(($User).SamAccountName)`" - already exists in $Domain" "Mirror_Users" 1
                        Log-ScriptEvent $NewReport " " " " 1 
                
                        #Increment user matched counter
                        $j++

                    }   #End of if ($TargetUserSAM)

                    else {

                        #Log that object does not exist
                        Log-ScriptEvent $NewReport "SamAccountName - `"$(($User).SamAccountName)`" - does not exist in $Domain" "Mirror_Users" 1

                        #Test that the user Name doesn't already exist
                        try{$TargetUserName = Get-ADUser -Identity $User.Name -Server $TargetDomainFqdn}
                        catch {}

                        #If we have a user then onwards...
                        if ($TargetUserName) {

                            #Log that object exists
                            Log-ScriptEvent $NewReport "User Name - `"$(($User).Name)`" - already exists in $Domain" "Mirror_Users" 1
                            Log-ScriptEvent $NewReport " " " " 1 
                
                            #Increment user matched counter
                            $j++

                        }   #End of if ($TargetUserName)

                        else {

                            #Log that object does not exist
                            Log-ScriptEvent $NewReport "User Name - `"$(($User).Name)`" - does not exist in $Domain" "Mirror_Users" 1

                            #Determine where we create the user
                            if ($TargetOu) {

                                #Log that we are using a parameter value as our target OU
                                Log-ScriptEvent $NewReport "Using supplied paramter - $TargetOu - as user parent OU" "Mirror_Users" 1  
                            
                                #Attempt to create user in Target OU
                                $NewUser = New-ADUser -Name $User.Name `                                                      -GivenName $User.GivenName `                                                      -Surname $User.SurName `                                                      -SamAccountName $User.SamAccountName `                                                      -DisplayName $User.DisplayName `                                                      -EmailAddress $User.Mail `                                                      -Description $User.Description `                                                      -Path $TargetOu `                                                      -ErrorAction SilentlyContinue

                                #Check the success of the New-ADUser cmdlet
                                if ($?) {

                                    #Log success of New-ADUser cmdlet
                                    Log-ScriptEvent $NewReport "Creation of `"$(($User).SamAccountName)`" succeeded." "Mirror_Users" 1
                                    Log-ScriptEvent $NewReport " " " " 1 
                                    
                                    #Increment user created counter
                                    $k++


                                }   #End of if ($?)

                                else {

                                    #Log failure of New-ADUser cmdlet
                                    Log-ScriptEvent $NewReport "Creation of `"$(($User).SamAccountName)`" failed. $($Error[0].exception.message)" "Mirror_Users" 3
                                    Log-ScriptEvent $NewReport " " " " 1    

                                    #Increment user creation failed counter
                                    $m++


                                }   #End of else ($?)                      


                        }   #End of if ($TargetOu)
                            else {

                                #Replace the domain DN with the target filter DN for our parent path
                                $TargetParentDn = $User.ParentDn –Replace $SourceDomainDn,$TargetDomainDn

                                #Test that the parent exists
                                Try{$TargetParent = Get-ADObject -Identity $TargetParentDn -Server $TargetDomainFqdn}
                                Catch {}

                                #Check to see that the parent OU already exists
                                if ($TargetParent) {

                                    #Log that object exists
                                    Log-ScriptEvent $NewReport "`"$TargetParentDn`" parent already exists in $Domain" "Mirror_Users" 1

                                    #Attempt to create user in Parent OU
                                    $NewUser = New-ADUser -Name $User.Name `                                                          -GivenName $User.GivenName `                                                          -Surname $User.SurName `                                                          -SamAccountName $User.SamAccountName `                                                          -DisplayName $User.DisplayName `                                                          -EmailAddress $User.Mail `                                                          -Description $User.Description `                                                          -Path $TargetParentDn `                                                          -ErrorAction SilentlyContinue

                                        #Check the success of the New-ADUser cmdlet
                                        if ($?) {

                                            #Log success of New-ADUser cmdlet
                                            Log-ScriptEvent $NewReport "Creation of `"$(($User).SamAccountName)`" succeeded." "Mirror_Users" 1
                                            Log-ScriptEvent $NewReport " " " " 1 
                                        
                                            #Increment user created counter
                                            $k++


                                        }   #End of if ($?)

                                        else {

                                            #Log failure of New-ADUser cmdlet
                                            Log-ScriptEvent $NewReport "Creation of `"$(($User).SamAccountName)`" failed. $($Error[0].exception.message)" "Mirror_Users" 3
                                            Log-ScriptEvent $NewReport " " " " 1    

                                            #Increment user creation failed counter
                                            $m++


                                        }   #End of else ($?) 

                                }   #End of if ($TargetParent)
                                else {

                                    #Log that object does not exist 
                                    Log-ScriptEvent $NewReport "`"$TargetParentDn`" parent does not exist in $Domain... user creation will not be attempted" "Mirror_Users" 1
                                    Log-ScriptEvent $NewReport " " " " 1 

                                }   #End of else ($TargetParent)

                            }   #End of else ($TargetOu)

                        }   #End of else ($TargetUserName)

                    }   #End of else ($TargetUserSAM)


                    #Spin up a progress bar for each filter processed
                    Write-Progress -Activity "Mirroring users to $TargetDomainFqdn" -Status "Processed: $i" -PercentComplete -1

                    #Increment the user processed counter
                    $i++

                    #Nullify key variables
                    $TargetUserSAM = $null
                    $TargetUserName = $null
                    $TargetUserDn = $null
                    $TargetParent = $null

                }   #End of Switch Default

            }   #End of Switch -Wildcard ($User.UserDn)

        }   #End of foreach($User in $Users)

    }   #End of if ($UserInfo)

    else {

    #Log failure to import custom OU XML object
    Log-ScriptEvent $NewReport "$BackupXml import failed" "Mirror_Users" 3
    Log-ScriptEvent $NewReport "Script execution stopped" "Mirror_Users" 1
    Log-ScriptEvent $NewReport ("=" * 90) "Mirror_Users" 1
    Write-Error "$BackupXml not found. Script execution stopped."
    Exit 2

    }   #End of else ($UserInfo)


    #Close of the script log
    Log-ScriptEvent $NewReport " " " " 1 
    Log-ScriptEvent $NewReport ("=" * 90) "Finish_Script" 1
    Log-ScriptEvent $NewReport "USERS_PROCESSED: $i" "Finish_Script" 1
    Log-ScriptEvent $NewReport "ACCOUNTS_MATCHED: $j" "Finish_Script" 1
    Log-ScriptEvent $NewReport "ACCOUNTS_CREATED_SUCCESS: $k" "Finish_Script" 1
    Log-ScriptEvent $NewReport "ACCOUNTS_CREATED_FAILURE: $m" "Finish_Script" 1
    Log-ScriptEvent $NewReport "BUILTIN_ACCOUNTS: $l" "Finish_Script" 1
    Log-ScriptEvent $NewReport ("=" * 90) "Finish_Script" 1


}   #End of if (New-Item -ItemType File -Path $NewReport)

else {

    #Write a custom error
    Write-Error "$NewReport not found. Script execution stopped."
    Exit 1

}   #End of else (New-Item -ItemType File -Path $NewReport)