##########################################################################################################
<#
.SYNOPSIS
    Imports all GPOs from a backup folder into a test domain. Additional GPO information can be imported.

.DESCRIPTION
    The script is intended to import backed up GPOs to a test domain. For the additional GPO information
    functionality, a backup created by the partner BackUp_GPOs script should be used.

    Details:
    * Can use a Migration Table to translate domain specific information
    * Can import SOM (Scope of Management) Path, Block Inheritance, Link Enabled, Link Order and Enforced
      settings
    * Can import and link WMI filters
    * If set by the script, 'Block Inheritance' and 'Enforced' settings are highlighted as warnings (yellow) 
      in the script log

    Requirements:
    * PowerShell GroupPolicy Module
    * PowerShell ActiveDirectory Module
    * A backup created by partner BackUp_GPOs.ps1 script
    * Trace32.exe (SMS Trace) or CMTrace.exe (Configuration Manager Trace Log Tool) to view script log
    * SOM paths, e.g. OU heirachy, in target domain matches source domain to reinstate additional information

.EXAMPLE
   .\Import_GPOs.ps1 -Domain northwindtraders.com -BackupFolder "\\corpdc01\backups\"

   This will import all backed-up GPOs from \\corpdc01\backups into the northwindtraders domain.
   No additional GPO infomation is imported.

.EXAMPLE
   .\Import_GPOs.ps1 -Domain fabrikam.com -BackupFolder "d:\backups" -MigTable

   This will import all backed-up GPOs from d:\backups into the fabrikam domain.
   The import will look for a migration table in the backup folder and attempt to translate the values.

.EXAMPLE
   .\Import_GPOs.ps1 -Domain northwindtraders.com -BackupFolder "\\corpdc01\backups\" -SomInfo

   This will import all backed-up GPOs from \\corpdc01\backups into the northwindtraders domain.
   The import will attempt to recreate GPO links and their precedence. Block Inheritance and Enforced
   details will also be restored, if possible.

.EXAMPLE
   .\Import_GPOs.ps1 -Domain northwindtraders.com -BackupFolder "\\corpdc02\backups\" -WmiFilter

   This will import all backed-up GPOs from \\corpdc02\backups into the northwindtraders domain.
   The import will attempt to recreate WMI filters and link them to matching policies.

.EXAMPLE
   .\Import_GPOs.ps1 -Domain fabrikam.com -BackupFolder "d:\backups" -MigTable -SomInfo -WMiFilter

   This will import all backed-up GPOs from d:\backups into the fabrikam domain.
   The import will look for a migration table in the backup folder and attempt to translate the values.
   The import will also attempt to recreate GPO links and their precedence. Block Inheritance and Enforced
   details will also be restored, if possible. The import will attempt to recreate WMI filters and link 
   them to matching policies.

.OUTPUTS
   Time and date stamped import log for use with Trace32.exe (SMS Trace) or CMTrace.exe (Configuration Manager Trace Log Tool)

   SMS Trace - http://www.microsoft.com/en-us/download/details.aspx?id=18153
   CM Trace - Installation directory on Configuration Manager 2012 Site Server - <Install Directory>\tools\


   EXIT CODES:  1 - Report file not found
                2 - Custom GPO XML file not found
                3 - Migration file not found

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
#Requires -modules ActiveDirectory,GroupPolicy

#Version: 2.0

#Define and validate parameters
[CmdletBinding()]
Param(
      #The target domain
      [parameter(Mandatory=$True,Position=1)]
      [ValidateScript({Get-ADDomain -Identity $_})] 
      [String]$Domain,

      #The source backup folder (use full path)
      [parameter(Mandatory=$True,Position=2)]
      [ValidateScript({Test-Path -Path $_})]
      [String]$BackupFolder,

      # Whether to reference a migration table
      [Switch] 
      $MigTable,

      # Whether to import SOM information
      [Switch] 
      $SomInfo,

      # Whether to import WMI filter information
      [Switch] 
      $WmiFilter
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
      [String]$NewReport,

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
#Create the line to be logged$LogLine =  "<![LOG[$Value]LOG]!>" +`            "<time=`"$(Get-Date -Format HH:mm:ss).000+0`" " +`            "date=`"$(Get-Date -Format M-d-yyyy)`" " +`            "component=`"$Component`" " +` 
            "context=`"`" " +`            "type=`"$Severity`" " +`            "thread=`"1`" " +`            "file=`"`">"

#Write the line to the passed log file
Add-Content -Path $NewReport -Value $LogLine

}


##########################################################################################################

########
## Main
########

#Create a variable to represent a new script log, constructing the report name from date details
$SourceParent = (Get-Location).Path
$Date = Get-Date #-Format yyMMddhhss
$NewReport = "$SourceParent\" + `             "$($Date.Year)" + `             "$("{0:D2}" -f $Date.Month)" + `             "$("{0:D2}" -f $Date.Day)" + `             "$("{0:D2}" -f $Date.Hour)" + `             "$("{0:D2}" -f $Date.Minute)" + `             "$("{0:D2}" -f $Date.Second)" + `
             "_GPO_Import.log"



#Make sure the script log has been created
If (New-Item -ItemType File -Path $NewReport) {

    ##Start writing to the script log (Start_Script)
    Log-ScriptEvent $NewReport ("=" * 90) "Start-Script" 1
    Log-ScriptEvent $NewReport "TARGET_DOMAIN: $Domain" "Start_Script" 1
    Log-ScriptEvent $NewReport "BACKUP_SOURCE: $BackupFolder" "Start_Script" 1
    Log-ScriptEvent $NewReport "MIGRATION_TABLE: $MigTable" "Start_Script" 1
    Log-ScriptEvent $NewReport "SOM_INFO: $SomInfo" "Start_Script" 1
    Log-ScriptEvent $NewReport "WMI_FILTERS: $WmiFilter" "Start_Script" 1
    Log-ScriptEvent $NewReport ("=" * 90) "Start_Script" 1
    Log-ScriptEvent $NewReport " " " " 1



    ##Define variables used throughout the script sections
    #Instantiate an object for the target domain
    $TargetDomain = Get-ADDomain $Domain

    #Obtain the target domain FQDN
    $TargetDomainFQDN = $TargetDomain.DNSRoot

    #Obtain the target domain DN
    $TargetDomainDN = $TargetDomain.DistinguishedName

    #Obtain the target domain PDCe
    $TargetPDC = $TargetDomain.PDCEmulator

    #Create a variable for the Custom GPO XML file
    $CustomGpoXML = "$BackupFolder\GpoDetails.xml"

    #Import the custom GPO information contained in the XML file
    $CustomGpoInfo = Import-Clixml -Path $CustomGpoXML

    #Obtain the source domain DN from the first custom GPO object
    $SourceDomainDN = ($CustomGpoInfo | Select -First 1).DomainDN



    ##################################
    ###Section 1 - Import WMI filters
    ##Create or update WMI filters in Active Directory if the -WmiFilter switch is specified (Import_WMI)
    #Make sure we have custom GPO info
    If ($CustomGpoInfo) {

        #Log custom GPO import success
        Log-ScriptEvent $NewReport "Custom GPO objects successfully imported from $CustomGpoXML" "Import_GPOs" 1
        Log-ScriptEvent $NewReport " " " " 1

        #Check whether the WMI filters should be imported
        If ($WmiFilter) {

            #Create a variable for the XML file representing the WMI filters
            $WmiXML = "$BackupFolder\WmiFilters.xml"


            #Import the WMI filter information contained in the XML file
            $WmiFilters = Import-Clixml -Path $WmiXML


            #Make sure we have WMI filter information
            If ($WmiFilters) {

                #Log WMI filter XML import success
                Log-ScriptEvent $NewReport "WMI f$Tailter objects successfully imported from $WmiXML" "Import_WMI" 1


                #Create a filter counter
                $k = 0

                #Loop through each of the WMI filters
                ForEach ($WMI in $WmiFilters) {

                    #Replace the domain DN with the target filter DN
                    $TargetWmiDN = $WMI.DistinguishedName –Replace $SourceDomainDN, $TargetDomainDN


                    #Ensure that the msWMI-Parm1 property (the WMI Filter Description in the GUI) is populated
                    If (!($WMI."msWMI-Parm1")) {

                        #Set the description as a single space to avoid an error
                        $Parm1 = " "


                    }   #End of If (!($WMI."msWMI-Parm1"))
                     
                    Else {

                        #Use the current filter's description property
                        $Parm1 = $WMI."msWMI-Parm1"


                    }   #End of Else (!($WMI."msWMI-Parm1"))


                    #Test that the WMI filter doesn't already exist
                    $TargetWMI = (Get-ADObject -Identity $TargetWmiDN -Server $TargetPDC -ErrorAction SilentlyContinue)


                    #If the object already exists then just update it
                    If ($TargetWMI) {

                        #Log that object exists
                        Log-ScriptEvent $NewReport "`"$($WMI."msWMI-Name") - $($WMI."msWMI-ID")`" already exists in $Domain - attempting to update..." "Import_WMI" 1
                        
                        #Define properties to be passed to Set-ADObject
                        $Properties = [Ordered]@{

                            "msWMI-Author" = $WMI."msWMI-Author"
                            "msWMI-ChangeDate" = "$(Get-Date -Format yyyyMMddhhmmss).706000-000"
                            "msWMI-ID" = $WMI."msWMI-ID"  
                            "msWMI-Name" = $WMI."msWMI-Name"
                            "msWMI-Parm1" = $Parm1
                            "msWMI-Parm2" = $WMI."msWMI-Parm2"


                        }   #End of $Properties

                        
                        #Update the AD object
                        $UpdateWmiFilter = Set-ADObject -Identity $TargetWmiDN -Replace $Properties -Server $TargetPDC -ErrorAction SilentlyContinue


                            #Check the success of the Set-ADObject cmdlet
                            If ($?) {

                                #Log success of Set-ADObject cmdlet
                                Log-ScriptEvent $NewReport "Update of `"$($WMI."msWMI-Name") - $($WMI."msWMI-ID")`" succeeded." "Import_WMI" 1   


                            }   #End of If ($?)

                            Else {

                                #Log failure of Set-ADObject cmdlet
                                Log-ScriptEvent $NewReport "Update of `"$($WMI."msWMI-Name") - $($WMI."msWMI-ID")`" failed. $($Error[0].exception.message)" "Import_WMI" 3   

                            }   #End of Else ($?)

                    }   #End of If ($TargetWMI)

                    Else {

                        #Log that object does not exist
                        Log-ScriptEvent $NewReport "`"$($WMI."msWMI-Name") - $($WMI."msWMI-ID")`" does not exist in $Domain - attempting to create..." "Import_WMI" 1

                        #Define properties to be passed to Set-ADObject
                        $Properties = [Ordered]@{

                            "msWMI-Author" = $WMI."msWMI-Author"
                            "msWMI-ChangeDate" = "$(Get-Date -Format yyyyMMddhhmmss).706000-000"
                            "msWMI-CreationDate" = "$(Get-Date -Format yyyyMMddhhmmss).706000-000"
                            "msWMI-ID" = $WMI."msWMI-ID"  
                            "msWMI-Name" = $WMI."msWMI-Name"
                            "msWMI-Parm1" = $Parm1
                            "msWMI-Parm2" = $WMI."msWMI-Parm2"
                        }   #End of $Properties


                        #Create the AD object
                        $NewWmiFilter = New-ADObject -Name $WMI."msWMI-ID" -Type $WMI.ObjectClass `                                                     -Path "CN=SOM,CN=WMIPolicy,CN=System,$TargetDomainDN" `                                                     -OtherAttributes $Properties `                                                     -Server $TargetPDC `                                                     -ErrorAction SilentlyContinue

                            #Check the success of the New-ADObject cmdlet
                            If ($?) {

                                #Log success of New-ADObject cmdlet
                                Log-ScriptEvent $NewReport "Creation of `"$($WMI."msWMI-Name") - $($WMI."msWMI-ID")`" succeeded." "Import_WMI" 1   


                            }   #End of If ($?)

                            Else {

                                #Log failure of New-ADObject cmdlet
                                Log-ScriptEvent $NewReport "`"$($WMI."msWMI-Name") - $($WMI."msWMI-ID")`" failed. $($Error[0].exception.message)" "Import_WMI" 3   


                            }   #End of Else (?)


                    }   #End of Else ($TargetWMI)


                    #Spin up a progress bar for each filter processed
                    Write-Progress -activity "Importing WMI filters to $TargetDomainFQDN" -status "Processed: $k" -percentcomplete -1

                    #Increment the filter counter
                    $k++

                }   #End of ForEach ($WMI in $WmiFilters)


            }   #End of If ($WmiFilters)

            Else {

                #Log WMI filter XML import failure
                Log-ScriptEvent $NewReport "WMI filter objects import failed from $WmiXML" "Import_WMI" 3


            }   #End of Else ($WmiFilters)


        }   #End of If ($WmiFilter)


        #####################################
        ###Section 2 - Import backed up GPOs 
        ##Perform a standard Import-GPO with or without a Migration Table (Import_GPOs)
        #A counter for each GPO processed 
        $i = 0


        #Loop through each Custom GPO object from the custom GPO array
        ForEach ($CustomGpo in $CustomGpoInfo) {
            
            #Log current GPO name
            Log-ScriptEvent $NewReport " " " " 1
            Log-ScriptEvent $NewReport "Processing policy - $($CustomGpo.Name)..." "Import_GPOs" 1
            

            #Check whether we're using a migration table for the GPO import
            If ($MigTable) {
                
                #Create a variable for the migration table
                $MigrationFile = "$BackupFolder\MigrationTable.migtable"


                #Check that a migration table has been created by the backup script
                If (Test-Path -Path $MigrationFile) {
                
                    #Log migration check
                    Log-ScriptEvent $NewReport "The import is referencing $MigrationFile" "Import_GPOs" 1


                    #Import all the GPOs referenced in the backup folder with a migration table
                    $ImportedGpo = Import-GPO -BackupId $CustomGpo.BackupGuid `                                              -Path $BackupFolder `
                                              -CreateIfNeeded `                                              -Domain $TargetDomainFQDN `                                              -TargetName $CustomGpo.Name `
                                              -MigrationTable $MigrationFile `
                                              -Server $TargetPDC `
                                              -ErrorAction SilentlyContinue

                
                        #Log the outcome of $ImportedGpo
                        If ($?) {

                            Log-ScriptEvent $NewReport "Import of $($CustomGpo.Name) successful" "Import_GPOs" 1
                            Log-ScriptEvent $NewReport "$($CustomGpo.Name) has guid - $($ImportedGpo.Id)" "Import_GPOs" 1
                
                        }   #End of If ($?)...

                        Else {

                            Log-ScriptEvent $NewReport "Import of $($CustomGpo.Name) failed. $($Error[0].exception.message)" "Import_GPOs" 3             

                        }   #End of Else ($?)...


                }   #End of If (Test-Path -Path $MigrationFile)...

                Else {
                    
                    #Record that the migration table isn't present and exit
                    Log-ScriptEvent $NewReport "$MigrationFile not found. " "Import_GPOs" 3
                    Log-ScriptEvent $NewReport "Script execution stopped" "Import_GPOs" 1
                    Log-ScriptEvent $NewReport ("=" * 90) "Import_GPOs" 1
                    Write-Error "$MigrationFile not found. Script execution stopped."
                    Exit 3


                }   #End of Else (Test-Path -Path $MigrationFile)...


            }   #End of If ($MigTable)...

            Else {

                #Import all the GPOs referenced in the backup folder
                $ImportedGpo = Import-GPO -BackupId $CustomGpo.BackupGuid `                                          -Path $BackupFolder `
                                          -CreateIfNeeded `                                          -Domain $TargetDomainFQDN `                                          -TargetName $CustomGpo.Name `
                                          -Server $TargetPDC `
                                          -ErrorAction SilentlyContinue


                    #Log the outcome of $ImportedGpo
                    If ($?) {

                        Log-ScriptEvent $NewReport "Import of $($CustomGpo.Name) successful" "Import_GPOs" 1
                        Log-ScriptEvent $NewReport "$($CustomGpo.Name) has guid - $($ImportedGpo.Id)" "Import_GPOs" 1
                
                    }   #End of If ($?)...

                    Else {

                        Log-ScriptEvent $NewReport "Import of $($CustomGpo.Name) failed. $($Error[0].exception.message)" "Import_GPOs" 3             

                    }   #End of Else ($?)...


            }   #End of Else ($MigTable)...



            ################################
            ###Section 3 - Link WMI filters
            ##Link previously updated WMI filters to GPOs (Update_WMI)
            #Check whether the a -WmiFilter switch was supplied at script execution
            If ($WmiFilter) {

                #Check whether the current GPO custom object has a WMI filter associated
                If ($CustomGpo.WmiFilter) {

                    #Log filter found
                    Log-ScriptEvent $NewReport "Found filter entry: $($CustomGpo.WmiFilter)" "Update_WMI" 1


                    ##Check that the associated filter exists in the target doamin
                    #Contruct the target WMI DN
                    $TargetWmiDN = "CN=$($CustomGpo.WmiFilter),CN=SOM,CN=WMIPolicy,CN=System,$TargetDomainDN"

                    #Test that the WMI filter exists
                    $TargetWMI = Get-ADObject -Identity $TargetWmiDN -Property "msWMI-Name" -Server $TargetPDC -ErrorAction SilentlyContinue


                    #If the object already exists then link it to the current GPO
                    If ($TargetWMI) {

                        #Log that WMI object exists
                        Log-ScriptEvent $NewReport "`"$($TargetWMI."msWMI-Name") - $($TargetWMI.Name)`" WMI filter already exists in $Domain" "Update_WMI" 1


                        ##We'll have to update an attribute on the GPO object in AD
                        #Contruct the target GPO DN
                        $TargetGpoDN = "CN={$($ImportedGpo.Id)},CN=Policies,CN=System,$TargetDomainDN"

                        #Update the GPO attribute in AD
                        $UpdateGpoFilter = Set-ADObject $TargetGpoDN -Replace @{gPCWQLFilter = "[$TargetDomainFQDN;$($TargetWMI.Name);0]"} -Server $TargetPDC -ErrorAction SilentlyContinue


                            #Check the success of the Set-ADObject cmdlet
                            If ($?) {

                                #Log success of Set-ADObject cmdlet
                                Log-ScriptEvent $NewReport "Link of `"$($TargetWMI."msWMI-Name") - $($TargetWMI.Name)`" to $TargetGpoDN succeeded." "Update_WMI" 1   


                            }   #End of If ($?)

                            Else {

                                #Log failure of Set-ADObject cmdlet
                                Log-ScriptEvent $NewReport "Link of `"$($TargetWMI."msWMI-Name") - $($TargetWMI.Name)`" to $TargetGpoDN failed. $($Error[0].exception.message)" "Update_WMI" 3   


                            }   #End of Else (?)


                    }   #End of If ($TargetWMI)

                    Else {

                        #Log that WMI object does not exist
                        Log-ScriptEvent $NewReport "`"$($TargetWMI."msWMI-Name") - $($TargetWMI.Name)`" WMI filter does not exist in $Domain" "Update_WMI" 3


                    }   #End of Else ($TargetWMI)
                        

                }   #End of If ($CustomGpo.WmiFilter)


            }   #End of If ($WmiFilter) 



            ###############################
            ###Section 4 - Create GPO links
            ##Creating the necessary GPO links is a two part process.. part one ensures that the GPO links are present (Create_Links)
            #Check whether the -SomInfo switch was supplied at script execution
            If ($SomInfo) {


                #Check whether the GPO has any SOM information
                If ($CustomGpo.SOMs) {
                    
                    #Get a list of any associated SOMs
                    $SOMs = $CustomGpo | Select-Object -ExpandProperty SOMs


                    #Log SOMs found
                    Log-ScriptEvent $NewReport "Found SOM entries: $SOMs" "Create_Links" 1


                    #Loop through each SOM and associate it with a target
                    ForEach ($SOM in $SOMs) {

                        #Get the DN part from the SOM entry
                        $SomDN = ($SOM –Split ":")[0] 


                        #Replace the domain DNs
                        $SomDN = $SomDN –Replace $SourceDomainDN, $TargetDomainDN

                        
                        #Log SOM DN update
                        Log-ScriptEvent $NewReport "SOM DN set as $SomDN" "Create_Links" 1


                        #Check the SOM target exists
                        $TargetSom = Get-ADObject -Identity $SomDn -Server $TargetPDC -ErrorAction SilentlyContinue

                        If ($?) {

                            #Log confirmation of SOM target
                            Log-ScriptEvent $NewReport "$SomDn exists in target domain" "Create_Links" 1


                            #Create a corresponding SOM link
                            $SomLink = New-GPLink -Guid $ImportedGpo.Id -Domain $TargetDomainFQDN -Target $SomDN -Server $TargetPDC -ErrorAction SilentlyContinue


                                #Log the outcome of $SomLink
                                If ($?) {

                                    Log-ScriptEvent $NewReport "GPO Link created for $($ImportedGPO.Id) at $SomDn" "Create_Links" 1
                
                                }   #End of If ($?)...

                                Else {

                                    Log-ScriptEvent $NewReport "Creation of GPO link at $SomDn failed. $($Error[0].exception.message)" "Create_Links" 3             

                                }   #End of Else ($?)...


                        }   #End of If ($?) ($TargetSom)...

                        Else {

                            #Log failure to verify SOM target
                            Log-ScriptEvent $NewReport "$SomDn does not exist in target domain" "Create_Links" 3


                        }   #End of Else ($?)...


                    }   #End of ForEach ($SOM in $SOMs)...


                }   #End of If ($CustomGpo.SOMs)...

                #Add the GPO guid from the new domain to our custom GPO information
                $CustomGpo | Add-Member -MemberType NoteProperty -Name NewGpoGuid -Value $ImportedGpo.Id


            }   #End of If ($SomInfo)...

            #Spin up a progress bar for each GPO processed
            Write-Progress -activity "Importing Group Policies to $TargetDomainFQDN" -status "Processed: $i" -percentcomplete -1


            #Increment the GPO processed counter
            $i++


        }   #End of ForEach ($CustomGpo in $CustomGpoInfo)...



        ##################################
        ###Section 5 - Configure GPO Links
        ##This is part two of the SOM / GPO link creation process (Update_Links)
        #Check whether the -SomInfo switch was supplied at script execution
        If ($SomInfo) {

            #A counter for each GPO linked
            $j = 0

 
            #We need to loop through $CustomGPOInfo again and set enabled status and precendence on GPO links
            ForEach ($CustomGpo in $CustomGpoInfo) {           

                #Check whether the GPO has any SOM information
                If ($CustomGpo.SOMs) {

                #Log current GPO name
                Log-ScriptEvent $NewReport " " " " 1
                Log-ScriptEvent $NewReport "Processing GPO link updates for $($CustomGpo.Name)..." "Update_Links" 1
            

                    #Get a list of any associated SOMs
                    $SOMs = $CustomGpo | Select -ExpandProperty SOMs


                    #Loop through each SOM and associate it with a target
                    ForEach ($SOM in $SOMs) {

                        #Get the DN part from the SOM entry
                        $SomDN = ($SOM -Split ":")[0]


                        #Replace the domain DNs
                        $SomDN = $SomDN –Replace $SourceDomainDN, $TargetDomainDN


                        #Check the SOM target exists
                        $TargetSom = Get-ADObject -Identity $SomDn -Server $TargetPDC -ErrorAction SilentlyContinue

                        If ($?) {

                            #Determine the GPO link status of the SOM entry
                            Switch ($SOM.Split(":")[2]) {

                                $True {

                                    #Set the GPO link enabled variable to Yes
                                    $LinkEnabled = "Yes"


                                }   #End of $True

                                $False {

                                    #Set the GPO link enabled variable to No
                                    $LinkEnabled = "No"

                                }   #End of $False

                            }   #End of Switch ($SOM.Split(":")[2])


                            #Get the GPO link order part of the SOM entry
                            $LinkOrder = $SOM.Split(":")[3]


                                #Determine the GPO enforced status of the SOM entry
                                Switch ($SOM.Split(":")[4]) {

                                    $True {

                                        #Set the GPO link enabled variable to Yes
                                        $LinkEnforced = "Yes"


                                    }   #End of $True

                                    $False {

                                        #Set the GPO link enabled variable to No
                                        $LinkEnforced = "No"

                                    }   #End of $False

                                }   #End of Switch ($SOM.Split(":")[4])


                            #The SOM link has already been created, so now set the 'enabled', 'order' and 'enforced' properties
                            $SomLink = Set-GPLink -Guid $CustomGpo.NewGpoGuid `                                                  -Domain $TargetDomainFQDN `                                                  -Target $SomDN `                                                  -LinkEnabled $LinkEnabled `                                                  -Order $LinkOrder `                                                  -Enforced $LinkEnforced `
                                                  -Server $TargetPDC `
                                                  -ErrorAction SilentlyContinue


                            #Log the outcome of $SomLink
                            If ($?) {
                                
                                #Log $SomLink success details
                                Log-ScriptEvent $NewReport "GPO link updated for $($ImportedGPO.Id) at $SomDn" "Update_Links" 1
                                
                                #Log an Enforced entry as a warning (severity 2)
                                If ($LinkEnforced -eq "Yes") {

                                    #Log with severity 2
                                    Log-ScriptEvent $NewReport "GPO link set to `"Enabled: $LinkEnabled`" `"Order: $LinkOrder`" `"ENFORCED: $($LinkEnforced.ToUpper())`"" "Update_Links" 2

                                }   #End of If ($LinkEnforced -eq "Yes")

                                Else {

                                    #Log with severity 1
                                    Log-ScriptEvent $NewReport "GPO link set to `"Enabled: $LinkEnabled`" `"Order: $LinkOrder`" `"Enforced: $LinkEnforced`"" "Update_Links" 1


                                }   #End of Else ($LinkEnforced -eq "Yes")

                                
                                #Increment the GPO linked counter
                                $j++

                
                            }   #End of If ($?) ($SomLink)...

                            Else {

                                #Log $SomLink failure details
                                Log-ScriptEvent $NewReport "Creation of GPO link at $SomDn failed. $($Error[0].exception.message)" "Update_Links" 3             

                            }   #End of Else ($?) ($SomLink)...


                            #Get the block inheritance part of the SOM entry
                            $SomInheritance = $SOM.Split(":")[1]


                            #Check if we need should set Block Inheritance
                            If ($SomInheritance -eq $True) {

                                #Set block inheritance
                                $SetInheritance = Set-GPInheritance -Target $SomDn -IsBlocked Yes -Server $TargetPDC -ErrorAction SilentlyContinue

                                If ($?) {

                                #Log failure to set block inheritance
                                Log-ScriptEvent $NewReport "BLOCK INHERITANCE set on $SomDn" "Update_Links" 2
                                    

                                }   #End of If ($?) ($SetInheritance)...

                                Else {

                                    #Log failure to set block inheritance
                                    Log-ScriptEvent $NewReport "Can not set Block Inheritance on $SomDn" "Update_Links" 3


                                }   #End of Else ($?) ($SetInheritance)...
                                 

                            }   #End of If ($SomInheritance -eq $True)...


                        }   # End of If ($?) ($TargetSom)...

                        Else {

                            #Log failure to verify SOM target
                            Log-ScriptEvent $NewReport "$SomDn does not exist in target domain" "Update_Links" 3


                        }   # End of Else ($?) ($TargetSom)...


                    }   #End of ForEach ($SOM in $SOMs)...


                }   #End of If ($CustomGpo.SOMs)


            #Spin up a progress bar for each GPO processed
            Write-Progress -activity "Linking Group Policies to $TargetDomainFQDN" -status "Processed: $j" -percentcomplete -1


            }   #End of ForEach ($CustomGpo in $CustomGpoInfo)...


        }   #End of If ($SomInfo)...


    }   #End of If ($CustomGpoInfo)...

    Else {

    #Log failure to import custom GPO XML object
    Log-ScriptEvent $NewReport "$CustomGpoXML import failed" "Import_GPOs" 3
    Log-ScriptEvent $NewReport "Script execution stopped" "Import_GPOs" 1
    Log-ScriptEvent $NewReport ("=" * 90) "Import_GPOs" 1
    Write-Error "$CustomGpoXML not found. Script execution stopped."
    Exit 2

    }   #End of Else ($CustomGpoInfo)...

    ##Finish Script (Finish_Script)
    #Close of the script log
    Log-ScriptEvent $NewReport " " " " 1 
    Log-ScriptEvent $NewReport ("=" * 90) "Finish_Script" 1
    Log-ScriptEvent $NewReport "FILTERS_IMPORTED: $k" "Finish_Script" 1
    Log-ScriptEvent $NewReport "POLICIES_PROCESSED: $i" "Finish_Script" 1
    Log-ScriptEvent $NewReport "LINKS_UPDATED: $j" "Finish_Script" 1
    Log-ScriptEvent $NewReport ("=" * 90) "Finish_Script" 1


}   #End of If (New-Item -ItemType File -Path $NewReport)...

Else {

    #Write a custom error and use continue to override silently continue
    Write-Error "$NewReport not found. Script execution stopped."
    Exit 1

}   #End of Else (New-Item -ItemType File -Path $NewReport)...