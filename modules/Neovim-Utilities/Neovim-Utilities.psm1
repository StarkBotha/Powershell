Import-Module General-Utilities

<#
.SYNOPSIS
    Clears Neovim cache files.
.DESCRIPTION
    This function clears various Neovim cache files including the shada file, swap files, undo files, and view files.
.EXAMPLE
    Clear-NeovimCache
    Clears all Neovim cache files.
.NOTES
    Requires the General-Utilities module for the Remove-ItemSafely function.
#>
function Clear-NeovimCache {
    [CmdletBinding()]
    param()
    
    begin {
        Write-Verbose "Starting Neovim cache clearing process."
    }
    
    process {
        try {
            # Define the base path for Neovim data
            $nvimDataPath = "$env:LOCALAPPDATA\nvim-data"

            # Check if the Neovim data path exists
            if (-not (Test-Path $nvimDataPath)) {
                Write-Warning "Neovim data path not found: $nvimDataPath"
                return
            }

            # 1. Clear the shada file
            Remove-ItemSafely "$nvimDataPath\shada\main.shada" -Verbose:$VerbosePreference

            # 2. Clear swap files
            Remove-ItemSafely "$nvimDataPath\swap\*" -Verbose:$VerbosePreference

            # 3. Clear undo files
            Remove-ItemSafely "$nvimDataPath\undo\*" -Verbose:$VerbosePreference

            # 4. Clear view files
            Remove-ItemSafely "$nvimDataPath\view\*" -Verbose:$VerbosePreference

            Write-Host "Neovim cache clearing complete." -ForegroundColor Green
        }
        catch {
            Write-Error "An error occurred while clearing Neovim cache: $_"
        }
    }
    
    end {
        Write-Verbose "Neovim cache clearing process finished."
    }
}

Export-ModuleMember -Function Clear-NeovimCache