##########################################################################################################
<#
.SYNOPSIS
    Mirrors an XML dump of a source domain's groups to a target test domain.
    
.DESCRIPTION
    Creates groups contained in a backup XML file in a target domain. Does not create groups if 
    they already exist. Does not create groups if the parent OU does not already exist.
    
    Populates groups memberships. IMPORTANT: Foreign Security Principals won't be added.
    
    Intended to be used with a sister script that dumps the groups from a source domain.

    Logs all script actions to a date and time named log.

    Requirements:

        * PowerShell ActiveDirectory Module
        * An XML backup created by partner Dump_Groups.ps1 script
        * Trace32.exe (SMS Trace) or CMTrace.exe (Configuration Manager Trace Log Tool) to view script log

.EXAMPLE
    .\Mirror_Groups.ps1 -Domain contoso.com -BackupXml .\150410093716_HALO_Group_Dump.xml

    Creates the groups contained in the 150410093716_HALO_Group_Dump.xml backup file in the contoso.com
    domain. Does not create groups if they already exist. Does not create groups if the parent OU does not
    already exist.  

    Writes a log file of all script actions.

.EXAMPLE
    .\Mirror_Groups.ps1 -Domain contoso.com 
                        -BackupXml .\150410093716_HALO_Group_Dump.xml
                        -TargetOu "OU=Test Groups,DC=Halo,DC=Net"

    Creates the groups contained in the 150410093716_HALO_Group_Dump.xml backup file in the contoso.com
    domain. Creates groups in the 'Test Groups' OU. Does not create Groups if they already exist. Does not 
    create Groups if the target OU does not exist.

    Writes a log file of all script actions.

.OUTPUTS
    Date and time stamped log file, e.g. 150410110533_AD_Group_Mirror.log, for use with Trace32.exe (SMS Trace) 
    or CMTrace.exe (Configuration Manager Trace Log Tool)

    SMS Trace - http://www.microsoft.com/en-us/download/details.aspx?id=18153
    CM Trace - Installation directory on Configuration Manager 2012 Site Server - <Install Directory>\tools\


    EXIT CODES:  1 - Report file not found
                 2 - Custom XML Group file not found

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
$NewReport = ".\$(Get-Date -Format yyMMddHHmmss)_AD_Group_Mirror.log" 

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
    $GroupInfo = Import-Clixml -Path $BackupXml -ErrorAction SilentlyContinue

    #Make sure we have custom group info
    if ($GroupInfo) {

        #Log custom XML import success
        Log-ScriptEvent $NewReport "Custom Group objects successfully imported from $BackupXml" "Mirror_Groups" 1
        Log-ScriptEvent $NewReport " " " " 1 

        #Obtain the source domain DN from the first custom group object
        $SourceDomainDn = ($GroupInfo| Select -First 1).DomainDn

        #Create counters
        $i = 0    # groups processed
        $j = 0    # groups matched
        $k = 0    # groups created
        $l = 0    # group members processed
        $m = 0    # group creation failed
        $n = 0    # group members failed
        $o = 0    # groups processed (2)

        #Loop through each of the custom group objects
        foreach ($Group in $GroupInfo) {

            #Test that the group SamAccountName doesn't already exist
            try {$TargetGroupSAM = Get-ADGroup -Identity $Group.SamAccountName -Server $TargetDomainFqdn}
            catch {}

            #If we have a group then onwards...
            if ($TargetGroupSAM) {

                #Log that object exists
                Log-ScriptEvent $NewReport "SamAccountName - `"$(($Group).SamAccountName)`" - already exists in $Domain" "Mirror_Groups" 1
            
                #Increment group matched counter
                $j++

            }   #End of if ($TargetGroupSAM)

            else {

                #Log that object does not exist
                Log-ScriptEvent $NewReport "SamAccountName - `"$(($Group).SamAccountName)`" - does not exist in $Domain" "Mirror_Groups" 1

                #Test that the group Name doesn't already exist
                try{$TargetgroupName = Get-ADGroup -Identity $Group.Name -Server $TargetDomainFqdn}
                catch {}

                #If we have a group then onwards...
                if ($TargetgroupName) {

                    #Log that object exists
                    Log-ScriptEvent $NewReport "Group Name - `"$(($Group).Name)`" - already exists in $Domain" "Mirror_Groups" 1
            
                    #Increment group matched counter
                    $j++

                }   #End of if ($TargetgroupName)

                else {

                    #Log that object does not exist
                    Log-ScriptEvent $NewReport "Group Name - `"$(($Group).Name)`" - does not exist in $Domain" "Mirror_Groups" 1

                    #Update the managedBy attribute if it exists
                    if ($Group.managedBy) {

                        #Replace domain portion of DN
                        $ManagedBy = $Group.managedBy -replace $SourceDomainDn,$TargetDomainDn

                    }   #end of if ($Group.managedBy)

                    #Determine where we create the group
                    if ($TargetOu) {

                        #Log that we are using a parameter value as our target OU
                        Log-ScriptEvent $NewReport "Using supplied paramter - $TargetOu - as group parent OU" "Mirror_Groups" 1  
                    
                        #Attempt to create group in Target OU
                        $Newgroup = New-ADgroup -Name $Group.Name `                                                -GroupCategory $Group.GroupCategory `                                                -GroupScope $Group.GroupScope `                                                -SamAccountName $Group.SamAccountName `                                                -DisplayName $Group.DisplayName `                                                -Description $Group.Description `                                                -Path $TargetOu `                                                -ErrorAction SilentlyContinue

                        #Check the success of the New-ADgroup cmdlet
                        if ($?) {

                            #Log success of New-ADgroup cmdlet
                            Log-ScriptEvent $NewReport "Creation of `"$(($Group).SamAccountName)`" succeeded." "Mirror_Groups" 1
                            
                            #Increment group created counter
                            $k++


                        }   #End of if ($?)

                        else {

                            #Log failure of New-ADgroup cmdlet
                            Log-ScriptEvent $NewReport "Creation of `"$(($Group).SamAccountName)`" failed. $($Error[0].exception.message)" "Mirror_Groups" 3   

                            #Increment group creation failed counter
                            $m++


                        }   #End of else ($?)                      


                }   #End of if ($TargetOu)
                    else {

                        #Replace the domain DN with the target filter DN for our parent path
                        $TargetParentDn = $Group.ParentDn –Replace $SourceDomainDn,$TargetDomainDn

                        #Test that the parent exists
                        Try{$TargetParent = Get-ADObject -Identity $TargetParentDn -Server $TargetDomainFqdn}
                        Catch {}

                        #Check to see that the parent OU already exists
                        if ($TargetParent) {

                            #Log that object exists
                            Log-ScriptEvent $NewReport "`"$TargetParentDn`" parent already exists in $Domain" "Mirror_Groups" 1

                            #Attempt to create group in Target OU
                            $Newgroup = New-ADgroup -Name $Group.Name `                                                    -GroupCategory $Group.GroupCategory `                                                    -GroupScope $Group.GroupScope `                                                    -SamAccountName $Group.SamAccountName `                                                    -DisplayName $Group.DisplayName `                                                    -Description $Group.Description `                                                    -Path $TargetParentDn `                                                    -ErrorAction SilentlyContinue


                                #Check the success of the New-ADgroup cmdlet
                                if ($?) {

                                    #Log success of New-ADgroup cmdlet
                                    Log-ScriptEvent $NewReport "Creation of `"$(($Group).SamAccountName)`" succeeded." "Mirror_Groups" 1
                                
                                    #Increment group created counter
                                    $k++


                                }   #End of if ($?)

                                else {

                                    #Log failure of New-ADgroup cmdlet
                                    Log-ScriptEvent $NewReport "Creation of `"$(($Group).SamAccountName)`" failed. $($Error[0].exception.message)" "Mirror_Groups" 3 

                                    #Increment group creation failed counter
                                    $m++


                                }   #End of else ($?) 

                        }   #End of if ($TargetParent)
                        else {

                            #Log that object does not exist 
                            Log-ScriptEvent $NewReport "`"$TargetParentDn`" parent does not exist in $Domain... group creation will not be attempted" "Mirror_Groups" 1
                            Log-ScriptEvent $NewReport " " " " 1 

                        }   #End of else ($TargetParent)

                    }   #End of else ($TargetOu)

                }   #End of else ($TargetgroupName)

            }   #End of else ($TargetGroupSAM)


            #Spin up a progress bar for each filter processed
            Write-Progress -Activity "Mirroring Groups to $TargetDomainFqdn" -Status "Processed: $i" -PercentComplete -1

            #Increment the group processed counter
            $i++

            #Nullify key variables
            $TargetGroupSAM = $null
            $TargetGroupName = $null
            $TargetGroupDn = $null
            $TargetParent = $null


        }   #End of foreach($Group in $GroupInfo)

        #Now we need to loop through the groups again to process membership
        foreach ($Group in $GroupInfo) {

            #Replace the existing domain DN with the DN for group in the target domain
            $TargetGroupDn = $Group.GroupDn –Replace $SourceDomainDn,$TargetDomainDn

            #Spacer
            Log-ScriptEvent $NewReport " " " " 1 

            #Loop through the members attribute
            foreach ($Member in $Group.members) {
                
                #Replace the existing member DN with the DN for the member in the target domain
                $TargetMemberDn = $Member –Replace $SourceDomainDn,$TargetDomainDn

                #Attempt to add the member to the group
                $NewMember = Add-ADGroupMember -Identity $TargetGroupDn -Members $TargetMemberDn -Server $Domain -ErrorAction SilentlyContinue

                    #Check the success of the New-ADGroupMember cmdlet
                    if ($?) {

                        #Log success of New-ADGroupMember cmdlet
                        Log-ScriptEvent $NewReport "Addition of $TargetMemberDn to $TargetGroupDn succeeded." "Add_Members" 1 
                    
                        #Increment group addition counter
                        $l++


                    }   #End of if ($?)

                    else {

                        #Log failure of New-ADGroup cmdlet
                        Log-ScriptEvent $NewReport "Addition of $TargetMemberDn to $TargetGroupDn failed. $($Error[0].exception.message)" "Add-Members" 3   

                        #Increment group addition failed counter
                        $n++


                    }   #End of else ($?)

                    #Nullify variable
                    $TargetMemberDn = $null

            }   #End of foreach ($Member in $Group.members)            

            #Spin up a progress bar for each filter processed
            Write-Progress -Activity "Updating group membership in $TargetDomainFqdn" -Status "Groups processed: $o" -PercentComplete -1

            #Increment the group processed counter
            $o++

            #Nullify variable
            $TargetGroupDn = $null

        }   #End of foreach($Group in $GroupInfo)


    }   #End of if ($GroupInfo)

    else {

    #Log failure to import custom group XML object
    Log-ScriptEvent $NewReport "$BackupXml import failed" "Mirror_Groups" 3
    Log-ScriptEvent $NewReport "Script execution stopped" "Mirror_Groups" 1
    Log-ScriptEvent $NewReport ("=" * 90) "Mirror_Groups" 1
    Write-Error "$BackupXml not found. Script execution stopped."
    Exit 2

    }   #End of else ($GroupInfo)


    #Close of the script log
    Log-ScriptEvent $NewReport " " " " 1 
    Log-ScriptEvent $NewReport ("=" * 90) "Finish_Script" 1
    Log-ScriptEvent $NewReport "GROUPS_PROCESSED: $i" "Finish_Script" 1
    Log-ScriptEvent $NewReport "GROUPS_MATCHED: $j" "Finish_Script" 1
    Log-ScriptEvent $NewReport "GROUPS_CREATED_SUCCESS: $k" "Finish_Script" 1
    Log-ScriptEvent $NewReport "GROUPS_CREATED_FAILURE: $m" "Finish_Script" 1
    Log-ScriptEvent $NewReport "MEMBERS_ADDED_SUCCESS: $l" "Finish_Script" 1
    Log-ScriptEvent $NewReport "MEMBERS_ADDED_FAILURE: $n" "Finish_Script" 1
    Log-ScriptEvent $NewReport ("=" * 90) "Finish_Script" 1


}   #End of if (New-Item -ItemType File -Path $NewReport)

else {

    #Write a custom error
    Write-Error "$NewReport not found. Script execution stopped."
    Exit 1

}   #End of else (New-Item -ItemType File -Path $NewReport)