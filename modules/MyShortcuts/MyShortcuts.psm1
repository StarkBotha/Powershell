<#
.SYNOPSIS
Changes the current location to the dev directory.
#>
function Use-Dev { Set-Location C:\dev }

<#
.SYNOPSIS
Changes the current location to the Avenu directory.
#>
function Use-Avenu { Set-Location c:\dev\avenu }

<#
.SYNOPSIS
Changes the current location to the BrokerPortalWeb directory.
#>
function Use-BpWeb { Set-Location C:\dev\avenu\BrokerPortalWeb }

<#
.SYNOPSIS
Changes the current location to the Avenu20_BP directory.
#>
function Use-BpApi { Set-Location C:\dev\avenu\Avenu20_BP }

<#
.SYNOPSIS
Changes the current location to the Avenu.Organizations directory.
#>
function Use-OrgApi { Set-Location C:\dev\avenu\Avenu.Organizations }

<#
.SYNOPSIS
Changes the current location to the Avenu.Tasks directory.
#>
function Use-TasksApi { Set-Location C:\dev\avenu\Avenu.Tasks }

<#
.SYNOPSIS
Changes the current location to the Neovim configuration directory.
#>
function Use-Nvim { Set-Location C:\Users\stark\AppData\Local\nvim }

# Create aliases
New-Alias -Name godev -Value Use-Dev
New-Alias -Name goavenu -Value Use-Avenu
New-Alias -Name gobpweb -Value Use-BpWeb
New-Alias -Name gobpapi -Value Use-BpApi
New-Alias -Name goorg -Value Use-OrgApi
New-Alias -Name gotasks -Value Use-TasksApi
New-Alias -Name govim -Value Use-Nvim

# Export functions and aliases
Export-ModuleMember -Function Use-Dev, Use-Avenu, Use-BpWeb, Use-BpApi, Use-OrgApi, Use-TasksApi, Use-Nvim
Export-ModuleMember -Alias godev, goavenu, gobpweb, gobpapi, goorg, gotasks, govim