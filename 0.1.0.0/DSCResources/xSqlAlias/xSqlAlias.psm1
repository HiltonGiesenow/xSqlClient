function Get-TargetResource
{
    [CmdletBinding()]
    [OutputType([System.Collections.Hashtable])]
    param
    (
        [parameter(Mandatory = $true)]
        [System.String]
        $ServerAlias,

        [ValidateSet("Present","Absent")]
        [System.String]
        $Ensure = "Present",
		
        [parameter(Mandatory = $true)]
        [System.String]
        $ServerName,

        [System.Int32]
        $Port,
		
        [ValidateSet("32Bit","64Bit","Both")]
        [System.String]
        $Architecture = "32Bit"
    )

    #Write-Verbose "Checking for Sql Alias $ServerAlias"

	$x86 = "HKLM:\Software\Microsoft\MSSQLServer\Client\ConnectTo"
	$x64 = "HKLM:\Software\Wow6432Node\Microsoft\MSSQLServer\Client\ConnectTo"
	
	if ($Architecture -eq "32Bit" -or $Architecture -eq "Both")
	{
		if ((Test-Path -path $x86) -ne $True)
		{
			#Write-Verbose "No 32-bit SQL Aliases exist at all (Registry key not present)"
			
			$result32bit = @{
				ServerAlias = $ServerAlias
				Ensure = "Absent"
				ServerName = $null
				Port = 1433
			}
		} else {
		
			$ServerAliasToTest = (Get-ItemProperty -Name $ServerAlias -Path $x86 -ErrorAction SilentlyContinue)
		
			if ($ServerAliasToTest -eq $null)
			{	
				#Write-Verbose "Alias not found"

				$result32bit = @{
					ServerAlias = $ServerAlias
					Ensure = "Absent"
					ServerName = $null
					Port = 1433
				}
			} else {
				#Write-Verbose "Alias found, extracting details"

				$aliasValue = $ServerAliasToTest | select -ExpandProperty $ServerAlias
				$aliasValue = $aliasValue.Replace("DBMSSOCN,", "") #TODO: Assumes TCP ONLY
				
				if ($aliasValue.IndexOf(",") -gt -1)
				{
					$serverNameFound = $aliasValue.SubString(0, $aliasValue.IndexOf(","))
					$portFound = $aliasValue.SubString($aliasValue.IndexOf(",") + 1)
				} else {
					$serverNameFound = $aliasValue
					$portFound = 1433
				}
				
				$result32bit = @{
					ServerAlias = $ServerAlias
					Ensure = "Present"
					ServerName = $serverNameFound
					Port = $portFound
				}
			}
		}
	}
	if ($Architecture -eq "64Bit" -or $Architecture -eq "Both")
	{
		if ((Test-Path -path $x64) -ne $True)
		{
			#Write-Verbose "No 64-bit SQL Aliases exist at all (Registry key not present)"
			
			$result64bit = @{
				ServerAlias = $ServerAlias
				Ensure = "Absent"
				ServerName = $null
				Port = 1433
			}
		} else {
		
			$ServerAliasToTest = (Get-ItemProperty -Name $ServerAlias -Path $x64 -ErrorAction SilentlyContinue)
		
			if ($ServerAliasToTest -eq $null)
			{	
				#Write-Verbose "Alias not found"

				$result64bit = @{
					ServerAlias = $ServerAlias
					Ensure = "Absent"
					ServerName = $null
					Port = 1433
				}
			} else {
				#Write-Verbose "Alias found, extracing details"

				$aliasValue = $ServerAliasToTest | select -ExpandProperty $ServerAlias
				$aliasValue = $aliasValue.Replace("DBMSSOCN,", "") #TODO: Assumes TCP ONLY
				
				if ($aliasValue.IndexOf(",") -gt -1)
				{
					$serverNameFound = $aliasValue.SubString(0, $aliasValue.IndexOf(","))
					$portFound = $aliasValue.SubString($aliasValue.IndexOf(",") + 1)
				} else {
					$serverNameFound = $aliasValue
					$portFound = 1433
				}
				
				$result64bit = @{
					ServerAlias = $ServerAlias
					Ensure = "Present"
					ServerName = $serverNameFound
					Port = $portFound
				}
			}
		}
	}
		
    $result = @{
		x86Result = $result32bit
		x64Result = $result64bit
	}

    $result
}

function Set-TargetResource
{
    [CmdletBinding()]
    param
    (
        [parameter(Mandatory = $true)]
        [System.String]
        $ServerAlias,

        [ValidateSet("Present","Absent")]
        [System.String]
        $Ensure = "Present",
		
        [parameter(Mandatory = $true)]
        [System.String]
        $ServerName,

        [System.Int32]
        $Port,
		
        [ValidateSet("32Bit","64Bit","Both")]
        [System.String]
        $Architecture = "32Bit"
    )

    $currentSettings = Get-TargetResource -ServerAlias $ServerAlias -Ensure $Ensure -ServerName $ServerName -Port $Port -Architecture $Architecture

	$x86 = "HKLM:\Software\Microsoft\MSSQLServer\Client\ConnectTo"
	$x64 = "HKLM:\Software\Wow6432Node\Microsoft\MSSQLServer\Client\ConnectTo"
	$TcpAlias = "DBMSSOCN," + $ServerName
    if ($Port -gt 0) { $TcpAlias += "," + $Port }

    if ($Architecture -eq "32Bit" -or $Architecture -eq "Both")
	{
        #Write-Verbose "Verifying 32-bit value"

        if ($currentSettings.x86Result.Ensure -eq "Absent" -and $Ensure -eq "Absent")
        {
            Write-Verbose "Alias does not exist, as Desired - skipping"
        }
        elseif ($currentSettings.x86Result.Ensure -eq "Absent" -and $Ensure -eq "Present")
        {
            Write-Verbose "Adding alias $TcpAlias"
            
            if ((Test-Path -Path $x86) -ne $true)
            {
                Write-Verbose "$x86 does not exist, creating"
                New-Item $x86 | Out-Null
            }

            New-ItemProperty -Path $x86 -Name $ServerAlias -PropertyType String -Value $TcpAlias | Out-Null
        }
        elseif ($currentSettings.x86Result.Ensure -eq "Present" -and $Ensure -eq "Present")
        {
            Write-Verbose "Alias exists, overwriting to ensure all values are as Desired"

            Set-ItemProperty -Path $x86 -Name $ServerAlias -Value $TcpAlias -Force
        }
        elseif ($currentSettings.x86Result.Ensure -eq "Present" -and $Ensure -eq "Absent")
        {
            Write-Verbose "Alias found, removing"
            
            Remove-ItemProperty -Path $x86 -Name $ServerAlias -Force
        }
    }
    if ($Architecture -eq "64Bit" -or $Architecture -eq "Both")
	{
        #Write-Verbose "Verifying 64-bit value"

        if ($currentSettings.x64Result.Ensure -eq "Absent" -and $Ensure -eq "Absent")
        {
            Write-Verbose "Alias does not exist, as desired - skipping"
        }
        elseif ($currentSettings.x64Result.Ensure -eq "Absent" -and $Ensure -eq "Present")
        {
            Write-Verbose "Adding alias $TcpAlias"
            
            if ((Test-Path -Path $x64) -ne $true)
            {
                Write-Verbose "$x64 does not exist, creating"
                New-Item $x64 | Out-Null
            }

            New-ItemProperty -Path $x64 -Name $ServerAlias -PropertyType String -Value $TcpAlias | Out-Null
        }
        elseif ($currentSettings.x64Result.Ensure -eq "Present" -and $Ensure -eq "Present")
        {
            Write-Verbose "Alias exists, overwriting to ensure all values are as Desired"

            Set-ItemProperty -Path $x64 -Name $ServerAlias -Value $TcpAlias -Force
        }
        elseif ($currentSettings.x64Result.Ensure -eq "Present" -and $Ensure -eq "Absent")
        {
            Write-Verbose "Alias found, removing"
            
            Remove-ItemProperty -Path $x64 -Name $ServerAlias -Force
        }
    }
}

function Test-TargetResource
{
    [CmdletBinding()]
    [OutputType([System.Boolean])]
    param
    (
        [parameter(Mandatory = $true)]
        [System.String]
        $ServerAlias,

        [ValidateSet("Present","Absent")]
        [System.String]
        $Ensure = "Present",
		
        [parameter(Mandatory = $true)]
        [System.String]
        $ServerName,

        [System.Int32]
        $Port,
		
        [ValidateSet("32Bit","64Bit","Both")]
        [System.String]
        $Architecture = "32Bit"
    )

    $currentSettings = Get-TargetResource -ServerAlias $ServerAlias -Ensure $Ensure -ServerName $ServerName -Port $Port -Architecture $Architecture

    #$currentSettings.x86Result | Format-List
    #$currentSettings.x64Result | Format-List

    Write-Verbose "Testing for Alias $ServerAlias in 32/64-bit - $Architecture"

    if ($Port -eq 0)
		{ $TestPort = 1433 }
	else
		{ $TestPort = $Port }

    if ($Architecture -eq "32Bit" -or $Architecture -eq "Both")
	{
        #Write-Verbose "Verifying 64-bit value"

        if ($currentSettings.x86Result.Ensure -eq "Absent" -and $Ensure -eq "Absent")
        {
			Write-Verbose "32-bit value is missing, as Desired"
            $is32BitOk = $true
        }
        elseif ($currentSettings.x86Result.Ensure -eq "Absent" -and $Ensure -eq "Present")
        {
			Write-Verbose "32-bit value is missing"
            $is32BitOk = $false
        }
        elseif ($currentSettings.x86Result.Ensure -eq "Present" -and $Ensure -eq "Present")
        {
            $is32BitOk = $currentSettings.x86Result.ServerName -eq $ServerName -and $currentSettings.x86Result.Port -eq $TestPort
			Write-Verbose "32-bit value exists, equality is $is32BitOk"
        }
        elseif ($currentSettings.x86Result.Ensure -eq "Present" -and $Ensure -eq "Absent")
        {
			Write-Verbose "32-bit value exists and needs to be removed"
            $is32BitOk = $false
        }
    } else {
        $is32BitOk = $true
    }	
    if ($Architecture -eq "64Bit" -or $Architecture -eq "Both")
	{
        #Write-Verbose "Verifying 64-bit value"

        if ($currentSettings.x64Result.Ensure -eq "Absent" -and $Ensure -eq "Absent")
        {
			rite-Verbose "64-bit value is missing, as Desired"
            $is64BitOk = $true
        }
        elseif ($currentSettings.x64Result.Ensure -eq "Absent" -and $Ensure -eq "Present")
        {
			Write-Verbose "64-bit value is missing"
            $is64BitOk = $false
        }
        elseif ($currentSettings.x64Result.Ensure -eq "Present" -and $Ensure -eq "Present")
        {
            $is64BitOk = $currentSettings.x64Result.ServerName -eq $ServerName -and $currentSettings.x64Result.Port -eq $TestPort
			Write-Verbose "64-bit value exists, equality is $is64BitOk"
        }
        elseif ($currentSettings.x64Result.Ensure -eq "Present" -and $Ensure -eq "Absent")
        {
			Write-Verbose "64-bit value exists and needs to be removed"
            $is64BitOk = $false
        }
    } else {
        $is64BitOk = $true
    }

    return $is32BitOk -eq $true -and $is64BitOk -eq $true
}

Export-ModuleMember -Function *-TargetResource
