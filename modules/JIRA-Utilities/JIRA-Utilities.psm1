<#
.SYNOPSIS
JIRA Utilities Module

.DESCRIPTION
This module provides functions for interacting with JIRA using PowerShell.
It includes functions for retrieving JIRA environment variables, getting issue details,
and adding text to issue descriptions.

.NOTES
Ensure that the following environment variables are set before using these functions:
- JIRA_URL: The URL of your JIRA instance
- JIRA_EMAIL: Your JIRA account email
- JIRA_API_TOKEN: Your JIRA API token
#>

<#
.SYNOPSIS
Retrieves JIRA environment variables.

.DESCRIPTION
This function fetches the JIRA URL, email, and API token from environment variables.
It checks if all required variables are set and returns them as a hashtable.

.OUTPUTS
System.Collections.Hashtable or $null if any required variable is missing.
#>
function Get-JiraEnvironmentVariables {
    $variables = @{
        "JiraUrl"  = [Environment]::GetEnvironmentVariable("JIRA_URL", "User")
        "Email"    = [Environment]::GetEnvironmentVariable("JIRA_EMAIL", "User")
        "ApiToken" = [Environment]::GetEnvironmentVariable("JIRA_API_TOKEN", "User")
    }

    # Check if all variables are set
    $missingVariables = $variables.GetEnumerator() | Where-Object { [string]::IsNullOrEmpty($_.Value) } | Select-Object -ExpandProperty Key
    if ($missingVariables) {
        Write-Host "Error: The following JIRA environment variables are not set: $($missingVariables -join ', ')" -ForegroundColor Red
        return $null
    }

    return $variables
}

<#
.SYNOPSIS
Creates the authentication headers for JIRA API requests.

.DESCRIPTION
This function generates the necessary authentication headers for JIRA API requests
using the email and API token stored in environment variables.

.OUTPUTS
System.Collections.Hashtable containing the Authorization and Content-Type headers.
#>
function Get-JiraApiHeaders {
    $jiraEnv = Get-JiraEnvironmentVariables
    if (-not $jiraEnv) {
        throw "JIRA environment variables are not properly set."
    }

    $base64AuthInfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(("{0}:{1}" -f $jiraEnv.Email, $jiraEnv.ApiToken)))
    return @{
        Authorization  = "Basic $base64AuthInfo"
        "Content-Type" = "application/json"
    }
}

<#
.SYNOPSIS
Constructs the JIRA API URL for a given endpoint.

.DESCRIPTION
This function builds the full JIRA API URL by combining the base JIRA URL
from environment variables with the provided endpoint.

.PARAMETER Endpoint
The API endpoint to append to the base JIRA URL.

.OUTPUTS
System.String representing the full JIRA API URL.

.EXAMPLE
Get-JiraApiUrl -Endpoint "issue/PROJ-123"
#>
function Get-JiraApiUrl {
    param (
        [Parameter(Mandatory = $true)]
        [string]$Endpoint
    )

    $jiraEnv = Get-JiraEnvironmentVariables
    if (-not $jiraEnv) {
        throw "JIRA environment variables are not properly set."
    }

    return "$($jiraEnv.JiraUrl)/rest/api/2/$Endpoint"
}

<#
.SYNOPSIS
Retrieves the summary of a JIRA issue.

.DESCRIPTION
This function fetches only the summary of a specified JIRA issue.

.PARAMETER IssueKey
The key of the JIRA issue to retrieve the summary for (e.g., "PROJ-123").

.EXAMPLE
Get-JiraSummary -IssueKey "PROJ-123"

.OUTPUTS
System.String containing the summary of the JIRA issue.
#>
function Get-JiraSummary {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$IssueKey
    )

    try {
        $headers = Get-JiraApiHeaders        
        $apiUrl = Get-JiraApiUrl -Endpoint "issue/$IssueKey"

        # Make the API request
        $response = Invoke-RestMethod -Uri $apiUrl -Headers $headers -Method Get

        # Return the summary
        return $response.fields.summary
    }
    catch {
        Write-Error "Error fetching summary for issue ${IssueKey}: $_"
        return $null
    }
}

<#
.SYNOPSIS
Retrieves and displays details of a JIRA issue.

.DESCRIPTION
This function fetches the details of a specified JIRA issue and displays them,
including key, summary, status, type, priority, assignee, reporter, creation date,
update date, and description.

.PARAMETER IssueKey
The key of the JIRA issue to retrieve (e.g., "PROJ-123").

.EXAMPLE
Get-JiraIssueDetails -IssueKey "PROJ-123"
#>
function Get-JiraIssueDetails {
    param (
        [Parameter(Mandatory = $true)]
        [string]$IssueKey
    )

    # Get environment variables
    $jiraEnv = Get-JiraEnvironmentVariables
    if (-not $jiraEnv) {
        return
    }

    try {
        $headers = Get-JiraApiHeaders
        $apiUrl = Get-JiraApiUrl -Endpoint "issue/$IssueKey"

        # Make the API request
        $response = Invoke-RestMethod -Uri $apiUrl -Headers $headers -Method Get

        # Display issue details
        Write-Host "Issue Key: $($response.key)" -ForegroundColor Cyan
        Write-Host "Summary: $($response.fields.summary)" -ForegroundColor Cyan
        Write-Host "Status: $($response.fields.status.name)" -ForegroundColor Cyan
        Write-Host "Issue Type: $($response.fields.issuetype.name)" -ForegroundColor Cyan
        Write-Host "Priority: $($response.fields.priority.name)" -ForegroundColor Cyan
        Write-Host "Assignee: $($response.fields.assignee.displayName)" -ForegroundColor Cyan
        Write-Host "Reporter: $($response.fields.reporter.displayName)" -ForegroundColor Cyan
        Write-Host "Created: $($response.fields.created)" -ForegroundColor Cyan
        Write-Host "Updated: $($response.fields.updated)" -ForegroundColor Cyan
        
        Write-Host "`nDescription:" -ForegroundColor Yellow
        Write-Host $response.fields.description

        # You can add more fields as needed
    }
    catch {
        Write-Host "Error fetching issue details: $_" -ForegroundColor Red
    }
}

function Get-JiraIssueObject {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$IssueKey
    )

    try {
        $headers = Get-JiraApiHeaders
        $apiUrl = Get-JiraApiUrl -Endpoint "issue/$IssueKey"

        # Make the API request
        $response = Invoke-RestMethod -Uri $apiUrl -Headers $headers -Method Get
        
        # Filter out customfields
        $filteredFields = $response.fields | Get-Member -MemberType NoteProperty |
        Where-Object { $_.Name -notlike 'customfield*' } |
        Select-Object -ExpandProperty Name

        $result = @{}
        foreach ($field in $filteredFields) {
            $result[$field] = $response.fields.$field
        }

        return $result
    }
    catch {
        Write-Error "Error fetching issue details for ${IssueKey}: $_"
        return $null
    }
}

<#
.SYNOPSIS
Adds text to the description of a JIRA issue.

.DESCRIPTION
This function appends specified text to the description of a JIRA issue.
If the description is empty, it sets the description to the provided text.

.PARAMETER IssueKey
The key of the JIRA issue to update (e.g., "PROJ-123").

.PARAMETER TextToAdd
The text to append to the issue description.

.EXAMPLE
Add-TextToJiraDescription -IssueKey "PROJ-123" -TextToAdd "Additional information for this issue."
#>
function Add-TextToJiraDescription {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$IssueKey,

        [Parameter(Mandatory = $true)]
        [string]$TextToAdd
    )

    # Get environment variables
    $jiraEnv = Get-JiraEnvironmentVariables
    if (-not $jiraEnv) {
        return
    }

    try {
        $headers = Get-JiraApiHeaders
        $apiUrl = Get-JiraApiUrl -Endpoint "issue/$IssueKey"

        # First, get the current description
        $getResponse = Invoke-RestMethod -Uri $apiUrl -Headers $headers -Method Get
        $currentDescription = $getResponse.fields.description

        # Append the new text to the description
        $newDescription = if ([string]::IsNullOrEmpty($currentDescription)) {
            $TextToAdd
        }
        else {
            "${currentDescription}`n`n${TextToAdd}"
        }

        # Prepare the update payload
        $updateBody = @{
            fields = @{
                description = $newDescription
            }
        } | ConvertTo-Json

        # Make the PUT request to update the description
        $updateResponse = Invoke-RestMethod -Uri $apiUrl -Headers $headers -Method Put -Body $updateBody

        Write-Host "Description updated successfully for issue $IssueKey" -ForegroundColor Green
        Write-Host "New text added: $TextToAdd" -ForegroundColor Cyan
        
        if ($null -eq $updateResponse -or $updateResponse -eq '') {
            Write-Host "Update successful (API returned no content)" -ForegroundColor Blue
        }
        else {
            Write-Host "Update Response: $($updateResponse | ConvertTo-Json -Depth 5)" -ForegroundColor Blue
        }
    }
    catch {
        Write-Error "Error updating description for issue ${IssueKey}: $_"
        if ($_.Exception.Response) {
            $responseBody = $_.Exception.Response.Content.ReadAsStringAsync().Result
            Write-Error "Response content: $responseBody"
        }
    }
}

# Export the functions to make them available when the module is imported
Export-ModuleMember -Function @(
    'Get-JiraEnvironmentVariables',
    'Get-JiraIssueDetails',
    'Add-TextToJiraDescription',
    'Get-JiraSummary',
    'Get-JiraIssueObject'
)