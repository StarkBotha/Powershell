@{
    RootModule        = 'JIRA-Utilities.psm1'
    ModuleVersion     = '1.0.0'
    GUID              = '47eecd91-cb12-4645-a8c4-d6e50f545aa6'
    Author            = 'Stark Botha'
    CompanyName       = 'Stark Botha'
    Copyright         = '(c) 2023 Stark Botha. All rights reserved.'
    Description       = 'A PowerShell module containing utility functions for interacting with JIRA.'
    PowerShellVersion = '5.1'
    FunctionsToExport = @(
        'Get-JiraEnvironmentVariables',
        'Get-JiraIssueDetails',
        'Add-TextToJiraDescription',
        'Get-JiraSummary',
        'Get-JiraIssueObject'
    )
    CmdletsToExport   = @()
    VariablesToExport = @()
    AliasesToExport   = @()
    PrivateData       = @{
        PSData = @{
            Tags       = @('Utility', 'JIRA', 'API', 'IssueTracking')
            LicenseUri = 'https://example.com/license'
            ProjectUri = 'https://github.com/yourusername/General-Utilities'
            # ReleaseNotes = 'Initial release of JIRA Utilities module.'
        }
    }
    # HelpInfoURI = 'https://example.com/help'
}