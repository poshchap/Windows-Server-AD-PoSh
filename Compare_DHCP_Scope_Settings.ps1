##########################################################################################################
<#
.SYNOPSIS
    Queries two DHCP servers, comparing scope settings by using the Windows Server 2012 DHCP Cmdlets.

.DESCRIPTION
    Queries two supplied DHCP servers, comparing scope settings by using a variety of Windows Server 2012 DHCP Cmdlets.
    The DHCP Cmdlets (checks) executed can be determined by a script 'control panel' The results all of the checks for 
    each scope are then written to a worksheet in an Excel document for readability.  
    
    Here are the checks:

        * IPv4 Scope Information
        * IPv4 Scope Reservations
        * IPv4 Scope Option Value 

    Checks not included:

        * IPv4 Scope DNS Settings
        * IPv4 Scope Failover
        * IPv4 Scope Free Address
        * IPv4 Scope Leases
        * IPv4 Scope Policies
        * IPv4 Scope Policy IP Range
        * IPv4 Scope Statistics 
        * All IPv6 Scope Checks

    Differences between the two servers are identified thus:

        * Matching objects are presented side by side in yellow and turquoise for ease of comparison
        * For matching objects, specific property discrepancies will have the property name 
          highlighted in red
        * Objects that are unique to one server will be highlighted in either green (server 1) 
          or orange (server 2) after any matching object comparisons

    Control Panel:

        * Provides the ability to comment out DHCP server checks not required
          N.B. include all tests for compatibility with the Configure_DHCP_Scope_Failover_Load_Balance_Mode.ps1 
          companion script
        

    Requirements:
        * PowerShell v3
        * DhcpServer PS module
        * Excel
        * Parameter 1: target DHCP server 1
        * Parameter 2: target DHCP server 2

.EXAMPLE
   .\Compare_Dhcp_Scope_Settings.ps1 -DhcpServer1 CORPDHCP1 -DhcpServer2 CORPDHCP2

   This will compare the scope settings on CORPDHCP1 to those on CORPDHCP2 and write the results to 
   an Excel spreadsheet in the same folder as the script.

.OUTPUTS
   <YearMonthDayHourMinuteSecond>_<DhcpServer1>_<DhcpServer2>_DHCP_Scope_Comparison.xls

   EXIT CODES:  1 - DhcpServerv4Scope check not in position 0
                2 - Excel not installed

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

###############################
## SCRIPT OPTIONS & PARAMETERS
###############################

#Requires -Version 3
#Requires -modules DhcpServer

#Define and validate mandatory parameters
[CmdletBinding()]
Param(
      #The first DHCP server to be targeted
      [parameter(Mandatory=$True,Position=1)]
      [ValidateScript({Test-Connection -ComputerName $_ -Count 1})]
      [String]$DhcpServer1,

      #The second DHCP server to be targeted
      [parameter(Mandatory=$True,Position=2)]
      [ValidateScript({Test-Connection -ComputerName $_ -Count 1})]
      [String]$DhcpServer2
      )


#Set strict mode to identify typographical errors
#Set-StrictMode -Version Latest


##########################################################################################################

########################################
## FUNCTION 1 - Execute-DhcpScopeChecks
########################################

#Builds a custom PSObject containing properties returned from each of the supplied checks

Function Execute-DhcpScopeChecks

($Checks, $DhcpServer, $DhcpServerScopes) 

{
    #Loop through the list of supplied scopes
    ForEach ($DhcpServerScope in $DhcpServerScopes) {

        #Create a custom PSObject to store scope information
        $DhcpScopeInfo = New-Object -TypeName PSObject -Property @{ScopeID = $DhcpServerScope}


        #Make sure the properties used in the custom object are empty
        $Properties = $Null
        $ExclusionStartRange = $Null
        $ExclusionEndRange = $Null
        $ReservationName = $Null
        $ReservationIPAddress = $Null
        $ReservationClientId = $Null
        $ReservationType = $Null
        $OptionName = $Null
        $OptionId = $Null
        $OptionValue = $Null

        #Perform each check, writing the results to a custom object
        ForEach ($Check in $Checks) {
            

            #Create a variable for the check (cmdlet) syntax
            $Command = "Get-$Check"


            #Execute the check
            $CheckResult = &$Command -ScopeId $DHCPServerScope -ComputerName $DhcpServer


            #Use Switch to manually define the parameters to be added to our custom object
            Switch ($Check) {
                
                ##Process the DhcpServerv4Scope check
                "DhcpServerv4Scope" {

                    #Define properties to be added to the custom scope object
                    $Properties = [Ordered]@{

                        Name = $CheckResult.Name
                        SubnetMask = $CheckResult.SubnetMask.IPAddressToString
                        ScopeStartRange = $CheckResult.StartRange.IPAddressToString
                        ScopeEndRange = $CheckResult.EndRange.IPAddressToString
                        Description = $CheckResult.Description
                        State = $CheckResult.State
                        Type = $CheckResult.Type
        
                    }   #End of $Properties...
                
                    
                    #Add the new property set to the custom scope object
                    $DhcpScopeInfo | Add-Member -NotePropertyMembers $Properties

                }   #End of "DhcpServerv4Scope"...


                ##Process the DhcpServerv4ExclusionRange check
                "DhcpServerv4ExclusionRange" {

                    #Convert returned arrays into single strings
                    $ExclusionStartRange = $CheckResult.StartRange.IPAddressToString -Join ", "
                    $ExclusionEndRange = $CheckResult.EndRange.IPAddressToString -join ", "


                    #Define properties to be added to the custom scope object
                    $Properties = [Ordered]@{

                        ExclusionStartRange = $ExclusionStartRange
                        ExclusionEndRange =  $ExclusionEndRange

        
                    }   #End of $Properties...
                
                    
                    #Add the new property set to the custom scope object
                    $DhcpScopeInfo | Add-Member -NotePropertyMembers $Properties
                
                
                }   #End of "DhcpServerv4ExclusionRange"...


                ##Process the DhcpServerv4Reservation check
                "DhcpServerv4Reservation"{

                    #Convert returned arrays into single strings if check is successful
                    If ($CheckResult) {
                    
                        $ReservationIPAddress = $CheckResult.IPAddress.IPAddressToString -Join ", "
                        $ReservationClientId = $CheckResult.ClientId -Join ", "
                        $ReservationType = $CheckResult.Type -Join ", "

                            ##As the reservation names may contain commas we need to handle this by wrapping them in quotation marks
                            #Loop though the option values returned
                            ForEach ($Result in $CheckResult) {
                    
                                #Combine the individual elements for each value manually adding ", " as a delimeter
                                $ReservationName += "`"$($Result.Name -Join ",")`", "


                            }   #End of ForEach ($Result in $CheckResult)


                        #Define properties to be added to the custom scope object
                        $Properties = [Ordered]@{

                            ReservationName = $ReservationName.TrimEnd(", ")
                            ReservationIPAddress = $ReservationIPAddress
                            ReservationClientId = $ReservationClientId
                            ReservationType = $ReservationType

        
                        }   #End of $Properties...
                
                    
                        #Add the new property set to the custom scope object
                        $DhcpScopeInfo | Add-Member -NotePropertyMembers $Properties


                    }   #End of If ($CheckResult)...
                
                
                }   #End of "DhcpServerv4Reservation"...


                ##Process the DhcpServerv4OptionValue check
                "DhcpServerv4OptionValue" {

                    #Convert returned arrays into single strings if check is successful
                    If ($CheckResult) {

                        $OptionId = $CheckResult.OptionId -Join ", "
                        $OptionName = $CheckResult.Name -Join ", "

                            ##As the option values may contain commas we need to handle this by wrapping them in quotation marks
                            #Loop though the option values returned
                            ForEach ($Result in $CheckResult) {
                    
                                #Combine the individual elements for each value manually adding "," as a delimeter
                                $OptionValue += "`"$($Result.Value -join ",")`", "


                            }   #End of ForEach ($Result in $CheckResult)
                    
                
                        #Define properties to be added to the custom scope object
                        $Properties = [Ordered]@{

                        OptionId = $OptionId 
                        OptionName = $OptionName 
                        OptionValue = $OptionValue.TrimEnd(", ")
                        
        
                        }   #End of $Properties...
                
                    
                        #Add the new property set to the custom scope object
                        $DhcpScopeInfo | Add-Member -NotePropertyMembers $Properties


                    }   #End of If ($CheckResult)...
                
                
                }   #End of "DhcpServerv4OptionValue"...


            }   #End of Switch ($Check)...


            #Spin up a progress bar for each DHCP server check processed
            Write-Progress -activity "Please wait... executing DHCP server checks..." -status "ScopeID: $DHCPServerScope" -percentcomplete -1


        }   #End of ForEach ($Check in $Checks)...


        #Add the fully populated custom object for the current scope to a parent array
        [Array]$TotalScopes += $DhcpScopeInfo


     }   #End of ForEach ($DhcpServerScope in $DhcpServerScopes)...


     #Return the fully populated custom scope object representing all scopes to MAIN
     Return $TotalScopes


 }   #End of Function Execute-DhcpScopeChecks...


##########################################################################################################

########################################
## FUNCTION 2 - Compare-MultipleObjects
########################################

#Run a DHCP command and compare the properties from a variable number of objects

Function Compare-MultipleObjects

($DhcpServer1, $DhcpServer2, $DhcpServer1CustomScopeInfo, $DhcpServer2CustomScopeInfo) 

{    #Rename Excel worksheet    $ExcelSheet = $ExcelBook.WorkSheets.Item(2)
    $ExcelSheet.Name = "Scope_Detail"    #Write DHCP Server details to Excel worksheet    $ExcelSheet.Cells.Item(1,2) = $DhcpServer1.ToUpper()    $ExcelSheet.Cells.Item(1,2).Font.Bold = $True    $ExcelSheet.Cells.Item(1,3) = $DhcpServer2.ToUpper()    $ExcelSheet.Cells.Item(1,3).Font.Bold = $True        #Obtain an array of properties from one of the sets of Cmdlet results (to be used later)        $Properties = $DhcpServer1CustomScopeInfo[0].PSObject.Properties.Name        

        #Create a discrepancy counter        $Discrepancies = 0


        #Excel row count
        $j = 2


        #Compare the Cmdlet outputs from the DHCP servers using the comparison property as a common reference
        $Comparison = Compare-Object -ReferenceObject $DhcpServer1CustomScopeInfo -DifferenceObject $DhcpServer2CustomScopeInfo -IncludeEqual -Property ScopeID


        #Check whether there are values (comparison objects) that occur on both servers
        If ($Comparison.SideIndicator -Contains "==") {

            #Write the details of values (comparison objects) that occur for both servers to a variable, using the comparison property as the common reference
            $Results = $Comparison | Where-Object {$_.SideIndicator -eq "=="} | Select ScopeID
     

            #Loop through the values (comparison objects) that occur on both DHCP servers
            ForEach ($Result in $Results) {


                #Reference a specific object from each of the collections of custom DHCP objects
                $TargetScopeInfo1 = $DhcpServer1CustomScopeInfo | Where-Object {$_.ScopeId -eq $Result.ScopeId}
                $TargetScopeInfo2 = $DhcpServer2CustomScopeInfo | Where-Object {$_.ScopeId -eq $Result.ScopeId}


                #Spin up a progress bar for each scopeID compared
                Write-Progress -activity "Please wait... comparing scope information..." -status "ScopeID: $($TargetScopeInfo1.ScopeID)" -percentcomplete -1


                #Loop through the array of properties (defined earlier) of the DHCP object, perform another comparison and write to Excel worksheet
                ForEach($Property in $Properties) {

                    #Write and compare supplied property                    $ExcelSheet.Cells.Item($j,1) = $Property                    $ExcelSheet.Cells.Item($j,1).Font.Bold = $True                    $ExcelSheet.Cells.Item($j,2) = $TargetScopeInfo1.$Property                    $ExcelSheet.Cells.Item($j,2).Interior.ColorIndex = 36                    $ExcelSheet.Cells.Item($j,3) = $TargetScopeInfo2.$Property                    $ExcelSheet.Cells.Item($j,3).Interior.ColorIndex = 28                    #Compare matching properties from both servers                    $Result = Compare-Object -ReferenceObject $TargetScopeInfo1 -DifferenceObject $TargetScopeInfo2 -IncludeEqual -Property $Property                    #Check for discrepancies                    If ($Result.SideIndicator -ne "==") {                                                #Highlight any discrepancies                        $ExcelSheet.Cells.Item($j,1).Interior.ColorIndex = 3                        #Increment the discrepancies counter                        $Discrepancies++                    }   #End of If ($Result.SideIndicator -ne "==") ...                    #Move onto the next row                    $j++                                   }   #End of ForEach($Property in $Properties)...            #Ensure we leave two lines between values            $j+=3               }   #End of ForEach ($Result in $Results)...                }   #End of If ($Comparison.SideIndicator -Contains "==")...        #Check whether there are unique values (objects) that exist only on the first DHCP server
        If ($Comparison.SideIndicator -Contains "<=") {

            #Create a counter to populate the unique values (objects) from the first DHCP server 
            $k = $j


            #Write the details of values (objects) that occur for just the first DHCP server to a variable, using the comparison property as the common reference
            $Results = $Comparison | Where-Object {$_.SideIndicator -eq "<="} | Select ScopeId
            

                #Query each returned comparison object
                ForEach ($Result in $Results) {

                    #Reference a specific object from the first server's collection of custom DHCP objects
                    $TargetScopeInfo = $DhcpServer1CustomScopeInfo | Where-Object {$_.ScopeId -eq $Result.ScopeId}


                    #Spin up a progress bar for each scopeID compared
                    Write-Progress -activity "Please wait... processing unique scopes for $DhcpServer1..." -status "ScopeId: $($TargetScopeInfo.ScopeID)" -percentcomplete -1
                

                    #Loop through each supplied property of the DHCP object and write to Excel worksheet
                    ForEach($Property in $Properties) {    

                            #Write the unique property to Excel
                            $ExcelSheet.Cells.Item($k,1) = $Property                            $ExcelSheet.Cells.Item($k,1).Font.Bold = $True                            $ExcelSheet.Cells.Item($k,2) = $TargetScopeInfo.$Property
                            $ExcelSheet.Cells.Item($k,2).Interior.ColorIndex = 43
                            
                            #Move onto the next row
                            $k++                       }   #End of ForEach($Property in $Properties)...                                #Ensure we leave two lines between values                $k+=3                   }   #End of ForEach ($Result in $Results)...        }   #End of If ($Comparison.SideIndicator -Contains "<=")...        
        #Check whether there are unique values (comparison objects) for the second DHCP server
        If ($Comparison.SideIndicator -Contains "=>") {

            #Write the details of values (comparison objects) that occur for just the second DHCP server to a variable, using the comparison property as the common reference
            $Results = $Comparison | Where-Object {$_.SideIndicator -eq "=>"} | Select ScopeId

                #Query each returned comparison object
                ForEach ($Result in $Results) {

                    #Reference a specific object from the first server's collection of custom DHCP objects
                    $TargetScopeInfo = $DhcpServer2CustomScopeInfo | Where-Object {$_.ScopeId -eq $Result.ScopeId}


                    #Spin up a progress bar for each scopeID compared
                    Write-Progress -activity "Please wait... processing unique scopes for $DhcpServer2..." -status "ScopeId: $($TargetScopeInfo.ScopeID)" -percentcomplete -1
                

                    #Loop through each supplied property of the DHCP object and write to Excel worksheet
                    ForEach($Property in $Properties) {    

                            #Write the unique property
                            $ExcelSheet.Cells.Item($j,1) = $Property                            $ExcelSheet.Cells.Item($j,1).Font.Bold = $True                            $ExcelSheet.Cells.Item($j,3) = $TargetScopeInfo.$Property
                            $ExcelSheet.Cells.Item($j,3).Interior.ColorIndex = 44

                            #Move onto the next row
                            $j++                       }   #End of ForEach($Property in $Properties)...                #Ensure we leave two lines between values                $j+=3                   }   #End of ForEach ($Result in $Results)...        }   #End of If ($Comparison.SideIndicator -Contains "=>")...


    #Tidy up the worksheet    $ExcelRange = $ExcelSheet.UsedRange    $ExcelRange.VerticalAlignment = 1    $ExcelRange.HorizontalAlignment = -4131    $ExcelRange.EntireColumn.AutoFit() | Out-Null


    #Return the custom totals object to MAIN
    Return $Discrepancies


}   #End of Function Compare-MultipleObjects...


##########################################################################################################

####################################
## FUNCTION 3 - Write-ScriptSummary
####################################

#Write DHCP scope summary information to the first worksheet

Function Write-ScopesSummary

($DhcpServer1, $DhcpServer2, $Discrepancies) 

{    #Rename Excel worksheet    $ExcelSheet = $ExcelBook.WorkSheets.Item(1)
    $ExcelSheet.Name = "Scope_Summary"    #Write DHCP Server details to Excel worksheet    $ExcelSheet.Cells.Item(1,2) = $DhcpServer1.ToUpper()    $ExcelSheet.Cells.Item(1,2).Font.Bold = $True    $ExcelSheet.Cells.Item(1,3) = $DhcpServer2.ToUpper()    $ExcelSheet.Cells.Item(1,3).Font.Bold = $True


    #Get DHCP Server Statistics for each server
    $DhcpServer1Stats = Get-DhcpServerv4Statistics -ComputerName $DhcpServer1
    $DhcpServer2Stats = Get-DhcpServerv4Statistics -ComputerName $DhcpServer2 


    #Write some of the statistics to Excel
    $ExcelSheet.Cells.Item(2,1) = "TotalScopes"
    $ExcelSheet.Cells.Item(2,2) = $DhcpServer1Stats.TotalScopes
    $ExcelSheet.Cells.Item(2,3) = $DhcpServer2Stats.TotalScopes

    $ExcelSheet.Cells.Item(3,1) = "TotalAddresses"
    $ExcelSheet.Cells.Item(3,2) = $DhcpServer1Stats.TotalAddresses
    $ExcelSheet.Cells.Item(3,3) = $DhcpServer2Stats.TotalAddresses


    #Write the number of discrepancies to Excel
    $ExcelSheet.Cells.Item(5,1) = "TotalDiscrepancies"
    $ExcelSheet.Cells.Item(5,1).Font.Bold = $True
    $ExcelSheet.Cells.Item(5,2) = $Discrepancies
    $ExcelSheet.Cells.Item(5,3) = $Discrepancies


    #Tidy up the worksheet    $ExcelRange = $ExcelSheet.UsedRange    $ExcelRange.VerticalAlignment = 1    $ExcelRange.HorizontalAlignment = -4131    $ExcelRange.EntireColumn.AutoFit() | Out-Null

}

##########################################################################################################

##########################
## SCRIPT 'CONTROL PANEL'
##########################

<#Comment out any checks not required:
  - Do not comment out the "DhcpServerv4Scope" check
  - Also, if you are planning to use the companion failover configuration script, 
    leave all checks in place
#>

$Checks = @(
     
    ##Do not comment out 
    "DhcpServerv4Scope"
    
    ##Can be commented out  
    "DhcpServerv4ExclusionRange" 
    "DhcpServerv4OptionValue" 
    "DhcpServerv4Reservation"

)

#Ensure that the "DhcpServerv4Scope" check is included at position 0 of the checks array
If ($Checks[0] -ne "DhcpServerv4Scope") {

    #Write a custom error 
    Write-Error "DhcpServerv4Scope not found at postion 0 of the checks the array. Script execution stopped."
    Exit 1

}   #End of If ($Checks[0] -ne "DhcpServerv4Scope")...


##########################################################################################################

########
## MAIN
########

#Instantiate an Excel COM object
$Excel = New-Object -ComObject Excel.Application


    #Exit script if Excel not found (check last execution status variable)
    If (-Not $?) {

        #Write a custom error 
        Write-Error "Excel not installed. Script execution stopped."
        Exit 2

    }   #End of If (-Not $?)...


#Add a workbook with the same number of sheets as checks
$Excel.SheetsInNewWorkbook = 2
$ExcelBook = $Excel.Workbooks.Add()
$ExcelSheets = $ExcelBook.Sheets


#Get the scope information for both DHCP servers
$DhcpServer1Scopes = (Get-DhcpServerv4Scope -ComputerName $DhcpServer1).ScopeID.IPAddressToString
$DhcpServer2Scopes = (Get-DhcpServerv4Scope -ComputerName $DhcpServer2).ScopeID.IPAddressToString


<#Call the Execute-DhcpScopeChecks function for the scopes identified on each of the DHCP servers
The function will create an array of custom PSObjects containing information from all checks passed#>
$DhcpServer1CustomScopeInfo = Execute-DhcpScopeChecks $Checks $DhcpServer1 $DhcpServer1Scopes
$DhcpServer2CustomScopeInfo = Execute-DhcpScopeChecks $Checks $DhcpServer2 $DhcpServer2Scopes


#Call the Compare-MultipleObjects function to analyse the two custom objects and write the results to Excel
$Discrepancies = Compare-MultipleObjects $DhcpServer1 $DhcpServer2 $DhcpServer1CustomScopeInfo $DhcpServer2CustomScopeInfo


#Call the Write-ScopesSummary to add totals to worksheet 1
Write-ScopesSummary $DhcpServer1 $DhcpServer2 $Discrepancies


<#And, finally...
Create a variable to represent a new report file, constructing the report name from date details (padded)#>
$SourceParent = (Get-Location).Path
$Date = Get-Date
$NewReport = "$SourceParent\" + `             "$($Date.Year)" + `             "$("{0:D2}" -f $Date.Month)" + `             "$("{0:D2}" -f $Date.Day)" + `             "$("{0:D2}" -f $Date.Hour)" + `             "$("{0:D2}" -f $Date.Minute)" + `             "$("{0:D2}" -f $Date.Second)" + `
             "_$($DhcpServer1.ToUpper())_$($DhcpServer2.ToUpper())_DHCP_Scope_Comparison.xls"
             #"_$($DhcpServer1.ToUpper())_$($DhcpServer2.ToUpper())_DHCP_Scope_Comparison.xlsx"


#Save and close the spreadhseet
$ExcelBook.SaveAs($NewReport)
$Excel.Quit()


#Release Excel COM object
$Release = [System.Runtime.Interopservices.Marshal]::ReleaseComObject($Excel)
