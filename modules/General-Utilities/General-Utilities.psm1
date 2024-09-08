function Remove-ItemSafely {
    param (
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

Export-ModuleMember -Function Remove-ItemSafely