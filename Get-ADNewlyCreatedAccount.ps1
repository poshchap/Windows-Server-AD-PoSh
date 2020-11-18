Function Get-ADNewlyCreatedAccount {

##########################################################################################################
<#
.SYNOPSIS
    Gets details of accounts added to an Active Directory domain within the last n days.

.DESCRIPTION
   Gets details of user and / or computer accounts added to a given Active Directory domain within
   a number of days supplied to the function. Outputs objects with the WhenCretaed property incluced,
   for any newly created accounts. Defaults to user / computer accounts created in the last 7 days 
   from the logged on domain.

.EXAMPLE
   Get-ADNewlyCreatedAccount 

   Retrieves user and compouter accounts created in the last 7 days from the logged on domain.

.EXAMPLE    

    Get-ADNewlyCreatedAccount -Domain contoso.com -WithinDays 14 -UsersOnly

    Retrieves user accounts created in the last 14 days from the contoso.com domain.

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
          #The target Active Directory domain (defaults to current domain)
          [parameter(Mandatory=$false,Position=1,ValueFromPipeline)]
          [ValidateScript({Get-ADDomain -Identity $_})] 
          [String]$Domain,
          
          #The target Active Directory domain (defaults to current domain)
          [parameter(Mandatory=$false,Position=2)]
          [Single]$WithinDays = 7,

          #Whether to target user accounts
          [Switch] 
          $UsersOnly,

          #Whether to target computer accounts
          [Switch] 
          $ComputersOnly
          )


    #Obtain domain FQDN
    $DomainFqdn = (Get-ADDomain -Identity $Domain).DNSRoot
    
    #Create the cut-off date using the $WithinDays parameter
    $Date = (Get-Date).AddDays(-$WithinDays)
    $CutOffDate = "$($Date.Year)$("{0:D2}" -f $Date.Month)$("{0:D2}" -f $Date.Day)000000.0Z"


    #Check for switches supplied and build query type
    If ($UsersOnly -xor $ComputersOnly) {

        #Check for UsersOnly or ComputersOnly
        If ($UsersOnly) {
            
            #Create a user account query
            $LDAPFilter = "(&(ObjectCategory=Person)(ObjectClass=User)(whenCreated>=$CutOffDate))"

        }   #End of If ($UsersOnly)
        Else {
            
            #Create a computer account query
            $LDAPFilter = "(&(ObjectClass=Computer)(whenCreated>=$CutOffDate))"

        }   #End of Else ($UsersOnly)


    }   #End of If ($UsersOnly -xor $ComputersOnly)
    Else {
        
        #Create a query for both user and computer accounts
        $LDAPFilter = "(&(objectclass=user)(whenCreated>=$CutOffDate))"


    }   #End of Else ($UsersOnly -xor $ComputersOnly)
    
    
    #Find ADObjects using our custom filter
    Get-ADObject -LDAPFilter $LDAPFilter -Properties WhenCreated -Server $DomainFqdn


}   #End of Function Get-ADNewlyCreatedAccount


