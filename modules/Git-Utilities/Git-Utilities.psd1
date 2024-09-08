@{
    RootModule        = 'Git-Utilities.psm1'
    ModuleVersion     = '1.0.0'
    GUID              = '12d4d14d-f9a6-442f-8c88-459fa5e81bb5'
    Author            = 'Stark Botha'
    CompanyName       = 'Stark Botha'
    Copyright         = '(c) 2023 Stark Botha. All rights reserved.'
    Description       = 'A module containing Git utility functions.'
    PowerShellVersion = '5.1'
    FunctionsToExport = @(
        'Test-IsGitRepository', 
        'Get-GitCurrentBranch', 
        'New-MergeBranch', 
        'Get-GitPrefix', 
        'Get-TopicBranches', 
        'Get-Branches',
        'Remove-Branches',
        'Get-UntrackedBranches',
        'Get-UnmergedBranches',
        'Show-Diff'
    )
    CmdletsToExport   = @()
    VariablesToExport = '*'
    AliasesToExport   = @()
    PrivateData       = @{
        PSData = @{
            Tags         = @('Utility', 'Git', 'VersionControl', 'Repository')
            LicenseUri   = 'https://example.com/license'
            ProjectUri   = 'https://github.com/yourusername/General-Utilities'
            # IconUri    = ''
            ReleaseNotes = 'Initial release of Git-Utilities module.'
        }
    }
    # HelpInfoURI = 'https://example.com/help'
    # CompatiblePSEditions = @('Desktop', 'Core')
}