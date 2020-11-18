Function Set-ADUserJitAdmin {

##########################################################################################################
<#
.SYNOPSIS
    Grants time-bound membership of specific high-privileged groups on a per-user basis
     
.DESCRIPTION
    Grants temporary membership of either Domain Admins, Enterprise Admins or Schema Admins to a user, 
    identified by their distinguished name, in the same domain.

    Uses a nested, dynamic group object to ensure that membership of the high privileged group is
    automatically removed after a period of time, specified in hours. The dynamic group has a TTL. The 
    user is added to the dynamic group and the dynamic group is nested in the high privileged group.

    Can spin up a 'count down' to monitor when membership is due to be removed (-CountDown switch).

    Can add the user to the Protected Users group (if it exists) to make use of credential theft 
    mitigations, e.g. no long term Kerberos keys (-ProtectedGroup switch). Furthermore, if the domain is at 
    Windows Server 2012 R2 functional level, can also make use of Authentication Policies to grant TGTs 
    of less than four hours. This is so the TGT can match the TTL of the dynamic group. The Authentication 
    Policy is removed at TTL expiry.

.EXAMPLE
    Set-ADUserJitAdmin -UserDn "CN=Ian Farr Temp HPU,OU=HPU Accounts,OU=User Accounts,DC=halo,DC=net"
                       -Domain "halo.net"
                       -PrivGroup "Domain Admins"
                       -TtlHours 10
                       -Verbose
                        
    Adds the 'Ian Farr Temp HPU' user account to a dynamic group that is then nested in the Domain Admins
    group of the halo.net domain. The dynamic group is given a TTL of 10 hours. After this time, AD removes
    the group, thereby removing privileged access. 
    
    Produces verbose output.

.EXAMPLE
    Set-ADUserJitAdmin -UserDn "CN=Ian Farr Temp HPU,OU=HPU Accounts,OU=User Accounts,DC=halo,DC=net"
                       -Domain "halo.net"
                       -PrivGroup "Schema Admins"
                       -TtlHours 12
                       -CountDown

    Adds the 'Ian Farr Temp HPU' user account to a dynamic group that is then nested in the Schema Admins
    group of the halo.net domain. The dynamic group is given a TTL of 12 hours. A count down of the 
    remaining seconds is written to the console. After this time, AD removes the group, thereby removing 
    privileged access. 

.EXAMPLE
    Set-ADUserJitAdmin -UserDn "CN=Ian Farr Temp HPU,OU=HPU Accounts,OU=User Accounts,DC=halo,DC=net"
                       -Domain "halo.net"
                       -PrivGroup "Enterprise Admins"
                       -TtlHours 2
                       -ProtectedUser
                       -Verbose

    Adds the 'Ian Farr Temp HPU' user to the Protected Users group, if it exists. Will then create an
    Authentication Policy, if the domain functional level is Windows Server 2012 R2, that has a TGT life
    time of 2 hours. The Authentication Policy is associated with the 'Ian Farr Temp HPU' user. 
    
    Adds the 'Ian Farr Temp HPU' user account to a dynamic group that is then nested in the Enterprise Admins
    group of the halo.net domain. The dynamic group is given a TTL of 2 hours. A count down of the 
    remaining seconds is written to the console. After this time, AD removes the group, thereby removing 
    privileged access. The Authentication Policy is also deleted.

    Produces verbose output.

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

#Requires -version 4
#Requires -modules ActiveDirectory

#Authors: Ian Farr (MSFT), Phil Lane (MSFT)
#Version: 2.1

    #Define and validate parameters
    [CmdletBinding()]
    Param(
          #The distinguished name of the user to be granted high privileged group membership
          [parameter(Mandatory,Position=1)]
          [ValidateScript({Get-ADUser -Identity $_})]
          [String]$UserDn,

          #Confirmation of the current domain
          [parameter(Mandatory,Position=2)]
          [ValidateScript({Get-ADDomain -Identity $_})]
          [String]$Domain,

          #The high privileged group the use will be a member of
          [parameter(Mandatory,Position=3)]
          [ValidateSet("Domain Admins","Enterprise Admins","Schema Admins")]
          [String]$PrivGroup,

          #The amount of time, in hours, that the user is granted privileged access
          [parameter(Mandatory,Position=4)]
          [ValidateRange(1,24)]
          [Single]$TtlHours,

          #Whether to spin up a count down
          [Switch] 
          $CountDown,

          #Whether to utilise membership of the Protected Users group
          [Switch] 
          $ProtectedUser
          )


    #####################
    ##VARIABLES AND SUCH

    #Get the sAMAccountName of our user
    $UserSamAccountName = ((Get-ADUser -Identity $UserDn).SamAccountName).ToUpper()

    #Create the temporary dynamic group name
    $DynamicGroupName = "Dynamic Group - $UserSamAccountName"

    #Get the domain distingusihed name
    $DomainDn = (Get-ADDomain -Identity $Domain).DistinguishedName

    #Construct an distinguished name for the Users container
    $UsersContainerDn = "CN=Users,$DomainDn"

    #Get a System.DirectoryServices.DirectoryEntry object representing the Users container
    $UsersContainer = [ADSI]("LDAP://$UsersContainerDn")

    #Check that we have the object representing the Users container
    if ($UsersContainer) {


        ########################
        ##PROTECTED USER SWITCH

        #Check whether we need to check membership of the protected users group
        if ($ProtectedUser) {

        #Check whether the Protected Users group exists (and ask for the members attribute)
        $ProtectedUsersGroup = Get-ADGroup -Identity "CN=Protected Users,$UsersContainerDn" -Properties members -ErrorAction SilentlyContinue

            #Check that we have an object representing the Protected Users group
            if ($ProtectedUsersGroup) {

                #Check whether our user is already a member of the Protected Users group
                if (($ProtectedUsersGroup).members -like $UserDn) {
          
                    #Write to console
                    Write-Verbose -Message "$(Get-Date -f T) - `'$UserDn`' already a member of Protected Users group"

                }
                else {

                    #Add our user to Protected Users group
                    Add-ADGroupMember -Identity "CN=Protected Users,$UsersContainerDn" -Members $UserDn -ErrorAction SilentlyContinue

                    #Check that Add-ADGroupMember completed successfully
                    if ($?) {

                        #Write to console
                        Write-Verbose -Message "$(Get-Date -f T) - `'$UserDn`' added to `'CN=Protected Users,$UsersContainerDn`'"

                    }   #end of if ($?)
                    else {

                        #Write error
                        Write-Error -Message "Unable to add `'$UserDn`' to `'CN=Protected Users,$UsersContainerDn!`'" -ErrorAction Stop

                    }   #end of else ($?)

                }   #End of else (($ProtectedUsersGroup).members -like $UserDn) 
                


                ########################
                ##AUTHENTICATION POLICY

                #Now, let's check whether we need to create an Authentication Policy
                if ($TtlHours -lt 4) {

                    #Get the domain distingusihed name
                    $DomainFL = (Get-ADDomain $Domain).DomainMode

                    #Check that we have a Domain Functional Level of W2K12 R2
                    if ($DomainFL -eq "Windows2012R2Domain") {

                        #Write to console
                        Write-Verbose -Message "$(Get-Date -f T) - Domain Functional Level currently set to $DomainFL"

                        #Variable for Auth Pol name
                        $AuthPolName = "Temp Auth Pol for $UserSamAccountName"

                        #Create a new Authentication Policy
                        New-ADAuthenticationPolicy -Name $AuthPolName `
                                                   -Description "Temporary Authentication Policy to set $TtlHours hour Ticket Granting Ticket for $UserSamAccountName" `
                                                   -UserTGTLifetimeMins ($TtlHours * 60) `
                                                   -Enforce `
                                                   -ProtectedFromAccidentalDeletion $False `                                                   -ErrorAction SilentlyContinue

                        #Make sure we have our Auth Pol
                        if ($?) {

                            #Write to console
                            Write-Verbose -Message "$(Get-Date -f T) - Authentication Policy `'$AuthPolName`' created with a user TGT of $TtlHours hours"

                            #A flag to tell us to delete the Auth Pol later
                            $AuthPol = $true

                            #Now assign the Auth Pol to our user
                            Set-ADUser -Identity $UserSamAccountName -AuthenticationPolicy $AuthPolName -ErrorAction SilentlyContinue

                            #Check that we have assigned our policy
                            if ($?) {

                                #Write to console
                                Write-Verbose -Message "$(Get-Date -f T) - Authentication Policy `'$AuthPolName`' assigned to `'$UserDn`' object"

                                #Make sure we spin up a counter later
                                $CountDown = $true


                            }   #end of if ($?)
                            else {

                                #Write-warning to screen
                                Write-Warning -Message "Unable to assign Authentication Policy to user object. User TGT won't match Dynamic Group TTL."

                            }   #end of else ($?)


                        }   #end of if ($?)
                        else {

                            #Write-warning to screen
                            Write-Warning -Message "Unable to create Authentication Policy. User TGT won't match Dynamic Group TTL."

                        }   #end of else ($?)



                    }   #end of if ($DomainFL -eq "Windows2012R2Domain")
                    else {

                        #Write-warning to screen
                        Write-Warning -Message "Domain Functional Level does not support Authentication Policies. User TGT won't match Dynamic Group TTL."

                    }   #end of ($DomainFL -eq "Windows2012R2Domain")


                }   #end of if $TtlHours -lt 4            

            }   #end of if ($ProtectedUsersGroup)
            else {

                #Write that Protected Users group not found
                Write-Error -Message "Unable to find `'CN=Protected Users,$UsersContainerDn`'!"

            }   #end of else ($ProtectedUsersGroup)

        }   #end of if ($ProtectedUser)



        #######################
        ##CREATE DYNAMIC GROUP

        #Use the Users container object to create the temporary dynamic group
        $DynamicGroup = $UsersContainer.Create("group","CN=$DynamicGroupName") 
        
        #Check that we have created the dynamic group
        if (!$DynamicGroup) {

            #Write error
            Write-Error -Message "Unable to create dynamic group!" -ErrorAction Stop

        }   #end of if ($DynamicGroup)
         
        $DynamicGroup.PutEx(2,"objectClass",@("dynamicObject","group"))  
        $DynamicGroup.Put("msDS-Entry-Time-To-Die",[datetime]::UtcNow.AddHours($TtlHours))
        $DynamicGroup.Put("sAMAccountName",$DynamicGroupName)  
        $DynamicGroup.Put("displayName",$DynamicGroupName)  
        $DynamicGroup.Put("description","Temporary group to grant time-bound membership of `'$PrivGroup`' to `'$UserSamAccountName`'")  
        $DynamicGroup.SetInfo() 


        #Check that the additional information has been set on the dynamic group
        if ($?) {

            #Write to console
            Write-Verbose -Message "$(Get-Date -f T) - `'CN=$DynamicGroupName,$UsersContainerDn`' created and set to expire in $TtlHours hours"

        }   #end of if ($?)
        else {

            #Write error
            Write-Error -Message "Unable to configure dynamic group settings!" -ErrorAction Stop

        }   #end of else ($?)


    }   #end of if ($UsersContainer)
    else {

        #Write error
        Write-Error -Message "Unable to obtain object for Users container!" -ErrorAction Stop

    }   #end of else ($UsersContainer)



    ###############################
    ##TARGET USER TO DYNAMIC GROUP

    #Add our user to the new dynamic group
    Add-ADGroupMember -Identity "CN=$DynamicGroupName,$UsersContainerDn" -Members $UserDn -ErrorAction SilentlyContinue

    #Check that Add-ADGroupMember completed successfully
    if ($?) {

        #Write to console
        Write-Verbose -Message "$(Get-Date -f T) - `'$UserDn`' added to `'CN=$DynamicGroupName,$UsersContainerDn`'"

    }   #end of if ($?)
    else {

        #Write error
        Write-Error -Message "Unable to add `'$UserDn`' to `'CN=$DynamicGroupName,$UsersContainerDn`'!" -ErrorAction Stop

    }   #end of else ($?)



    #########################################
    ##DYNAMIC GROUP TO HIGH PRIVILEGED GROUP

    #Add the dynamic group to the built-in privileged group
    Add-ADGroupMember -Identity $PrivGroup -Members "CN=$DynamicGroupName,$UsersContainerDn" -ErrorAction SilentlyContinue
    
    #Check that Add-ADGroupMember completed successfully
    if ($?) {

        #Write to console
        Write-Verbose -Message "$(Get-Date -f T) - `'CN=$DynamicGroupName,$UsersContainerDn`' added to `'$PrivGroup`'"

    }   #end of if ($?)
    else {

        #Write error
        Write-Error -Message "Unable to add `'CN=$DynamicGroupName,$UsersContainerDn`' to `'$PrivGroup`'!" -ErrorAction Stop

    }   #end of else ($?) 

    

    #################### 
    ##COUNTDOWN SWITCH

    #Check whether we need to spin up a counter
    if ($CountDown) {

        #A do loop for our countdown
        do {
    
            #Get the TTL of the dynamic group
            $TTL = (Get-ADGroup -Identity $DynamicGroupName -Properties entryTTL).entryTTL

            #Spin up a progress bar for the countdown
            Write-Progress -Activity "Countdown until `'CN=$DynamicGroupName,$UsersContainerDn`' removed..." `
                           -Status "Seconds remaining: $TTL" `
                           -PercentComplete ($TTL/($TtlHours * 3600) *100)

            #Wait a second...
            Start-Sleep -Seconds 1

        } while ($TTL -gt 0) 

    }   #end of if ($CountDown)



    ########## 
    ##TIDY UP

    #Check for the existence of an authentication policy
    if ($AuthPol) {
        
        #Remove the authentication policy
        Remove-ADAuthenticationPolicy -Identity $AuthPolName -Confirm:$false -ErrorAction SilentlyContinue

        if ($?) {

            #Write to console
            Write-Verbose -Message "$(Get-Date -f T) - `'$AuthPolName`' removed"

            
        }   #end of if ($?)
        else {

            #Write error
            Write-Error -Message "Unable to remove `'$AuthPolName`'. Please investigate."


        }   #end of else ($?)

    }   #end of if ($AuthPol)


}   #end of Function Set-ADUserJitAdmin


##########################################################################################################