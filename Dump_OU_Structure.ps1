##########################################################################################################
<#
.SYNOPSIS
    Dumps the OU hierarchy of a domain to an XML file.
    
.DESCRIPTION
    Creates a date and time named XML backup of a domain's OU structure. Intended to be used with a sister
    script that can mirror the dumped OU structure to a test domain.

.EXAMPLE
    .\Dump_OU_Structure.ps1 -Domain halo.net

    Dumps the OU hierarchy of the target domain, halo.net, to a date and time stamped XML file.

.OUTPUTS
    Date and time stamped xml file, e.g. 150410093716_HALO_OU_Dump.xml

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
      [ValidateScript({Get-ADDomain $_})] 
      [String]$Domain
      )


#Set strict mode to identify typographical errors (uncomment whilst editing script)
#Set-StrictMode -version Latest


##########################################################################################################

########
## Main
########

#Craete a variable for the domain DN
$DomainDn = (Get-ADDomain -Identity $Domain).DistinguishedName

#Craete a variable for the domain DN
$DomainNetbios = (Get-ADDomain -Identity $Domain).NetBIOSName

#Specify a XML report variable
$CsvReport = ".\$(Get-Date -Format yyMMddHHmmss)_$($DomainNetbios)_OU_Dump.xml" 

#Create an array to  contain our custom PS objects
$TotalOus = @()

#Create user counter
$i = 0

#Get-ADOrganizationalUnit dumps the OU structure in a logical order (thank you cmdlet author!) 
$Ous = Get-ADOrganizationalUnit -Filter * -SearchScope Subtree -Server $Domain -Properties ParentGuid -ErrorAction SilentlyContinue | 
       Select Name,DistinguishedName,ParentGuid 

#Check that we have some output
if ($Ous) {

    #Loop through each OU, create a custom object and add to $TotalOUs
    foreach ($Ou in $Ous){

        #Convert the parentGUID attribute (stored as a byte array) into a proper-job GUID
        $ParentGuid = ([GUID]$Ou.ParentGuid).Guid

        #Attempt to retrieve the object referenced by the parent GUID
        $ParentObject = Get-ADObject -Identity $ParentGuid -Server $Domain -ErrorAction SilentlyContinue

        #Check that we've retrieved the parent
        if ($ParentObject) {

            #Create a custom PS object
            $OuInfo = [PSCustomObject]@{

                Name = $Ou.Name
                DistinguishedName = $Ou.DistinguishedName
                ParentDn = $ParentObject.DistinguishedName
                DomainDn = $DomainDn
        
             }   #End of $Properties...


            #Add the object to our array
            $TotalOus += $OuInfo

            #Spin up a progress bar for each filter processed
            Write-Progress -Activity "Finding OUs in $DomainDn" -Status "Processed: $i" -PercentComplete -1

            #Increment the filter counter
            $i++

        }   #End of if ($ParentObject)

    }   #End of foreach ($Ou in $Ous)


    #Dump custom OU info to XML file
    Export-Clixml -Path $CsvReport -InputObject $TotalOus

    #Message to screen
    Write-Host "OU information dumped to $CSVReport" 


}   #End of if ($Ous)
Else {

    #Write message to screen
    Write-Error -Message "Failed to retrieve OU information."


}   #End of else ($Ous)