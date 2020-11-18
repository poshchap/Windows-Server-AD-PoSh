﻿Function Test-ADUserHighPrivilegeGroupMembership {

##########################################################################################################
<#
.SYNOPSIS
   Checks whether a user is a member of a high privileged group

.DESCRIPTION
   Checks whether the supplied user object is a member of any of the following high privileged groups:

       - Account Operators
       - BUILTIN\Administrators
       - Backup Operators
       - Cert Publishers
       - Domain Admins
       - Enterprise Admins
       - Print Operators
       - Schema Admins
       - Server Operators

.EXAMPLE
   Get-ADUser -Identity ianfarr | Test-ADUserHighPrivilegeGroupMembership

   Gets the AD user with the SamAccountName ianfarr and pipes it into the Test-ADUserHighPrivilege
   function which lists any high privilege group memberships.

.EXAMPLE
   Test-ADUserHighPrivilegeGroupMembership -User "CN=Ian Farr,OU=User Accounts,DC=contoso,DC=com"

   Uses the distinguished name for the user Ian Farr to list any high privilege group memberships.

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
          #The target user account
          [parameter(Mandatory,Position=1,ValueFromPipeline)]
          [ValidateScript({Get-ADUser -Identity $_})] 
          $User
          )
    
    #Process each value supplied by the pipeline
    Process {

        #Ensures all variables are empty
        $Groups = $Null
        $Privs = $Null

        #Use the MemberOf atttibute to retrieve a list of groups
        $Groups = (Get-ADUser -Identity $User -Property MemberOf).MemberOf

        #Evaluate each entry
        Switch -Wildcard ($Groups) {
            
            #Search for membership of Account Operators
            "CN=Account Operators,CN=BuiltIn*" {
                
                #Capture membership in a custom object and add to an array
                [Array]$Privs += [PSCustomObject]@{

                    User = $User
                    MemberOf =$Switch.Current

                }   #End of $Privs

            }   #End of "CN=Account Operators,CN=BuiltIn*"


            #Search for membership of Administrators
            "CN=Administrators,CN=BuiltIn*" {
                
                #Capture membership in a custom object and add to an array
                [Array]$Privs += [PSCustomObject]@{

                    User = $User
                    MemberOf =$Switch.Current

                }   #End of $Privs
           
            }   #End of "CN=Administrators,CN=BuiltIn*"


            #Search for membership of Backup Operators
            "CN=Backup Operators,CN=BuiltIn*" {
                
                #Capture membership in a custom object and add to an array
                [Array]$Privs += [PSCustomObject]@{

                    User = $User
                    MemberOf =$Switch.Current

                }   #End of $Privs
           
            }   #End of "CN=Backup Operators,CN=BuiltIn*"


            #Search for membership of Cert Publishers
            "CN=Cert Publishers,CN=Users*" {
                
                #Capture membership in a custom object and add to an array
                [Array]$Privs += [PSCustomObject]@{

                    User = $User
                    MemberOf =$Switch.Current

                }   #End of $Privs
           
            }   #End of "CN=Cert Publishers,CN=Users*"


            #Search for membership of Domain Admins
            "CN=Domain Admins,CN=Users*" {
                
                #Capture membership in a custom object and add to an array
                [Array]$Privs += [PSCustomObject]@{

                    User = $User
                    MemberOf =$Switch.Current

                }   #End of $Privs
           
            }   #End of "CN=Domain Admins,CN=Users*"


            #Search for membership of Enterprise Admins
            "CN=Enterprise Admins,CN=Users*" {
                
                #Capture membership in a custom object and add to an array
                [Array]$Privs += [PSCustomObject]@{

                    User = $User
                    MemberOf =$Switch.Current

                }   #End of $Privs
           
           
            }   #End of "CN=Enterprise Admins,CN=Users*" 


            #Search for membership of
            "CN=Print Operators,CN=BuiltIn*" {
                
                #Capture membership in a custom object and add to an array
                [Array]$Privs += [PSCustomObject]@{

                    User = $User
                    MemberOf =$Switch.Current

                }   #End of $Privs
           
           
            }   #End of "CN=Print Operators,CN=BuiltIn*"


            #Search for membership of Schema Admins
            "CN=Schema Admins,CN=Users*" {
                
                #Capture membership in a custom object and add to an array
                [Array]$Privs += [PSCustomObject]@{

                    User = $User
                    MemberOf =$Switch.Current

                }   #End of $Privs
           
           
            }   #End of "CN=Schema Admins,CN=Users*"


            #Search for membership of Server Operators
            "CN=Server Operators,CN=BuiltIn*" {

                #Capture membership in a custom object and add to an array
                [Array]$Privs += [PSCustomObject]@{

                    User = $User
                    MemberOf =$Switch.Current

                }   #End of $Privs
           
           
            }   #End of "CN=Server Operators,CN=BuiltIn*"


        }   #End of Switch -Wildcard ($Groups)


        #Return any high privilege group memberships
        If ($Privs) {
            
            #Return the contents of $Privs
            $Privs


        }   #End of If ($Privs)


    }   #End of Process block


}   #End of Function Test-ADUserHighPrivilegeGroupMembership

