##########################################################################################################
<#
.SYNOPSIS
    Obtains all conflict objects for a forest. Creates a CSV report of found conflict objects and 
    corresponding 'live' objects.
    
.DESCRIPTION
    Obtains all conflict objects for a forest along with the corresponding 'live' object (if the 'live'
    object exists). Returns the two sets of objects as a PS custom object containing the objects' 
    DistinguishedNames as well as their WhenChanged dates.
    
    Also creates a CSV report containing the same information.

.EXAMPLE
    Get-ADForestConflictObjects -Forest contoso.com

    Obtains all conflict objects for the contoso.com forest along with the corresponding 'live' object 
    (if the 'live' object exists). Returns the two sets of objects as a PS custom object containing
    the objects' DistinguishedNames as well as their WhenChanged dates.
    
    Also creates a date / time stamped CSV report, in the current directory, containing the 'conflict' /
    'live' information.

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

Function Get-ADForestConflictObjects {

    #Define and validate parameters
    [CmdletBinding()]
    Param(
          #The target domain
          [parameter(Mandatory,Position=1)]
          [ValidateScript({Get-ADForest -Server $_})] 
          [String]$Forest,

          #The target domain
          [Switch]$NonDomainParitions
          )
    

    #Specify a CSV report 
    $CsvReport = ".\$(Get-Date -Format yyMMddHHmmss)_AD_Conflict_Object_Report.csv" 
 
    #Add header to CSV Report 
    Add-Content -Value "CONFLICT_DN,CONFLICT_WHENCHANGED,LIVE_DN,LIVE_WHENCHANGED" -Path $CsvReport 


    #Determine the domains
    if ($NonDomainParitions) {

        #Get just the forest root name
        $Domains = (Get-ADForest -Server $Forest).Name

    }   #end of if
    else {
        
        #Get a list of domains
        $Domains = (Get-ADForest -Server $Forest).Domains

    }   #end of else


    #Pipe each domain in our forest into a loop to test for conflict objects
    $Domains | ForEach-Object {

        #Assign the domain to a variable to use in the next loop
        $DomainDn = (Get-ADDomain -Identity $_).DistinguishedName

        ######



        #COllect AD conflict objects
        $Objects = Get-ADObject -LDAPFilter "(|(cn=*\0ACNF:*)(ou=*CNF:*))" -Properties WhenChanged -Server $Domain 
        $Objects += Get-ADObject -LDAPFilter "(|(cn=*\0ACNF:*)(ou=*CNF:*))" -Properties WhenChanged -Server $Domain -Partition 

        #Get conflict objects
        Get-ADObject -LDAPFilter "(|(cn=*\0ACNF:*)(ou=*CNF:*))" -Properties WhenChanged -Server $Domain |
        ForEach-Object {
    
            #Nullify live object variables
            $LiveDN = $Null
            $LiveWhenChanged = $Null
            $LiveObject= $Null

            #Assign conflict object properties to variables
            $ConfDN = $_.DistinguishedName
            $ConfWhenChanged = $_.WhenChanged

            #See if we are dealing with a 'cn' conflict object
            if (Select-String -SimpleMatch "\0ACNF:" -InputObject $ConfDN) {
        
                #Split the conflict object DN so we can remove the conflict notation
                $SplitConfDN = $ConfDN -split "0ACNF:"

                #Remove the conflict notation from the DN and try to get the live AD object
                try {

                    $LiveObject = Get-ADObject -Identity "$($SplitConfDN[0].TrimEnd("\"))$($SplitConfDN[1].Substring(36))" -Properties WhenChanged -Server $Domain -erroraction Stop
                }
                catch{}

                #Check we have a live object
                if ($LiveObject) {

                    #Populate live object variable
                    $LiveDN = $LiveObject.DistinguishedName
                    $LiveWhenChanged = $LiveObject.WhenChanged

                }  
                else {
                    #Populate live object variable
                    $LiveDN= "N/A"
                    $LiveWhenChanged = "N/A"

                } #End of if ($LiveObject)

                     

            }   #end of if (Select-String -SimpleMatch "\0ACNF:" -InputObject $ConfDN)
            else {

                #Split the conflict object DN so we can remove the conflict notation for OUs
                $SplitConfDN = $ConfDN -split "CNF:"

                #Remove the conflict notation from the DN and try to get the live AD object
                $LiveObject = Get-ADObject -Identity "$($SplitConfDN[0])$($SplitCnfDN[1].Substring(36))" -Properties WhenChanged -Server $Domain

                #Check we have a live object
                if ($LiveObject) {

                    #Populate live object variable
                    $LiveDN = $LiveObject.DistinguishedName
                    $LiveWhenChanged = $LiveObject.WhenChanged

                }   #End of if ($LiveObject)


            }   #End of else (Select-String -SimpleMatch "\0ACNF:" -InputObject $ConfDN)


            #Add findings to a CSV report
            Add-Content -Value "`"$ConfDN`",$ConfWhenChanged,`"$LiveDN`",$LiveWhenChanged" -Path $CsvReport

            #Create a custom PSObject with our collected information
            $ConflictObject = [PSCustomObject]@{

                ConflictDn = $ConfDN
                ConflictWhenChanged = $ConfWhenChanged
                LiveDn = $LiveDN
                LiveWhenChanged = $LiveWhenChanged
        
            }   #End of $ConflictObject 


            #Return the custom object
            $ConflictObject


        }   #End of ForEach-Object

    }   #End of ForEach-Object

}   #End of Function Get-ADForestConflictObjects
