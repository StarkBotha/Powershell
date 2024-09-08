function Go-Dev { Set-Location C:\dev }
function Go-Avenu { Set-Location c:\dev\avenu }
function Go-BpWeb { Set-Location C:\dev\avenu\BrokerPortalWeb }
function Go-BpApi { Set-Location C:\dev\avenu\Avenu20_BP }
function Go-OrgApi { Set-Location C:\dev\avenu\Avenu.Organizations }
function Go-TasksApi { Set-Location C:\dev\avenu\Avenu.Tasks }
function Go-Nvim { Set-Location C:\Users\stark\AppData\Local\nvim }

# Create aliases
New-Alias -Name godev -Value Go-Dev
New-Alias -Name goavenu -Value Go-Avenu
New-Alias -Name gobpweb -Value Go-BpWeb
New-Alias -Name gobpapi -Value Go-BpApi
New-Alias -Name goorg -Value Go-OrgApi
New-Alias -Name gotasks -Value Go-TasksApi
New-Alias -Name govim -Value Go-Nvim

# Export only the aliases
Export-ModuleMember -Alias godev, goavenu, gobpweb, gobpapi, goorg, gotasks, govim