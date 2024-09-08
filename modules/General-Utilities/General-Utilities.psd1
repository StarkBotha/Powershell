@{
    RootModule        = 'General-Utilities.psm1'
    ModuleVersion     = '1.0.0'
    GUID              = '6c1b2607-8c9e-4ba1-b86e-69a20b18d612'
    Author            = 'Stark Botha'
    CompanyName       = 'Stark Botha'
    Copyright         = '(c) 2023 Stark Botha. All rights reserved.'
    Description       = 'A module containing general utility functions.'
    PowerShellVersion = '5.1'
    FunctionsToExport = @(
        'Remove-ItemSafely',
        'New-Guid',
        'Get-ModuleText',
        'Get-CustomFunctions'
    )
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