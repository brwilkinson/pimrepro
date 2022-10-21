#Requires -Modules @{ ModuleName="Az.Resources"; ModuleVersion="5.6.0" }

$SubscriptionId = '7c3b02b9-943a-408b-adb3-88200ede29ee'
$ResourceGroupName = 'TestConditionalAccess'
$PrincipalId = '8ad9676b-6d83-4d50-be85-4fa0617a0b6c'
$Role = 'Owner'


# load helper module
Import-Module -Name .\helper.psm1 -force -Verbose

<#
Login-AzAccount -SubscriptionId $SubscriptionId
#>

# create RG for conditional access policy testing
New-AzResourceGroup -Name $ResourceGroupName -Location centralus -OutVariable NewResourceGroup

<#
Get-AzResourceGroup -Name $ResourceGroupName -OutVariable NewResourceGroup

#>

# Assign access via PIM to the Resource Group, you can skip this step
New-PimRoleAssignment -scope $NewResourceGroup[0].ResourceId -PrincipalId $PrincipalId -Role $Role

# Enable conditional access policy c1 on the role for Owner on the Resource Group Scope
Update-PimConditionalAccess -scope $NewResourceGroup[0].ResourceId -Role $Role

<# 
# Disable PIM if you want to test without it enabled, then activation will work

Update-PimConditionalAccess -scope $NewResourceGroup[0].ResourceId -Role $Role -DisableConditionalAccess
#>

# Try to activate with c1 enabled, will provide repro for the error.
New-PimRoleActivation -scope $NewResourceGroup[0].ResourceId -PrincipalId $PrincipalId -Role $Role

<#
FullyQualifiedErrorId : RoleAssignmentRequestAcrsValidationFailed,Microsoft.Azure.PowerShell.Cmdlets.Resources.Authorization.Cmdlets.NewAzRoleAssignmentScheduleRequest_CreateExpanded
ErrorDetails          : &claims={"access_token":{"acrs":{"essential":true, "value":"c1"}}}
#>

