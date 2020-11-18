Function Get-ADDomainAccountPolicies {

##########################################################################################################
<#
.SYNOPSIS
    Obtain a domain's Account Lockout and Password policies 

.DESCRIPTION
    Reads account lockout and password attributes from the domain header for a supplied domain

.EXAMPLE
    Get-ADDomainAccountPolicies -Domain contoso.com

    Returns the Account Lockout and Password policies for the contoso.com domain, e.g...

    PolicyType : Account Lockout
    DistinguishedNane : DC=contoso,DC=com
    lockoutDuration : 30 minutes
    lockoutObservationWindow : 30 minutes
    lockoutThreshold : 50

    PolicyType : Password
    DistinguishedNane : DC=contoso,DC=com
    minPwdAge : 1 days
    maxPwdAge : 60 days
    minPwdLength : 8
    pwdHistoryLength : 24
    pwdProperties : Passwords must be complex and the administrator account cannot be locked out

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
          [parameter(Mandatory=$True,Position=1)]
          [ValidateScript({Get-ADDomain -Identity $_})] 
          [String]$Domain
          )
        ##Get the RootDSE    $RootDSE = Get-ADRootDSE -Server $Domain    ##Get the Account Lockout policy    #Store specific attributes from the domain header    $AccountPolicy = Get-ADObject $RootDSE.defaultNamingContext -Property lockoutDuration,lockoutObservationWindow,lockoutThreshold -Server $Domain

    #Format the Account Lockout policy
    $AccountPolicy | Select @{n="PolicyType";e={"Account Lockout"}},`                            DistinguishedName,`                            @{n="lockoutDuration";e={"$($_.lockoutDuration / -600000000) minutes"}},`
                            @{n="lockoutObservationWindow";e={"$($_.lockoutObservationWindow / -600000000) minutes"}},`
                            lockoutThreshold | Format-List


    ##Get the Password policy    #Store specific attributes from the domain header    
    $PasswordPolicy = Get-ADObject $RootDSE.defaultNamingContext -Property minPwdAge,maxPwdAge,minPwdLength,pwdHistoryLength,pwdProperties -Server $Domain
    
    #Format the Password policy
    $PasswordPolicy | Select @{n="PolicyType";e={"Password"}},`
                             DistinguishedName,`                             @{n="minPwdAge";e={"$($_.minPwdAge / -864000000000) days"}},`
                             @{n="maxPwdAge";e={"$($_.maxPwdAge / -864000000000) days"}},`
                             minPwdLength,`                             pwdHistoryLength,`
                             @{n="pwdProperties";e={Switch ($_.pwdProperties) {
                                  0 {"Passwords can be simple and the administrator account cannot be locked out"} 
                                  1 {"Passwords must be complex and the administrator account cannot be locked out"} 
                                  8 {"Passwords can be simple, and the administrator account can be locked out"} 
                                  9 {"Passwords must be complex, and the administrator account can be locked out"} 
                                  Default {$_.pwdProperties}}}}

}   #End of Function Get-ADDomainAccountPolicies