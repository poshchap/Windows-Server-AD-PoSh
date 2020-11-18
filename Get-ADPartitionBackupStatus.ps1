Function Get-ADPartitionBackupStatus {

##########################################################################################################
<#
.SYNOPSIS
    For each partition on a domain controller checks the last backup time.

.DESCRIPTION
    Uses AD replication metadata to retrieve last backup information on for all naming contexts on
    a single DC or a supplied list of DCs.
    
    Writes a warning to screen if an NC hasn't been backed up within the supplied number of days ($BackupThreshold).
    
    Can produce a CSV report of the last backup time of each directory partiton with the use of the
    -CsvOutput switch.

.EXAMPLE
    Get-ADPartitionBackupStatus -DC NINJADC01 -BackupThreshold 2

    Writes to screen the details of any naming contexts not backed up within the last two days 
    on the domain controller NINJADC01.

.EXAMPLE
    (Get-ADForest).Domains | 
    ForEach-Object {Get-ADDomainController -Filter * -Server $_} | 
    Get-ADPartitionBackupStatus -CsvOutput

    Checks all domain controllers in the forest and writes to screen the details of any naming 
    contexts not backed up within the last seven days. 

    Creates a CSV report in the current working directory containing the last backup time of 
    every partition of every domain controller in the forest.

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

    ##Define and validate parameters
    [CmdletBinding()]
    Param(
          #The target domain controller(s)
          [parameter(Mandatory,Position=1,ValueFromPipeline)]
          [ValidateScript({Get-ADDomainController -Identity $_})] 
          $DC,
          
          ##The number of days after which we flag that a partition hasn't been backed up
          [parameter(Mandatory = $false,Position=2)]
          [ValidateRange(1,180)] 
          [Int32]$BackupThreshold = 7,

          #Whether to create a CSV report
          [switch]
          $CsvOutput
          )

    ##Begin block
    Begin {

        #Obtain a datetime object before which accounts are considered stale
        $DaysAgo = (Get-Date).AddDays(-$BackupThreshold) 

        #Check if we need to create a CSV report
        If ($CsvOutput) {

            #Specify a CSV report
            $CsvReport = ".\$(Get-Date -Format yyMMddHHmmss)_AD_DC_NC_Backup_Report.csv"

            #Add header to CSV Report
            Add-Content -Value "DC_NAME,PARTITION_NAME,BACKUP_DATE" -Path $CsvReport

        }   #End of If ($CsvReport)
    
    }   #End of Begin block


    ##Process block
    Process {
        
        #Nullify the $Partitions variable
        $Partitions = $null

        #Get a list of partitions on our DC
        $Partitions = (Get-ADRootDSE -Server $DC).namingContexts

        #Check we have partitions
        if ($Partitions) {
        
            #Loop through each partition
            foreach ($Partition in $Partitions) {

                #Nullify the $Object variable                $Object = $null

                #Get the replication metadate for the current partition using a constructed attribute
                $Object = Get-ADObject -Identity $Partition -Properties msDS-ReplAttributeMetaData -Server $DC -ErrorAction SilentlyContinue

                #Check we have an object
                If ($Object) {
    
                    #Loop through each object in the metadata
                    $Object."msDS-ReplAttributeMetaData" | ForEach-Object {
        
                        #Replace trailing null character
                        $MetaData = [XML]$_.Replace("`0","")

                        #Loop through the XML nodes
                        $MetaData.DS_REPL_ATTR_META_DATA | ForEach-Object {

                            #Check for dSASignature attribute
                            If ($_.pszAttributeName -eq "dSASignature") {

                                #Create a date time object for the time of the last backup
                                 $LastBackup = Get-Date $_.ftimeLastOriginatingChange 

                                #Check and report on the date of the update
                                If ($LastBackup -lt $DaysAgo) {

                                    #Write details to console
                                    Write-Warning -Message "$DC - The directory partition $Partition was last backed up on $(($LastBackup).DateTime)"

                                }   #End of If ($LastBackup -lt $DaysAgo)

                                #Check if we need to create a CSV report
                                If ($CsvOutput) {

                                    #Add information to our report
                                    Add-Content -Value "$DC,`"$Partition`",$(($LastBackup).DateTime)" -Path $CsvReport

                                }   #End of If ($CsvReport)

                            }   #End of If ($_.pszAttributeName -eq "dSASignature")

                        }   #End of ForEach-Object 
    
                    }   #End of ForEach-Object

                }   #End of If ($Object)

            }   #End of foreach ($Partition in $Partitions)

        }   #End of If ($Partitions)

    }   #End of Process block

}   #End of Function Get-ADPartitionBackupStatus

