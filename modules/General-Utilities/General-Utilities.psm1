<#
.SYNOPSIS
Safely removes an item at the specified path.

.DESCRIPTION
The Remove-ItemSafely function attempts to remove an item (file or directory) at the specified path.
If the item exists, it will be forcefully removed. If it doesn't exist, a message will be displayed
indicating that the path is already clear.

.PARAMETER Path
The path to the item (file or directory) that should be removed.

.EXAMPLE
Remove-ItemSafely -Path "C:\temp\oldfiles"
This will attempt to remove the "oldfiles" directory in C:\temp.

.EXAMPLE
Remove-ItemSafely -Path "C:\temp\unneeded.txt"
This will attempt to remove the file "unneeded.txt" from C:\temp.

.NOTES
This function uses the -Force and -Recurse parameters when removing items, so it will delete
read-only files and non-empty directories without prompting for confirmation. Use with caution.
#>
function Remove-ItemSafely {
    param (
        [Parameter(Mandatory = $true, Position = 0, HelpMessage = "Path to the item to be removed")]
        [string]$Path
    )
    if (Test-Path $Path) {
        Remove-Item $Path -Force -Recurse
        Write-Host "Cleared: $Path"
    }
    else {
        Write-Host "Path not found (already clear): $Path"
    }
}

<#
.SYNOPSIS
Generates a new GUID (Globally Unique Identifier) in various formats.

.DESCRIPTION
This function creates a new GUID and returns it in the specified format.
The available formats are Default, NoHyphens, Braces, and Parentheses.

.PARAMETER Format
Specifies the output format of the GUID. 
Valid values are: "Default", "NoHyphens", "Braces", "Parentheses".
If not specified, the default format is used.

.EXAMPLE
New-Guid
Returns a GUID in the default format (e.g., 123e4567-e89b-12d3-a456-426614174000)

.EXAMPLE
New-Guid -Format NoHyphens
Returns a GUID without hyphens (e.g., 123e4567e89b12d3a456426614174000)

.EXAMPLE
New-Guid -Format Braces
Returns a GUID enclosed in braces (e.g., {123e4567-e89b-12d3-a456-426614174000})

.EXAMPLE
New-Guid -Format Parentheses
Returns a GUID enclosed in parentheses (e.g., (123e4567-e89b-12d3-a456-426614174000))

.OUTPUTS
System.String

#>
function New-Guid {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $false)]
        [ValidateSet("Default", "NoHyphens", "Braces", "Parentheses")]
        [string]$Format = "Default"
    )

    # Generate a new GUID
    $guid = [System.Guid]::NewGuid()

    # Return the GUID in the specified format
    switch ($Format) {
        "Default" {
            return $guid.ToString()  # Standard GUID format with hyphens
        }
        "NoHyphens" {
            return $guid.ToString("N")  # GUID without hyphens
        }
        "Braces" {
            return $guid.ToString("B")  # GUID enclosed in braces
        }
        "Parentheses" {
            return $guid.ToString("P")  # GUID enclosed in parentheses
        }
    }
}

<#
.SYNOPSIS
Generates the content for a PowerShell module manifest.

.DESCRIPTION
This function returns a string containing the content for a PowerShell module manifest (*.psd1 file).
The manifest includes metadata about the module such as its name, version, author, and exported functions.

.EXAMPLE
Get-ModuleText
Returns the complete module manifest content as a string.

.EXAMPLE
$manifestContent = Get-ModuleText
$manifestContent | Out-File -FilePath .\General-Utilities.psd1
Generates the module manifest content and saves it to a file named General-Utilities.psd1 in the current directory.

.OUTPUTS
System.String
#>
function Get-ModuleText {
    # Define the module manifest content as a here-string
    $manifestContent = @"
@{
    RootModule        = 'General-Utilities.psm1'
    ModuleVersion     = '1.0.0'
    GUID              = '6c1b2607-8c9e-4ba1-b86e-69a20b18d612'
    Author            = 'Stark Botha'
    CompanyName       = 'Stark Botha'
    Copyright         = '(c) 2023 Stark Botha. All rights reserved.'
    Description       = 'A module containing general utility functions.'
    PowerShellVersion = '5.1'
    FunctionsToExport = @('Remove-ItemSafely')
    CmdletsToExport   = @()
    VariablesToExport = '*'
    AliasesToExport   = @()
    PrivateData       = @{
        PSData = @{
            Tags       = @('Utility', 'FileSystem')
            LicenseUri = 'https://example.com/license'
            ProjectUri = 'https://github.com/yourusername/General-Utilities'
            # ReleaseNotes = ''
        }
    }
}
"@

    # Output the manifest content
    Write-Output $manifestContent
}

<#
.SYNOPSIS
Lists custom PowerShell functions and aliases from modules in a specified directory.

.DESCRIPTION
This function scans a specified directory for PowerShell module manifests (*.psd1 files),
imports each module, and lists its exported functions and aliases along with their descriptions.
It also provides information on how to get more detailed help for specific functions.

.PARAMETER CustomModulePath
The path to the directory containing custom PowerShell modules.
Default is "C:\dev\powershell\modules".

.EXAMPLE
Get-CustomFunctions
Lists functions and aliases from modules in the default directory.

.EXAMPLE
Get-CustomFunctions -CustomModulePath "C:\MyModules"
Lists functions and aliases from modules in the specified directory.

.OUTPUTS
Writes module, function, and alias information to the host.

.NOTES
The function temporarily imports each module to gather information and then removes it to avoid conflicts.
#>
function Get-CustomFunctions {
    param (
        [string]$CustomModulePath = "C:\dev\powershell\modules"
    )

    # Ensure the custom module path exists
    if (-not (Test-Path $CustomModulePath)) {
        Write-Error "Custom module path does not exist: $CustomModulePath"
        return
    }

    # Get all module manifests in the custom path
    $moduleManifests = Get-ChildItem -Path $CustomModulePath -Filter "*.psd1" -Recurse

    foreach ($manifest in $moduleManifests) {
        try {
            # Import the module
            $module = Import-Module -Name $manifest.FullName -PassThru -ErrorAction Stop
            Write-Host "Module: $($module.Name)" -ForegroundColor Cyan

            # Get exported functions
            $exportedFunctions = Get-Command -Module $module.Name -CommandType Function

            if ($exportedFunctions) {
                Write-Host "  Functions:" -ForegroundColor Yellow
                foreach ($function in $exportedFunctions) {
                    $help = Get-Help $function.Name
                    Write-Host "    $($function.Name)" -ForegroundColor Green
                    if ($help.Synopsis) {
                        Write-Host "      $($help.Synopsis.Trim())" -ForegroundColor Gray
                    }
                    Write-Host "      For more details, run: Get-Help $($function.Name) -Detailed" -ForegroundColor DarkGray
                    Write-Host ""
                }
            }

            # Get exported aliases
            $exportedAliases = Get-Command -Module $module.Name -CommandType Alias

            if ($exportedAliases) {
                Write-Host "  Aliases:" -ForegroundColor Yellow
                foreach ($alias in $exportedAliases) {
                    Write-Host "    $($alias.Name) -> $($alias.ResolvedCommand)" -ForegroundColor Magenta
                }
            }
            
            Write-Host ""  # Add an extra newline for separation between modules

            # Remove the module to avoid conflicts
            Remove-Module -Name $module.Name -ErrorAction SilentlyContinue
        }
        catch {
            Write-Warning "Failed to import module from $($manifest.FullName): $_"
        }
    }

    Write-Host "To get more information about a specific function, use Get-Help with the -Detailed or -Full parameter." -ForegroundColor Cyan
    Write-Host "Example: Get-Help FunctionName -Detailed" -ForegroundColor Cyan
}


Export-ModuleMember -Function @(
    'Remove-ItemSafely',
    'New-Guid',
    'Get-ModuleText',
    'Get-CustomFunctions'
)