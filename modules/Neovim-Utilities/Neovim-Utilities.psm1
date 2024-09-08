Import-Module General-Utilities

function Clear-NeovimCache {
    # Define the base path for Neovim data
    $nvimDataPath = "$env:LOCALAPPDATA\nvim-data"

    # 1. Clear the shada file
    Remove-ItemSafely "$nvimDataPath\shada\main.shada"

    # 2. Clear swap files
    Remove-ItemSafely "$nvimDataPath\swap\*"

    # 3. Clear undo files
    Remove-ItemSafely "$nvimDataPath\undo\*"

    # 4. Clear view files
    Remove-ItemSafely "$nvimDataPath\view\*"

    Write-Host "Neovim cache clearing complete."
}

Export-ModuleMember -Function Remove-ItemSafely