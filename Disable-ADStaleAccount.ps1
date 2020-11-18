Function Disable-ADStaleAccount {

##########################################################################################################
<#
.SYNOPSIS
    Finds potentially stale user and computer accounts. Can also disable and move accounts if instructed.

.DESCRIPTION

    Uses the lastLogonTimeStamp and pwdLastSet attributes to find user or computer accounts that are potentially
    stale. Evaluates the value of lastLogonTimeStamp and pwdLastSet aganst a supplied stale threshold: 60, 90,
    120, 150, 180 days. Where the value of either lastLogonTimeStamp and pwdLastSet is older than today minus 
    the stale threshold an account is consider stale.

    Can search for stale accounts in a specific OU or in the whole domain.

    Can also disable any stale accounts and move them to a specified, target OU.

    
    IMPORTANT: * Consider searching in specific OUs rather than the whole domain
               * Use the function WITHOUT the -Disable option to produce a report of potentially stale accounts
               * Evaluate the report... this is essential!
               * When using -Disable consider using the -WhatIf and -Confirm parameters

.EXAMPLE

    Disable-ADStaleAccount -Domain fabrikam.com -StaleThreshold 90 -AccountType User
                           
    List user accounts that have a lastLogonTimeStamp and pwdLastSet value older than today minus 90
    days for the fabrikam.com domain.

.EXAMPLE

    Disable-ADStaleAccount -Domain contoso 
                           -StaleThreshold 120 
                           -AccountType Computer 
                           -SourceOu "OU=Computer Accounts,DC=contoso,DC=com"
                           
    List computer accounts, from the Computer Accounts OU, that have a lastLogonTimeStamp and pwdLastSet 
    value older than today minus 120 days for the contoso domain.

.EXAMPLE

    Disable-ADStaleAccount -Domain contoso 
                           -StaleThreshold 150 
                           -AccountType Computer 
                           -SourceOu "OU=Computer Accounts,DC=contoso,DC=com"
                           -TargetOu "OU=Disabled,OU=Computer Accounts,DC=contoso,DC=com"
                           -Disable
                           -WhatIf
                           
    List computer accounts, from the Computer Accounts OU, that have a lastLogonTimeStamp and pwdLastSet 
    value older than today minus 150 days that will be disabled and moved to the 
    "OU=Disabled,OU=Computer Accounts,DC=contoso,DC=com" OU.

.EXAMPLE

    Disable-ADStaleAccount -Domain contoso 
                           -StaleThreshold 180 
                           -AccountType User
                           -SourceOu "OU=User Accounts,DC=contoso,DC=com"
                           -TargetOu "OU=Disabled,OU=User Accounts,DC=contoso,DC=com"
                           -Disable
                           -Confirm
                           
    Finds user accounts, from the User Accounts OU, that have a lastLogonTimeStamp and pwdLastSet 
    value older than today minus 180 days. Asks that you confirm the disabling of the accounts. The account 
    is then also moved to the "OU=Disabled,OU=User Accounts,DC=contoso,DC=com" OU upon confirmation.

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
    [CmdletBinding(SupportsShouldProcess)]
    Param(
          #The target domain
          [parameter(Mandatory,Position=1)]
          [ValidateScript({Get-ADDomain -Server $_})] 
          [String]$Domain,
          
          #The number of days before which accounts are considered stale
          [parameter(Mandatory,Position=2)]
          [ValidateSet(60,90,120,150,180)] 
          [Int32]$StaleThreshold,

          #Whether we are searching for user or computer accounts
          [parameter(Mandatory,Position=3)]
          [ValidateSet("User","Computer")] 
          [String]$AccountType,

          #The OU we use as the basis of our search
          [parameter(Position=4)]
          [ValidateScript({Get-ADOrganizationalUnit -Identity $_ -Server $Domain})] 
          [String]$SourceOu,

          #The OU to which we move the disabled accounts
          [parameter(Position=5)]
          [ValidateScript({Get-ADOrganizationalUnit -Identity $_ -Server $Domain})] 
          [String]$TargetOu,
          
          #Whether to disable and move the accounts
          [switch]
          $Disable
          )
    
    #Obtain a datetime object before which accounts are considered stale
    $DaysAgo = (Get-Date).AddDays(-$StaleThreshold) 


    #Check whether we have a source OU for our search
    if ($SourceOU) {

        #Search for stale accounts in our source OU and assign any resultant objects to a variable
        $StaleAccounts = &"Get-AD$AccountType" -Filter {(PwdLastSet -lt $DaysAgo) -or (LastLogonTimeSTamp -lt $DaysAgo)} `
                                               -Properties PwdLastSet,LastLogonTimeStamp,Description `
                                               -SearchBase $SourceOu `
                                               -Server $Domain
    }
    else {

        #Search for stale accounts and assign any resultant objects to a variable
        $StaleAccounts = &"Get-AD$AccountType" -Filter {(PwdLastSet -lt $DaysAgo) -or (LastLogonTimeSTamp -lt $DaysAgo)} `
                                               -Properties PwdLastSet,LastLogonTimeStamp,Description `
                                               -Server $Domain

    }   #end of else ($SourceOU)


    #Check whether we have the disable switch activated
    if ($Disable) {

        #Now check we have a targetOU
        if ($TargetOu) {

            #Loop through the stale accounts
            foreach ($StaleAccount in $StaleAccounts) {

                #Activate the -WhatIf and -Confirm risk mitigation common parameters
                if ($PSCmdlet.ShouldProcess($StaleAccount, "DISABLED and MOVED to $TargetOu")) {

                    #Disable the account
                    &"Set-AD$AccountType" -Identity $StaleAccount -Enabled $false -Server $Domain

                    #Check whether the disable (last action) was successful
                    if ($?) {

                        #Move the disable account
                        Move-ADObject -Identity $StaleAccount -TargetPath $TargetOu -Server $Domain

                        #Check whether the move (last action) was successful
                        if ($?) {

                            #Write a message to screen
                            Write-Host "$StaleAccount has been DISABLED and MOVED to $TargetOu"


                        }   #end of if ($?) - move

                        else {

                            Write-Warning "$StaleAccount has been DISABLED but could not be moved to $TargetOu"


                        }   #end of else ($?) - move


                    }   #end of if ($?) - disable

                    Else {

                        #Write an error message
                        Write-Error "Unable to disable $StaleAccount"

                    }   #end of else ($?) - disable


                }   #end of if ($PSCmdlet.ShouldProcess($StaleAccount, "DISABLED and MOVED to $TargetOU"))


            }   #end of foreach ($StaleAccount in $StaleAccounts)


        }   #end of if ($targetOu)

        else { 

            #Write an error message
            Write-Error "If you use the -Disable switch you must specifiy a target OU for the account move" 


        }   #end of else ($targetOu)


    }   #end of if ($Disable)

    #If we don't have the disabled switch activated perform the following action
    else {

        #Output the stale accounts found with human-readable properties
        $StaleAccounts | Select-Object -Property DistinguishedName,Name,Enabled,Description, `
                         @{Name="PwdLastSet";Expression={[datetime]::FromFileTime($_.PwdLastSet)}}, `
                         @{Name="LastLogonTimeStamp";Expression={[datetime]::FromFileTime($_.LastLogonTimeStamp)}} 


    }   #end of else ($Disable)


}   #end of Function Disable-ADStaleAccount
