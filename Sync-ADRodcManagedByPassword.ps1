Function Sync-ADRodcManagedByPassword {

##########################################################################################################
<#
.SYNOPSIS
   Uses the Sync-ADObject cmdlet to prepopulate passwords to an RODC

.DESCRIPTION
   Gets the ManagedBy attribute for an RODC. Checks if the ManagedBy attribute is populated or is empty. 
   If the ManagedBy principal is a group (best practice) it will enumerate group membership, otherwise 
   the assigned user is captured. Will then prepopulate the passwords for each ManagedBy group member or 
   a single ManagedBy user to the RODC.

.EXAMPLE
   Get-ADDomainController -Filter {IsReadOnly -eq $True} | Sync-ADRodcManagedByPassword

   Finds all of the RODCs for the domain that the user is currently logged on to and then pipes this into
   the function to prepopulate passwords for security principals from each RODC's ManagedBy attribute.

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

    #Define and validate parameters
    [CmdletBinding()]
    Param(
          #The target DistinguishedName
          [parameter(Mandatory,Position=1,ValueFromPipeline)]
          [ValidateScript({(Get-ADDomainController -Identity $_).IsReadOnly})] 
          [String]$Rodc
          )
    
    #Process each value supplied by the pipeline
    Process {

        #Get a computer account object for the current RODC
        $ManagedByPrincipal= Get-ADComputer -Identity $Rodc -Property ManagedBy | ForEach-Object {Get-ADObject -Identity $_.ManagedBy}
        

        #Check that ManagedByPrincipal is populated 
        If ($ManagedByPrincipal -eq $Null) {

            #Write a message to the host
            Write-Host "$Rodc does not have the ManagedBy attribute set"


        }   #End of If ($ManagedByPrincipal)
         
        Else {

            #Check that $Principal is a user or group
            If (($ManagedByPrincipal.ObjectClass-ne "user") -and ($ManagedByPrincipal.ObjectClass -ne "group")) {

                #Write a message to the host
                Write-Host "$ManagedByPrincipal is not a user or group"

            }   #End of If (($ManagedByPrincipal.ObjectClass-ne "user") -and ($ManagedByPrincipal.ObjectClass -ne "group"))

            Else {

                #Test whether the ManagedBy entry relates to a group or user
                Switch ($ManagedByPrincipal.ObjectClass) {

                    "group" {

                        #Hold the enumerated ManagedBy group members in $Principals
                        $Principals = Get-ADGroupMember -Identity $ManagedByPrincipal -Recursive 

                    }   #End of "group"


                    "user" {

                        #Hold single ManagedBy principal in $Principals (user object)
                        $Principals = $ManagedByPrincipal

                    }   #End of "user"
                

                }   #End of Switch


                #Get an AD object for each principal and sync the password
                $Principals | ForEach-Object {

                        #HERE'S THE PASSWORD PREPOPULATION BIT!
                        Get-ADObject -Identity $_.distinguishedName |
                        Sync-ADObject -Destination $Rodc -PasswordOnly -PassThru


                    }   #End of ForEach-Object

            }   #End of Else  (($ManagedByPrincipal.ObjectClass-ne "user") -and ($ManagedByPrincipal.ObjectClass -ne "group"))
            

        }   #End of Else ($ManagedByPrincipal)


    }   #End of Process block


}   #End of Function Sync-ADRodcManagedByPassword

