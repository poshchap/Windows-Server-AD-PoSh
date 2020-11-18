##########################################################################################################
<#
.SYNOPSIS
    Queries two DHCP servers, comparing server settings by using the Windows Server 2012 DHCP Cmdlets.

.DESCRIPTION
    Queries two supplied DHCP servers, comparing server settings by using a variety of Windows Server 2012 DHCP Cmdlets.
    The DHCP Cmdlets (checks) executed can be determined by a script 'control panel' The results of each check are then 
    written to a separate worksheet in an Excel document for readability. 
    
    Here are the checks:

        * Audit Log
        * Database
        * DHCP Server Settings
        * DHCP Server Version
        * IPv4 Classes
        * IPv4 DNS Settings
        * IPv4 Failover (information rather than comparison)
        * IPv4 Filter List Status
        * IPv4 Option Definitions
        * IPv4 Option Values
        * IPv4 Policy
        * IPv4 Statistics (information rather than comparison)  

    Checks not included:

        * IPv4 Bindings
        * IPv4 Exclusion Ranges
        * IPv4 Filter
        * IPv4 Scopes
        * IPv4 Scope Statistics
        * IPv4 Superscopes
        * IPv6 Checks

    Differences between the two servers are identified thus:

        * Matching objects are presented side by side in yellow and turquoise for ease of comparison
        * For matching objects, specific property discrepancies will have the property name 
          highlighted in red
        * Objects that are unique to one server will be highlighted in either green (server 1) 
          or orange (server 2) after any matching object comparisons

    Control Panel:

        * Provides the ability to comment out DHCP server checks not required

    Requirements:
        * PowerShell v3
        * DhcpServer PS module
        * Excel
        * Parameter 1: target DHCP server 1
        * Parameter 2: target DHCP server 2

.EXAMPLE
   .\Compare_Dhcp_Server_Settings.ps1 -DhcpServer1 CORPDHCP1 -DhcpServer2 CORPDHCP2

   This will compare the server settings on CORPDHCP1 to those on CORPDHCP2 and write the results to 
   an Excel spreadsheet in the same folder as the script.

.OUTPUTS
   <YearMonthDayHourMinuteSecond>_<DhcpServer1>_<DhcpServer2>_DHCP_Server_Comparison.xls

   EXIT CODES: 1 - Excel not installed

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
      #The first DHCP server to be targetted
      [parameter(Mandatory=$True,Position=1)]
      [ValidateScript({Test-Connection -ComputerName $_ -Count 1})]
      [String]$DhcpServer1,

      #The second DHCP server to be targetted
      [parameter(Mandatory=$True,Position=2)]
      [ValidateScript({Test-Connection -ComputerName $_ -Count 1})]
      [String]$DhcpServer2
      )


#Set strict mode to identify typographical errors (uncomment whilst editing script)
#Set-StrictMode -Version Latest


##########################################################################################################

#####################################
## FUNCTION 1 - Compare-SingleObject
#####################################


#Run a DHCP command and compares the properties of an expected number of objects 

Function Compare-SingleObject 

($DhcpCmdlet, $DhcpServer1, $DhcpServer2, $SheetNumber, $SheetName) 

{    #Rename Excel worksheet    $ExcelSheet = $ExcelBook.WorkSheets.Item($SheetNumber)
    $ExcelSheet.Name = "$SheetName"    #Write DHCP Server details to Excel worksheet    $ExcelSheet.Cells.Item(1,2) = $DhcpServer1.ToUpper()    $ExcelSheet.Cells.Item(1,2).Font.Bold = $True    $ExcelSheet.Cells.Item(1,3) = $DhcpServer2.ToUpper()    $ExcelSheet.Cells.Item(1,3).Font.Bold = $True            <#Interogate each DHCP server by running the supplied check (DHCP cmdlet) and write the results to variables...     Use call operator to avoid interpretation of command parameters#>    $Output1 = &$DhcpCmdlet -ComputerName $DhcpServer1    $Output2 = &$DhcpCmdlet -ComputerName $DhcpServer2    #Excel row count    $j = 2    #Check that we have an output from both executed DHCP cmdlets    If (($Output1 -ne $Null) -and ($Output2 -ne $Null)) {        #Obtain an array of properties from one of the sets of Cmdlet results         $Properties = ($Output1[0] | Get-Member -Type Properties).Name                  #Loop through each supplied property, performing a comparison and writing the results to Excel worksheet        ForEach ($Property in $Properties) {                        #Don't write anything if both properties are empty            If ((($Output1).$Property -ne $Null) -and (($Output2).$Property -ne $Null)) {                #Write supplied properties                $ExcelSheet.Cells.Item($j,1) = $Property                $ExcelSheet.Cells.Item($j,1).Font.Bold = $True                $ExcelSheet.Cells.Item($j,2) = ($Output1).$Property                $ExcelSheet.Cells.Item($j,2).Interior.ColorIndex = 36                $ExcelSheet.Cells.Item($j,3) = ($Output2).$Property                $ExcelSheet.Cells.Item($j,3).Interior.ColorIndex = 28                #Compare matching properties from both servers                $Result = Compare-Object -ReferenceObject $Output1 -DifferenceObject $Output2 -IncludeEqual -Property $Property                    If ($Result.SideIndicator -ne "==") {                        $ExcelSheet.Cells.Item($j,1).Interior.ColorIndex = 3                    }   #End of If ($Result.SideIndicator -ne "==")                #Increment Excel row count                $j++                        }   #End of If ((($Output1).$Property -ne $Null) -and (($Output2).$Property -ne $Null))...        }   #End of ForEach ($Property in $Properties)...    }   #End of If (($Output1 -ne $Null) -and ($Output2 -ne $Null))...    Else {                #Write failure to obtain information from at least DHCP server to Excel worksheet        $ExcelSheet.Cells.Item(2,2) = "Comparison not performed: information not obtained from one or both DHCP servers"        $ExcelSheet.Cells.Item(2,3) = "Comparison not performed: information not obtained from one or both DHCP servers"    }   #End of Else (($Output1 -ne $Null) -and ($Output2 -ne $Null))...    #Tidy up the Excel worksheet    $ExcelRange = $ExcelSheet.UsedRange    $ExcelRange.VerticalAlignment = 1    $ExcelRange.HorizontalAlignment = -4131    $ExcelRange.EntireColumn.AutoFit() | Out-Null


}   #End of Function Compare-SingleObject...


##########################################################################################################

########################################
## FUNCTION 2 - Compare-MultipleObjects
########################################

#Run a DHCP command and compare the properties from a variable number of objects

Function Compare-MultipleObjects

($DhcpCmdlet, $DhcpServer1, $DhcpServer2, $SheetNumber, $SheetName, $ComparisonProperty) 

{    #Rename Excel worksheet    $ExcelSheet = $ExcelBook.WorkSheets.Item($SheetNumber)
    $ExcelSheet.Name = "$SheetName"    #Write DHCP Server details to Excel worksheet    $ExcelSheet.Cells.Item(1,2) = $DhcpServer1.ToUpper()    $ExcelSheet.Cells.Item(1,2).Font.Bold = $True    $ExcelSheet.Cells.Item(1,3) = $DhcpServer2.ToUpper()    $ExcelSheet.Cells.Item(1,3).Font.Bold = $True    #Interogate each DHCP server by running the supplied check (DHCP cmdlet) and write the results to variables...     #Use call operator to avoid interpretation of command parameters    $Output1 = &$DhcpCmdlet -ComputerName $DhcpServer1    $Output2 = &$DhcpCmdlet -ComputerName $DhcpServer2    #Check that we have an output from both executed DHCP cmdlets    If (($Output1 -ne $Null) -and ($Output2 -ne $Null)) {        #Obtain an array of properties from one of the sets of Cmdlet results (to be used later)        $Properties = ($Output1[0] | Get-Member -Type Properties).Name         #Compare the Cmdlet outputs from the DHCP servers using the comparison property as a common reference
        $Comparison = Compare-Object -ReferenceObject $Output1 -DifferenceObject $Output2 -IncludeEqual -Property $ComparisonProperty        

        #Excel row count
        $j = 2


        #Check whether there are values (comparison objects) that occur on both servers
        If ($Comparison.SideIndicator -Contains "==") {

            #Write the details of values (comparison objects) that occur for both servers to a variable, using the comparison property as the common reference
            $Results = $Comparison | Where-Object {$_.SideIndicator -eq "=="} | Select $ComparisonProperty
     

            #Loop through the values (comparison objects) that occur on both DHCP servers
            ForEach ($Result in $Results) {


                #Call the check again (DHCP cmdlet) targeting a single value (DHCP object) on each server
                #Use call operator to avoid interpretation of command parameters
                $Value1 = &$DhcpCmdlet $Result.$ComparisonProperty -ComputerName $DhcpServer1
                $Value2 = &$DhcpCmdlet $Result.$ComparisonProperty -ComputerName $DhcpServer2


                #Loop through the array of properties (defined earlier) of the DHCP object, perform another comparison and write to Excel worksheet
                ForEach($Property in $Properties) {
                    

                    #Ensure both proerty values aren't empty
                    If (($Value1.$Property -ne $Null) -and ($Value2.$Property -ne $Null)) {


                        #Write and compare supplied property                        $ExcelSheet.Cells.Item($j,1) = $Property                        $ExcelSheet.Cells.Item($j,1).Font.Bold = $True                        $ExcelSheet.Cells.Item($j,2) = $Value1.$Property                        $ExcelSheet.Cells.Item($j,2).Interior.ColorIndex = 36                        $ExcelSheet.Cells.Item($j,3) = $Value2.$Property                        $ExcelSheet.Cells.Item($j,3).Interior.ColorIndex = 28                        #Compare matching properties from both servers                        $Result = Compare-Object -ReferenceObject $Value1 -DifferenceObject $Value2 -IncludeEqual -Property $Property                        #Highlight any discrepencies                        If ($Result.SideIndicator -ne "==") {                            $ExcelSheet.Cells.Item($j,1).Interior.ColorIndex = 3                        }   #End of If ($Result.SideIndicator -ne "==") ...                        #Move onto the next row                        $j++                       }   #End of If (($Value1.$Property -ne $Null) -and ($Value2.$Property -ne $Null))...                                }   #End of ForEach($Property in $Properties)...            #Ensure we leave two lines between values            $j+=3               }   #End of ForEach ($Result in $Results)...                }   #End of If ($Comparison.SideIndicator -Contains "==")...        #Check whether there are unique values (objects) that exist only on the first DHCP server
        If ($Comparison.SideIndicator -Contains "<=") {

            #Create a counter to populate the unique values (objects) from the first DHCP server 
            $k = $j


            #Write the details of values (objects) that occur for just the first DHCP server to a variable, using the comparison property as the common reference
            $Results = $Comparison | Where-Object {$_.SideIndicator -eq "<="} | Select $ComparisonProperty
            

                #Query each returned comparison object
                ForEach ($Result in $Results) {

                    #Call the check again (DHCP cmdlet) targeting a single value (DHCP object)
                    $Value1 = &$DhcpCmdlet $Result.$ComparisonProperty -ComputerName $DhcpServer1
                

                    #Loop through each supplied property of the DHCP object and write to Excel worksheet
                    ForEach($Property in $Properties) {
                    
                        #Ensure the PSComputer property value isn't written to Excel
                        If ($Property -ne "PSComputer") {        

                            #Write the unique property to Excel
                            $ExcelSheet.Cells.Item($k,1) = $Property                            $ExcelSheet.Cells.Item($k,1).Font.Bold = $True                            $ExcelSheet.Cells.Item($k,2) = $Value1.$Property
                            $ExcelSheet.Cells.Item($k,2).Interior.ColorIndex = 43
                            
                            #Move onto the next row
                            $k++                           }   #End of If ($Property -ne "PSComputer")...                    }   #End of ForEach($Property in $Properties)...                                #Ensure we leave two lines between values                $k+=3                   }   #End of ForEach ($Result in $Results)...        }   #End of If ($Comparison.SideIndicator -Contains "<=")...        
        #Check whether there are unique values (comparison objects) for the second DHCP server
        If ($Comparison.SideIndicator -Contains "=>") {

            #Write the details of values (comparison objects) that occur for just the second DHCP server to a variable, using the comparison property as the common reference
            $Results = $Comparison | Where-Object {$_.SideIndicator -eq "=>"} | Select $ComparisonProperty
            

                #Query each returned comparison object
                ForEach ($Result in $Results) {

                    #Call the check again (DHCP cmdlet) targeting a single value (DHCP object)
                    $Value1 = &$DhcpCmdlet $Result.$ComparisonProperty -ComputerName $DhcpServer2
                

                    #Loop through each supplied property of the DHCP object and write to Excel worksheet
                    ForEach($Property in $Properties) {
                    
                        #Ensure the PSComputer property value isn't written
                        If ($Property -ne "PSComputer") {        

                            #Write the unique property
                            $ExcelSheet.Cells.Item($j,1) = $Property                            $ExcelSheet.Cells.Item($j,1).Font.Bold = $True                            $ExcelSheet.Cells.Item($j,3) = $Value1.$Property
                            $ExcelSheet.Cells.Item($j,3).Interior.ColorIndex = 44

                            #Move onto the next row
                            $j++                           }   #End of If ($Property -ne "PSComputer")...                    }   #End of ForEach($Property in $Properties)...                #Ensure we leave two lines between values                $j+=3                   }   #End of ForEach ($Result in $Results)...        }   #End of If ($Comparison.SideIndicator -Contains "=>")...    }   #End of If (($Output1 -ne $Null) -and ($Output2 -ne $Null))...    Else {                #Write failure to obtain information from at least DHCP server to Excel worksheet        $ExcelSheet.Cells.Item(2,2) = "Comparison not performed: information not obtained from one or both DHCP servers"        $ExcelSheet.Cells.Item(2,3) = "Comparison not performed: information not obtained from one or both DHCP servers"    }   #End of Else (($Output1 -ne $Null) -and ($Output2 -ne $Null))...    #Tidy up the worksheet    $ExcelRange = $ExcelSheet.UsedRange    $ExcelRange.VerticalAlignment = 1    $ExcelRange.HorizontalAlignment = -4131    $ExcelRange.EntireColumn.AutoFit() | Out-Null


}   #End of Function Compare-MultipleObjects...



##########################################################################################################

##########################
## SCRIPT 'CONTROL PANEL'
##########################

#Comment out any checks not required
$Checks = @(

    "DhcpServerAuditLog"
    "DhcpServerDatabase"
    "DhcpServerSetting"
    "DhcpServerVersion"
    "DhcpServerv4Class"
    "DhcpServerv4DnsSetting"
    #"DhcpServerv4Failover"       #Add for information not comparison
    "DhcpServerv4FilterList"
    "DhcpServerv4OptionDefinition"
    "DhcpServerv4OptionValue"
    "DhcpServerv4Policy"
    #"DhcpServerv4Statistics"     #Add for information not comparison

)


##########################################################################################################

########
## MAIN
########

#Count the number of checks to be performed 
$NumberofChecks = $Checks.Count

#Instantiate an Excel COM object
$Excel = New-Object -ComObject Excel.Application


#Exit script if Excel not found (check last execution status variable)
If (-Not $?) {

    #Write a custom error 
    Write-Error "Excel not installed. Script execution stopped."
    Exit 1

}   #End of If (-Not $?)...


#Add a workbook with the same number of sheets as checks
$Excel.SheetsInNewWorkbook = $NumberofChecks
$ExcelBook = $Excel.Workbooks.Add()
$ExcelSheets = $ExcelBook.Sheets


#Create a check counter to pass the worksheet number
$i = 1


#Now for the good stuff... loop through the checks and call the relevant function with relevant parameters
ForEach ($Check in $Checks) {

    <#Use switch to set a variable that determines which function to execute
    The function for multiple values also requires a comparison property which is set here#>
    Switch ($Check) {

        "DhcpServerAuditLog" {$Single = $True}

        "DhcpServerDatabase" {$Single = $True}

        "DhcpServerSetting" {$Single = $True}

        "DhcpServerVersion" {$Single = $True}

        "DhcpServerv4Class" {$Single = $False; $ComparisonProperty = "Name"}

        "DhcpServerv4DnsSetting" {$Single = $True}

        "DhcpServerv4Failover" {$Single = $False; $ComparisonProperty = "Name"}

        "DhcpServerv4FilterList" {$Single = $True}

        "DhcpServerv4OptionDefinition" {$Single = $False; $ComparisonProperty = "OptionID"}

        "DhcpServerv4OptionValue" {$Single = $False; $ComparisonProperty = "OptionID"}

        "DhcpServerv4Policy" {$Single = $False; $ComparisonProperty = "Name"}

        "DhcpServerv4Statistics" {$Single = $True}


    }   #End of Switch ($Check)...


    #Define the parameter set to be passed to the relevant function
    If ($Single) { 

        #Splatted parameters
        $Parameters = @{
 
            DhcpCmdlet = "Get-$Check"
            DhcpServer1 = $DhcpServer1
            DhcpServer2 = $DhcpServer2
            SheetNumber = $i
            SheetName = $Check


        }   #End of $Parameters


        #Target function
        $Function = "Compare-SingleObject"


    }   #End of If ($Single)...

    Else {

        #Splatted parameters
        $Parameters = @{
 
            DhcpCmdlet = "Get-$Check"
            DhcpServer1 = $DhcpServer1
            DhcpServer2 = $DhcpServer2
            SheetNumber = $i
            SheetName = $Check
            ComparisonProperty = $ComparisonProperty


        }   #End of $Parameters


        #Target function
        $Function = "Compare-MultipleObjects"


    }   #End of Else  ($Single)...


    #Spin up a progress bar for each DHCP server check processed
    Write-Progress -activity "Please wait... processing DHCP server check - $Check" -status "Checks completed: $($i -1)" -percentcomplete -1


    <#Call the relevant function, with the correct paramter set, to perform the check
    Use call operator to allow splatted parameters to be passed#>
    &$Function @Parameters


    #Increment our check counter
    $i++
   

}   #End of ForEach ($Check in $Checks)...


<#And, finally...
Create a variable to represent a new report file, constructing the report name from date details (padded)#>
$SourceParent = (Get-Location).Path
$Date = Get-Date
$NewReport = "$SourceParent\" + `             "$($Date.Year)" + `             "$("{0:D2}" -f $Date.Month)" + `             "$("{0:D2}" -f $Date.Day)" + `             "$("{0:D2}" -f $Date.Hour)" + `             "$("{0:D2}" -f $Date.Minute)" + `             "$("{0:D2}" -f $Date.Second)" + `
             "_$($DhcpServer1.ToUpper())_$($DhcpServer2.ToUpper())_DHCP_Server_Comparison.xls"
             #"_$($DhcpServer1.ToUpper())_$($DhcpServer2.ToUpper())_DHCP_Server_Comparison.xlsx"


#Save and close the spreadhseet
$ExcelBook.SaveAs($NewReport)
$Excel.Quit()


#Release Excel COM object
$Release = [System.Runtime.Interopservices.Marshal]::ReleaseComObject($Excel)