##########################################################################################################
<#
.SYNOPSIS
    Find Active Directory Sites and Services server objects without NTDS Settings... 
     
.DESCRIPTION
    Reports on Active Directory server objects from the configuration partition. Lists server objects
    that have a child nTDSDSA object as well as writing a warning for server objects without a child
    nTDSDSA object.

.EXAMPLE
    .\Get-ADNtdsdsa

    Reports on server objects from the configuration partion for the forest in which the script is executed.
 
 .OUTPUT
    Sample output:

    SUCCESS: HALODC02 - CN=NTDS Settings,CN=HALODC02,CN=Servers,CN=Default-First-Site-Name,CN=Sites,CN=Configuration,DC=halo,DC=net
    SUCCESS: HALODC01 - CN=NTDS Settings,CN=HALODC01,CN=Servers,CN=Default-First-Site-Name,CN=Sites,CN=Configuration,DC=halo,DC=net
    WARNING: HALODC03 - no NTDS settings object detected!
    WARNING: HALODC04 - no NTDS settings object detected!

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

#Requires -version 3
#Requires -modules ActiveDirectory

#Authors: Ian Farr (MSFT)
#Version: 1.0


#Get the config partition DN
$Config = (Get-ADRootDSE).configurationNamingContext


#Use Get-ADObject to list server objects for current forest
$Servers = Get-ADObject -Filter {ObjectClass -eq "Server"} -SearchBase "CN=Sites,$Config" -SearchScope Subtree

#Loop through the list of servers
foreach ($Server in $Servers) {

    #Test for NTDS Settings object
    $Ntdsa = Get-ADObject -Filter {ObjectClass -eq "nTDSDSA"} -SearchBase "$(($Server).DistinguishedName)" -SearchScope Subtree

    #Check that we have an NTDS Settings object for our server
    if ($Ntdsa) {

        #Write to console
        Write-Host "SUCCESS`: $(($Server).Name) - $(($Ntdsa).DistinguishedName)"

    }   #end of if ($Ntdsa)
    else {
        
        #Write warning
        Write-Warning "$(($Server).Name) - no NTDS settings object detected!"


    }   #end of else ($Ntdsa)


}   #end of foreach ($Server in $Servers)
