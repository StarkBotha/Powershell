@{
    RootModule        = 'MyShortcuts.psm1'
    ModuleVersion     = '1.0.0'
    GUID              = '9f2d182d-7972-4f07-88c0-8e21e9f2005c'
    Author            = 'Stark Botha'
    CompanyName       = 'Stark Botha'
    Copyright         = '(c) 2023 Stark Botha. All rights reserved.'
    Description       = 'Provides shortcuts for navigating to common directories.'
    PowerShellVersion = '5.1'
    FunctionsToExport = @('Use-Dev', 'Use-Avenu', 'Use-BpWeb', 'Use-BpApi', 'Use-OrgApi', 'Use-TasksApi', 'Use-Nvim')
    CmdletsToExport   = @()
    VariablesToExport = '*'
    AliasesToExport   = @('godev', 'goavenu', 'gobpweb', 'gobpapi', 'goorg', 'gotasks', 'govim')
    PrivateData       = @{
        PSData = @{
            Tags       = @('Utility', 'FileSystem')
            LicenseUri = 'https://example.com/license'
            ProjectUri = 'https://github.com/yourusername/General-Utilities'
            # ReleaseNotes = ''
        }
    }
}