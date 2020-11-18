Function Check-ADForwardLinkProperty {

##########################################################################################################
<#
.SYNOPSIS
   Check whether a property is a forward link and returns any property values for a given AD object

.DESCRIPTION
   Checks whether a supplied property is a forward link. If the property is a valid forward link,
   any values associated with the property, for a referenced Distinguished Name, are returned.

.EXAMPLE
   Check-ADForwardLinkProperty -DN "CN=Server Operators,CN=Builtin,DC=Contoso,DC=Com" -Property Member

   Checks whether the Member property is a valid forward link. If the property is a valid forward link and had values
   a custom object is returned for "CN=Server Operators,CN-Builtin,DC=Contoso,DC=Com", for example:

   DistinguishedName                                     LinkID Member
   -----------------                                     ------ --------
   CN=Server Operators,CN-Builtin,DC=Co...                    2 {CN=Master Chief,OU=User Accou,...

.EXAMPLE
   Get-ADGroup "CONTOSOMEM19 Access" | Check-ADForwardLinkProperty -Property Member | Select-Object -ExpandProperty Member

   Uses Get-ADGroup to retrieve an object representing the group "CONTOSOMEM19 Access". Pipes the object into 
   the Check-ADForwardLinkProperty function. Checks whether the Member property is a valid forward link. 
   If the property is a valid forward link and has values, a custom object is returned and piped into Select-Object. 
   The Member property is then expanded to show the values returned, for example:

   CN=Ian Farr,OU=User Accounts,DC=Contoso,DC=Com
   CN=Master Chief,OU=User Accounts,DC=Contoso,DC=Com

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
          [ValidateScript({Get-ADObject -Identity $_})] 
          [String]$DN,

          #The property to check
          [parameter(Mandatory=$True,Position=2)]
          [ValidateNotNullOrEmpty()] 
          [String]$Property
          )
      

    #Get schema attributes that are linked
    $SchemaNC = (Get-ADRootDSE).schemaNamingContext
    $LinkedSchema = Get-ADObject -SearchBase $SchemaNC `
                                 -LDAPFilter "(linkId=*)" `
                                 -Property linkId, lDAPDisplayName


    #See if our passed property has a link ID
    $LinkedProperty = $LinkedSchema | Where-Object {$_.lDAPDisplayName -eq $Property}

        If ($LinkedProperty -eq $Null) {

            Write-Error "Passed property - $Property - is not a linked property"

        }   #End of If ($LinkedProperty -eq $Null)

        Else {

            #Check that the link ID is for a forward link (forward links are even numbers, back links are odd numbers)
            If (($LinkedProperty.LinkId % 2) -ne 0) {

                Write-Host "Passed property - $Property - is a back link"

            }   #End of If ($LinkedProperty.LinkId % 2)

            Else {

                #Get details of the property
                $ADObject = Get-ADObject -Identity $DN -Properties $Property | Select-Object -ExpandProperty $Property

                    #Check whether Get-ADObject has returned values
                    If ($ADObject -ne $Null) {

                            #Create a custom object to store the different pieces of information we've collected
                            $ADCustomObject = [PSCustomObject]@{

                                DistinguishedName = $DN
                                LinkID = $($LinkedProperty.LinkId)
                                $Property = $ADObject

                            }   #End of $ADCustomObject...
 
                        #Return the new object
                        Return $ADCustomObject

                    }   #End of If ($ADObject -ne $Null)

                    Else {

                        Write-Host
                        Write-Host "`"$Property`" is a valid forward link but is empty or not a valid property for `"$DN`""


                    }   #End of Else ($ADObject -ne $Null)


            }   #End of Else ($LinkedProperty.LinkId % 2)


        }   #End of Else ($LinkedProperty -eq $Null)


}   #End of Function Check-ADForwardkLinkProperty