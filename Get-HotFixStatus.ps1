﻿<#
.SYNOPSIS
	Search a computer/s for the install status of a particular Microsoft HotFix (Patch)
.DESCRIPTION
	Search a computer/s for the install status of a particular Microsoft HotFix (Patch)

	You must supply the hotfix name in the format of KBxxxxxxx (EX: KB3011768)
.PARAMETER ComputerName
	Name of computer / computers
.PARAMETER HotFixID
	Name of HotFix to search for
.PARAMETER MostRecent
	Use this switch param to identify what the last patch installed was and when it was installed
.INPUTS
	System.String
.OUTPUTS
	System.Management.Automation.PSCustomObject
.EXAMPLE
	.\Get-HotFixStatus.ps1 -ComputerName SERVER1.corp.com, SERVER2.corp.com -HotFixID KB3011780 -Verbose | Format-Table -Autosize
.EXAMPLE
	.\Get-HotFixStatus.ps1 -ComputerName (Get-Content C:\ServerList.txt) -HotFixID KB3011780 -Verbose | Export-Csv C:\ServerPatchReport.csv -NoTypeInformation
.NOTES
	20141119	K. Kirkpatrick		[+] Created
	20141124	K. Kirkpatrick		[+] Cleaned up the way objects get stored to final $Results array
									[+] Added -MostRecent switch variable which will return the most recent installed patch

	#TAG:PUBLIC

	GitHub:	 https://github.com/vN3rd
	Twitter:  @vN3rd
	Email:	 kevin@pinelabs.co

[-------------------------------------DISCLAIMER-------------------------------------]
 All script are provided as-is with no implicit
 warranty or support. It's always considered a best practice
 to test scripts in a DEV/TEST environment, before running them
 in production. In other words, I will not be held accountable
 if one of my scripts is responsible for an RGE (Resume Generating Event).
 If you have questions or issues, please reach out/report them on
 my GitHub page. Thanks for your support!
[-------------------------------------DISCLAIMER-------------------------------------]
#>


[cmdletbinding(DefaultParameterSetName = "Default")]
param (
	[parameter(Mandatory = $false,
			   Position = 0,
			   ValueFromPipeline = $true,
			   ValueFromPipelineByPropertyName = $true)]
	[alias("Comp", "CN")]
	[string[]]$ComputerName = "localhost",

	[parameter(Mandatory = $true,
			   Position = 1,
			   ValueFromPipeline = $true,
			   ValueFromPipelineByPropertyName = $true,
			   HelpMessage = "Enter full HotFix ID (ex: KB1234567) ",
			   ParameterSetName = "Default")]
	[alias("HotFix", "Patch")]
	[validatepattern('^KB\d{7}$')]
	[string]$HotFixID,

	[parameter(Mandatory = $false,
			   Position = 2,
			   ParameterSetName = "MostRecent")]
	[switch]$MostRecent

)

BEGIN
{
	# Set global EA pref so that all errors are treated as terminating and get caught in the 'catch' block
	$ErrorActionPreference = [System.Management.Automation.ActionPreference]::Stop

	# define the final results array
	$Results = @()

}# BEGIN

PROCESS
{
	foreach ($C in $ComputerName)
	{
		# Create counter variable and increment by 1 for each item in the collection
		$i++

		# Call out variables and set/reset values
		$hotfixQuery = $null
		$objHotFix = @()

		# If connectivity to remote system is successful, continue
		if (Test-Connection $C -Count 2 -Quiet)
		{
			if ($MostRecent)
			{
				try
				{
					Write-Verbose -Message "Searching for most recent HotFix on $($C.toupper())"

					$hotfixQuery = (Get-HotFix -ComputerName $C -ErrorAction 'SilentlyContinue' |
					Where-Object { $_.InstalledOn -ne $null } |
					Sort-Object InstalledOn -Descending)[0]

					# Create obj for reachable systems
					$objHotFix = [PSCustomObject] @{
						SystemName = $C.ToUpper()
						Description = $hotfixQuery.Description
						HotFixID = $hotfixQuery.HotFixID
						InstalledBy = $hotfixQuery.InstalledBy
						InstalledOn = $hotfixQuery.InstalledOn
						Error = if ($hotfixQuery.HotFixID -eq $null) { "System reachable but errors may have been encountered collecting HotFix details" }
					}# $objSvc

					# add obj data to final results array
					$Results += $objHotFix

				} catch
				{
					Write-Warning -Message "$C - $_"

					# Store data in obj for systems that are reachable but incur an error
					$objHotFix = [PSCustomObject] @{
						SystemName = $C.ToUpper()
						Description = $null
						HotFixID = $null
						InstalledBy = $null
						InstalledOn = $null
						Error = $_
					}# objHotFix

					# add obj data to final results array
					$Results += $objHotFix

				}# try/catch

			} else
			{
				try
				{
					Write-Verbose -Message "Searching for HotFix ID $($HotFixID.toupper()) on $($C.toupper())"

					$hotfixQuery = Get-HotFix -Id $HotFixID -ComputerName $C -ErrorAction 'SilentlyContinue' |
					Where-Object { $_.HotFixID -ne 'File 1' }

					# Create obj for reachable systems
					$objHotFix = [PSCustomObject] @{
						SystemName = $C.ToUpper()
						Description = $hotfixQuery.Description
						HotFixID = $hotfixQuery.HotFixID
						InstalledBy = $hotfixQuery.InstalledBy
						InstalledOn = $hotfixQuery.InstalledOn
						Error = if ($hotfixQuery.HotFixID -eq $null) { "HotFix $($HotFixID.toupper()) does not appear to be installed" }
					}# $objSvc

					# add obj data to final results array
					$Results += $objHotFix

				} catch
				{
					Write-Warning -Message "$C - $_"

					# Store data in obj for systems that are reachable but incur an error
					$objHotFix = [PSCustomObject] @{
						SystemName = $C.ToUpper()
						Description = $null
						HotFixID = $null
						InstalledBy = $null
						InstalledOn = $null
						Error = $_
					}# objHotFix


					# add obj data to final results array
					$Results += $objHotFix

				}# try/catch

			}# if/else

		} else
		{
			Write-Warning -Message "$C is unreachable"

			# Capture unreachable systems and store the output in an object
			$objHotFix = [PSCustomObject] @{
				SystemName = $C.ToUpper()
				Description = $null
				HotFixID = $null
				InstalledBy = $null
				InstalledOn = $null
				Error = "$C is unreachable"
			}# $objHotFix

			# add obj data to final results array
			$Results += $objHotFix

		}# else

		# Write total progress to progress bar
		$TotalServers = $ComputerName.Length
		$PercentComplete = [int](($i / $TotalServers) * 100)
		Write-Progress -Activity "Working..." -CurrentOperation "$PercentComplete% Complete" -Status "Percent Complete" -PercentComplete $PercentComplete

	}# foreach

}# PROCESS

END
{
	# Call the results object
	$Results

}# END