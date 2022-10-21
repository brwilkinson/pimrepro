# alternatie to New-PimRoleActivation

<#
$ScheduleRequestId = ''
$URI =  "https://management.azure.com/subscriptions/$SubscriptionId/providers/Microsoft.Authorization/roleAssignmentScheduleRequests/$ScheduleRequestId?api-version=2020-10-01"

$Body = @"
{
  "properties": {
    "scheduleInfo": {
      "expiration": {
        "type": "AfterDuration",
        "duration": "PT15M"
      },
      "startDateTime": "$(Get-Date -Format o)"
    },
    "roleDefinitionId": "$($NewResourceGroup.ResourceId)/providers/Microsoft.Authorization/roleDefinitions/8e3af657-a8ff-443c-a75c-2fe8c4bcb635",
    "principalId": "$PrincipalId",
    "requestType": "SelfActivate",
    "justification": "testing pim"
  }
}
"@

# $token = Get-AzAccessToken -ResourceTypeName MSGraph | foreach token
$token = Get-AzAccessToken | foreach token

    $contentType = 'application/json'
    $headers = @{
        Authorization = "Bearer $token"
        Accept        = $contentType
    }

iwr -uri $uri -headers $headers -body $Body -Method PUT -ContentType $ContentType -ov r
#>