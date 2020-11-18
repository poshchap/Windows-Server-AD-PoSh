##########################################################################################################
<#
.SYNOPSIS
    Dumps Users accounts for a domain
    
.DESCRIPTION
    Creates a date and time named XML backup of a domain's user accounts. Intended to be used with a sister
    script that can mirror the dumped OU structure to a test domain.

.EXAMPLE
    .\Dump_Users.ps1 -Domain halo.net

    Dumps the user accounts of the target domain, halo.net, to a date and time stamped XML file.

.EXAMPLE
    .\Dump_Users.ps1 -Domain halo.net -TargetOu "OU=Test Users,DC=halo,DC=net"

    Dumps the user accounts of the target OU, "Test Users", and subtree to a date and time stamped
    XML file.

.OUTPUTS
    Date and time stamped xml file, e.g. 150410093716_HALO_User_Dump.xml

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
      [parameter(Mandatory,Position=1)]
      [ValidateScript({Get-ADDomain -Identity $_})] 
      [String]$Domain,

      #Optional target OU 
      [parameter(Position=2)]
      [ValidateScript({Get-ADOrganizationalUnit -Identity $_})]
      [String]$TargetOu
      )


#Set strict mode to identify typographical errors (uncomment whilst editing script)
#Set-StrictMode -version Latest


##########################################################################################################

########
## Main
########

#Create a variable for the domain DN
$DomainDn = (Get-ADDomain -Identity $Domain).DistinguishedName

#Create a variable for the domain DN
$DomainNetbios = (Get-ADDomain -Identity $Domain).NetBIOSName

#Specify a XML report variable
$XmlReport = ".\$(Get-Date -Format yyMMddHHmmss)_$($DomainNetbios)_User_Dump.xml" 

#Create an array to  contain our custom PS objects
$TotalUsers = @()

#Create user counter
$i = 0

#Check for target OU
if ($TargetOu) {

    #Create splatted parameters for Get-ADuser command
    $Parameters = @{

        Filter = "*"
        SearchBase = $TargetOu
        SearchScope = "SubTree"
        Server = $Domain
        ErrorAction = "SilentlyContinue"

    }   #End of $Parameters

}   #End of if ($TargetOu)
else {

    #Create splatted parameters for Get-ADuser command
    $Parameters = @{

        Filter = "*"
        SearchScope = "SubTree"
        Server = $Domain
        ErrorAction = "SilentlyContinue"

    }   #End of $Parameters

}   #end of else ($TargetOu)

#Get a list of AD users
$Users = Get-ADUser @Parameters -Properties mail,ParentGuid,Description,DisplayName

if ($Users) {

    foreach ($User in $Users) {

        #Convert the parentGUID attribute (stored as a byte array) into a proper-job GUID
        $ParentGuid = ([GUID]$User.ParentGuid).Guid

        #Attempt to retrieve the object referenced by the parent GUID
        $ParentObject = Get-ADObject -Identity $ParentGuid -Server $Domain -ErrorAction SilentlyContinue

        #Check that we've retrieved the parent
        if ($ParentObject) {

            #Create a custom PS object
            $UserInfo = [PSCustomObject]@{

                GivenName = $User.GivenName
                Surname = $User.Surname
                Name = $User.Name
                SamAccountName = $User.SamAccountName
                DisplayName = $User.DisplayName
                mail = $User.mail
                Description = $User.Description
                UserDn = $User.DistinguishedName 
                ParentDn = $ParentObject.DistinguishedName
                DomainDn = $DomainDn
    
             }   #End of $UserInfo...


            #Add the object to our array
            $TotalUsers += $UserInfo

            #Spin up a progress bar for each filter processed
            Write-Progress -Activity "Finding users in $DomainDn" -Status "Processed: $i" -PercentComplete -1

            #Increment the filter counter
            $i++

        }   #end of if ($ParentObject)

    }   #end of foreach ($User in $Users)

}   #end if ($Users)


#Dump custom User info to XML file
Export-Clixml -Path $XmlReport -InputObject $TotalUsers

#Message to screen
Write-Host "User information dumped to $XmlReport" 