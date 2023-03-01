#Requires -Modules @{ ModuleName="Az.Resources"; ModuleVersion="5.6.0" }
Set-Location -Path $PSScriptRoot
break

# Security Group to assign to PIM
$GroupName = '2023-02-28-pimrepro-c1'
Get-AzADGroupMember -GroupDisplayName $GroupName
$PrincipalId = '32688d2e-6d9f-4f09-a241-e9113c401bbb'

# Role to enable conditional access on PIM.
$Role = 'Log Analytics Reader'

$TenantId = '{tenantGUID}'
Login-AzAccount -Tenant $TenantId
Select-AzSubscription -Tenant $TenantId

$ManagementGroupName = 'pimrepro-c1'
$MG = Get-AzManagementGroup -GroupName  $ManagementGroupName

# load helper module
Import-Module -Name .\helper.psm1 -force -Verbose

# Assign access via PIM to the Resource Group
New-PimRoleAssignment -scope $MG.Id -PrincipalId $PrincipalId -Role $Role

# Enable conditional access policy c1 on the role for Owner on the Resource Group Scope
# Enable
Update-PimConditionalAccess -scope $MG.Id -Role $Role

# Disable PIM if you want to test without it enabled, then activation will work
Update-PimConditionalAccess -scope $MG.Id -Role $Role -DisableConditionalAccess

# Try to activate with c1 enabled, will provide repro for the error.
New-PimRoleActivation -scope $MG.Id -PrincipalId $PrincipalId -Role $Role -duration PT15M

<#
FullyQualifiedErrorId : RoleAssignmentRequestAcrsValidationFailed,Microsoft.Azure.PowerShell.Cmdlets.Resources.Authorization.Cmdlets.NewAzRoleAssignmentScheduleRequest_CreateExpanded
ErrorDetails          : &claims={"access_token":{"acrs":{"essential":true, "value":"c1"}}}
#>

# Disable the PIM activation to test with different conditionalaccess setting
New-PimRoleActivation -scope $MG.Id -PrincipalId $PrincipalId -Role $Role -RequestType SelfDeactivate

