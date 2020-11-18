Function Test-ADPrincipalProtectedGroupMembership {

##########################################################################################################
<#
.SYNOPSIS
   Checks whether an Active Directory user, computer, group or service account is a member of a protected 
   group.

.DESCRIPTION
   Checks whether the supplied user, group, computer or service account, from the current domain, is a 
   member of groups marked as AdminCount = 1 from other domains in the forest.

.EXAMPLE
   Get-ADUser -Identity ianfarr | Test-ADPrincipalProtectedGroupMembership | 
   Select-Object -ExpandProperty  MemberOf

   Gets the AD user with the SamAccountName ianfarr and pipes it into the Test-ADUserHighPrivilege
   function and then displays the distinguishedNames of any protected groups that the user is a member of.

.EXAMPLE
   Test-ADPrincipalProtectedGroupMembership -Principal "CN=CONCLI81,OU=Clients,DC=contoso,DC=com"

   Uses the distinguished name for the computer account CONCLI81 to list any protected group memberships.

.EXAMPLE
   Get-ADGroup -Filter * -SearchBase "OU=Groups,DC=contoso,DC=com" -SearchScope OneLevel | 
   Test-ADPrincipalProtectedGroupMembership -Verbose

   Tests all of the groups from the "OU=Groups,DC=contoso,DC=com" OU for any protected group memberships 
   and lists results to screen.

   Verbose shows groups that don't have the MemberOf attribute populated.

.EXAMPLE
   Get-ADUser -Filter * | Test-ADPrincipalProtectedGroupMembership

   Get's every user from the current domain and checks them for protected groups membership in any domain, 
   found to be in scope, from the user's memberOf property.

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
          #The distinguishedname of the target principal
          [parameter(Mandatory,Position=1,ValueFromPipeline)]
          [ValidateScript({Get-ADObject -Identity $_})] 
          $Principal
          )

    
     Begin {

        #Connect to a Global Catalogue
        $GC = New-PSDrive -PSProvider ActiveDirectory -Server $(Get-ADDomain).DnsRoot -Root "" –GlobalCatalog –Name GC

        #Error checking
        if (!$GC) {

            #Error and exit
            Write-Error -Message "Failed to create GC drive. Exiting function..."
            Break

        }   #end of if ($GC)

    }   #end of Begin

   

    Process {

        #Use the MemberOf atttibute to retrieve a list of groups
        $PrincipalGroups = (Get-ADPrincipalGroupMembership -Identity $Principal).DistinguishedName

        #Change to GC PS Drive
        Set-Location -Path GC:

        if ($PrincipalGroups) {

            #Create arays for protected groups and domains found
            $ProtectedGroups = @()
            $Domains = @()

            #Loop through groups to determine group domain (this is needed to define scope of admincount -eq 1 tests)
            foreach ($Group in $PrincipalGroups) {

                $Domain = ($Group -split "," | Select-String "DC=").line.substring(3) -join "."
                $Domains += $Domain                

            }   #end of foreach ($Group in $PrincipalGroups)

            #Ensuire we have an array of unique entries
            $Domains = $Domains | Select-Object -Unique

            #Loop through the domains to retrieve protected groups
            foreach ($Domain in $Domains) {

                $ProtectedGroups += (Get-ADGroup -Filter {adminCount -eq 1} -Server $Domain -ErrorAction SilentlyContinue).DistinguishedName

            }   #end of foreach ($Domain in $Domains

            #Perform comparison
            $PrivMemberships = (Compare-Object -ReferenceObject $ProtectedGroups -DifferenceObject $PrincipalGroups -IncludeEqual |
                              Where-Object {$_.SideIndicator -eq "=="}).InputObject
            
            #Check for a match
            if ($PrivMemberships) {

                #Capture results
                $Privs = [PSCustomObject]@{

                        Principal = $Principal
                        MemberOf =$PrivMemberships

                    }   #End of $Privs


                #Return Custom Object
                $Privs

                #Debug here
                Write-Debug "Privs"

            }   #end of if ($PrivMemberships)

        }   #end of if ($PrincipalGroups)
        else {

            Write-Verbose "$(Get-Date -f T) - No group memberships retrieved for $Principal"

        }   #end of else ($ProtectedGroups)

        #Change back to C: PS Drive
        Set-Location -Path C:

    }   #End of Process block



    End {

        #Exit the GC PS drive and remove
        if ((Get-Location).Drive.Name -eq "GC") {

            #Move to C: drive
            C:

        }   #end of if ((Get-Location).Drive.Name -eq "GC")

    }   #end of End


}   #End of Function Test-ADPrincipalProtectedGroupMembership

