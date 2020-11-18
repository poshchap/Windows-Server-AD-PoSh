Function Get-ADRodcAuthenticatedNotRevealed {

##########################################################################################################
<#
.SYNOPSIS
   Produces a list of accounts authenticated by an RODC, but not revealed, i.e. the accounts 
   whose credentials are not stored as part of an 'allowed' Password Replication Policy (PRP).

.DESCRIPTION
   Uses the Get-ADDomainControllerPasswordReplicationPolicyUsage to get details of authenticated 
   accounts and revealed accounts. Compares these lists and returns accounts that have been
   authenticated but not revealed.

.EXAMPLE
   Get-ADDomainController -Filter {IsReadOnly -eq $True} | Get-ADRodcAuthenticatedNotRevealed

   Queries all of the RODCs for the domain that the user is currently logged on to and returns
   those accounts that have been authenticated and not revealed

.EXAMPLE
   Get-ADRodcAuthenticatedNotRevealed -Rodc HALODC01 -UsersOnly

   Queries an RODC called HALODC01 and returns user accounts that have been authenticated 
   and not revealed

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
          [parameter(Mandatory=$True,Position=1,ValueFromPipeline = $True)]
          [ValidateScript({Get-ADDomainController -Identity $_})] 
          [String]$Rodc,

          #Output just user accounts
          [Switch] 
          $UsersOnly
          )
    
    #Process each value supplied by the pipeline
    Process {

        #Ensures all variables are empty
        $AuthenticatedAccounts = $Null
        $RevealedAccounts = $Null
        $Comparison = $Null
        $Results = $Null

        #Get the list of all authenticated accounts from the supplied RODC
        $AuthenticatedAccounts = Get-ADDomainControllerPasswordReplicationPolicyUsage -Identity $Rodc -AuthenticatedAccounts


        #Get the list of accounts from the supplied RODC
        $RevealedAccounts = Get-ADDomainControllerPasswordReplicationPolicyUsage -Identity $Rodc -RevealedAccounts


        #Perform a comparison of the authenticated list against the revealed list
        $Comparison = Compare-Object -ReferenceObject $AuthenticatedAccounts -DifferenceObject $RevealedAccounts


        #Take the comparison and capture those accounts that have been autheticated but not revealed
        $Results = $Comparison | Where-Object {$_.SideIndicator -eq "<="} 


        #Return objects that are authenticated but not revealed
        If ($Results) {
            
            #Check for users only switch
            If ($UsersOnly) {

                #Make sure we only output users
                ForEach ($Result in $Results.InputObject) {

                    #Check the objectClass
                    If ($Result.ObjectClass -eq "user") {

                        #Return the object
                        $Result


                    }   #End of If ($Result.ObjectClass -eq "user") 


                }   #End of ForEach ($Result in $Results.InputObject)


            }   #End of If ($UsersOnly)
            Else {

                #Uncomment the pipe to export the results to a CSV for the current RODC
                $Results.InputObject #| Export-CSV -Path "$($Rodc)_AuthenticatedNotRevealed.csv" -Force


            }   #End of If ($UsersOnly)


        }   #End of If ($Results) 


    }   #End of Process block


}   #End of Function Get-ADRodcAuthenticatedNotRevealed

