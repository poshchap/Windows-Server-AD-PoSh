Function Set-ADRodcManagedByAttribute {

##########################################################################################################
<#
.SYNOPSIS
   Sets an RODC's ManagedBy attribute to the supplied User or Group Distinguished Name for delegated 
   administration

.DESCRIPTION
   If a valid RODC and AD Object (principal) are supplied, the function checks the principal's object 
   class. If a valid user or group is detected, the principal's Distinguished Name will be written to the 
   RODC's ManagedBy attribute.

.EXAMPLE
   Get-ADDomainController -Filter {IsReadOnly -eq $True} | 
   Set-ADRodcManagedByAttribute -Principal "CN=RODC Admins,OU=Groups,DC=Fabrikam,DC=com"

   Finds all of the RODCs for the domain that the user is currently logged on to and then pipes this into
   the function to set each RODC's ManagedBy attribute to the "RODC Admins" group

.EXAMPLE
   "NINJARODC01" | Set-ADRodcManagedByAttribute -Principal "CN=RODC01 Admins,OU=Groups,DC=Fabrikam,DC=com" -AddtoPRP

   Pipes "NINJARODC01" into the Set-ADRodcManagedByAttribute function. Sets the 'ManagedBy' attribute to the
   supplied principal - RODC01 Admins - and then adds the same principal to the PRP allowed list

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

#Version: 3.0 
# -added the AddtoPRP switch

    #Define and validate parameters
    [CmdletBinding()]
    Param(
          #The target DistinguishedName
          [parameter(Mandatory,Position=1,ValueFromPipeline)]
          [ValidateScript({(Get-ADDomainController -Identity $_).IsReadOnly})] 
          [String]$Rodc,

          #DistinguishedName of user or group to be added to the ManagedBy attribute
          [parameter(Mandatory,Position=2)]
          [ValidateScript({Get-ADObject -Identity $_})] 
          [String]$Principal,

          #Whether we also add the user or group to the RODCs Allowed Password Replication Policy
          [switch]
          $AddtoPRP
          )
    
    #Perform an additional check of the supplied AD Object
    Begin {

        #Get the supplied AD Object
        $ADObject= Get-ADObject -Identity $Principal -ErrorAction SilentlyContinue
        

        #Check that $Principal is a user or group
        If (($ADObject.ObjectClass -ne "user") -and ($ADObject.ObjectClass -ne "group")) {

            #Write a message to the host
            Write-Host "$Principal is not a user or group"
            Break

        }   #End of If (($ADObject.ObjectClass -ne "user") -and ($ADObject.ObjectClass -ne "group"))
        

    }   #End of Begin block

    #Process each value supplied by the pipeline
    Process {
        
        #Set the ManagedBy attribute
        Get-ADComputer -Identity $Rodc | Set-ADObject -Replace @{ManagedBy = $Principal}

        #Check to see if the AddtoPRP switch is specified
        If ($AddtoPRP) {

            #Add the principal to the PRP
            Add-ADDomainControllerPasswordReplicationPolicy -Identity $Rodc -AllowedList $Principal

        }   #End of If ($AddtoPRP)


    }   #End of Process block


}   #End of Function Set-ADRodcManagedByPassword

