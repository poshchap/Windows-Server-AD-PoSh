Function Get-ADPrivilegedGroupUpdates {

##########################################################################################################
<#
.SYNOPSIS
    Gets details of any recent changes to Active Directory High Privileged groups

.DESCRIPTION
   Uses repadmin to retrieve replication metadata for high privileged groups. Parses repadmin output
   and will show groups that have had additions or removal within the last X hours.


.EXAMPLE
   Get-ADPrivilegedGroupUpdates -Hours 76 -DC NINJADC01

   Retrieves group membership changes that have happened within the last 76 hours for all high privileged 
   groups from NINJADC01.


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
          #Specifies the period in which we want to check for changes
          [parameter(Mandatory,Position=1)]
          [Single]$Hours = 24,

          #The target domain controller
          [parameter(Mandatory,Position=2)]
          [ValidateScript({Get-ADDomainController -Server $_})] 
          [String]$DC
          )

    #Get a list of protected groups
    $ProtectedGroups = Get-ADGroup -Filter 'AdminCount -eq 1' 

    #Loop through the protected groups and test for changes
    ForEach ($Group in $ProtectedGroups) {  

    #Collect repadmin output for the privileged grouo
    $RepAdmin = repadmin /showobjmeta $DC $Group.DistinguishedName
    
    #Filter repadmin output for members
    $Updates =  $RepAdmin | Select-String "Member"
    
        #Check we have matches
        If ($Updates) {
        
            #Filter repadmin output for Distinguished Names
            $DNs = $RepAdmin | Select-String "CN="

            #Iteration Count (this allows us to refer back to $DNs)...
            $i = 0
   
            #Loop thorugh the matched lines
            ForEach ($Update in $Updates) {
        
                #Tidy up the output (trim multiple spaces down to a single space)
                $Update = $Update.Line.TrimStart() -replace '\s+',' '
        
                #Split the line down
                $Split = $Update.Split()

                #Let's see what type of member we're dealing with
                Switch ($Split[0]) {
                    
                    "LEGACY" {

                        #Show that we have found a non-LVR / LEGACY member
                        Write-Warning "'$($DNs[$i].Line.TrimStart())' is a LEGACY (non-LVR) member of '$Group'. Please enable linked value replication. `
                        More information: 'http://blogs.technet.com/b/heyscriptingguy/archive/2014/04/22/remediate-active-directory-members-that-don-39-t-support-lvr.aspx'"

                        #Increment count 
                        $i++

                    }   #End of LEGACY


                    "PRESENT" {

                        #Check whether the member change has been made in the last X hours
                        If ((Get-Date "$($Split[2]) $($Split[3])") -gt (Get-Date).AddHours(-1 * $Hours)) {

                            #Write details of the change to screen
                            Write-Warning "'$($DNs[$i].Line.TrimStart())' was added to '$Group' on $($Split[2]) at $($Split[3])"

                        }   #End of If ((Get-Date "$($Split[2]) $($Split[3])") -gt (Get-Date).AddHours(-1 * $Hours))

                        #Increment count 
                        $i++

                    }   #End of PRESENT


                    "ABSENT" {

                        #Check whether the member change has been made in the last X hours
                        If ((Get-Date "$($Split[2]) $($Split[3])") -gt (Get-Date).AddHours(-1 * $Hours)) {

                            #Write details of the change to screen
                            Write-Warning "'$($DNs[$i].Line.TrimStart())' was removed from '$Group' on $($Split[2]) at $($Split[3])"

                        }   #End of If ((Get-Date "$($Split[2]) $($Split[3])") -gt (Get-Date).AddHours(-1 * $Hours))

                        #Increment count 
                        $i++

                    }   #End of ABSENT

                }   #End of Switch ($Split[0])
        
            }   #End of ForEach ($Update in $Updates)
        
        }   #End of If ($Updates)        

    }   #End of ForEach ($Group in $ProtectedGroups)
        
}   #End of Get-ADPrivilegedGroupUpdates 

