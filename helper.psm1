#Requires -Modules @{ ModuleName="Az.Resources"; ModuleVersion="5.6.0" }

function Update-PimConditionalAccess
{
    param (
        [string]$scope,
    
        [validateset('Log Analytics Reader', 'Owner', 'Contributor', 'User Access Administrator')]
        [string]$Role = 'Owner',

        [switch]$DisableConditionalAccess
    )

    if ($ExecutionContext.SessionState.LanguageMode -ne 'FullLanguage')
    {
        return 'Please use full language mode to execute this script'
    }

    $RuleFilter = 'AuthenticationContext_EndUser_Assignment'

    $PolicyId = Get-AzRoleManagementPolicyAssignment -Scope $Scope |
        Where-Object RoleDefinitionDisplayName -EQ $Role | ForEach-Object PolicyId

    Write-Warning "PolicyId is [$PolicyId] for Role [$Role]"
    $current = Get-AzRoleManagementPolicy -Scope $Scope | Where-Object Id -EQ $PolicyId
    $AcrsRule = $Current | ForEach-Object EffectiveRule | Where-Object Id -EQ $RuleFilter

    # view the current settings
    $AcrsRule | Format-List

    <#
ClaimValue               : c1
Id                       : AuthenticationContext_EndUser_Assignment
IsEnabled                : True
RuleType                 : RoleManagementPolicyAuthenticationContextRule
Target                   : Microsoft.Azure.PowerShell.Cmdlets.Resources.Authorization.Models.Api20201001Preview.RoleManagementPolicyRuleTarget
TargetCaller             : EndUser
TargetEnforcedSetting    :
TargetInheritableSetting :
TargetLevel              : Assignment
TargetObject             :
TargetOperation          : {All}
#>

    $acrsRequired = $True
    $claimValue = 'c1' # 'SAW Required' replaces 'urn:microsoft:req1'
    if ($DisableConditionalAccess)
    { 
        $acrsRequired = $False
    }

    if ($acrsRequired -ne $AcrsRule.IsEnabled -or $AcrsRule.ClaimValue -ne $claimValue)
    {
        # Does not work from SAW directly, use Azure CloudShell (i.e. not supported in contrained language mode)
        $AcrsRule.IsEnabled = $acrsRequired
        $AcrsRule.ClaimValue = $claimValue
    
        Write-Warning -Message "Updating Role [$Role]"
        Write-Warning -Message "Updating ACRS: IsEnabled [$($AcrsRule.IsEnabled)] ClaimValue [$($AcrsRule.ClaimValue)]"

        $AcrsRule

        $new = Update-AzRoleManagementPolicy -Rule $AcrsRule -Name $current.Name -Scope $Scope
        Write-Warning -Message 'Rule updated'
        $new.EffectiveRule | Where-Object Id -EQ $RuleFilter
    }
    else
    {
        Write-Warning -Message 'Rule already set correctly'
        $AcrsRule
    }
}

function New-PimRoleActivation
{
    Param (
        [Parameter(ValueFromPipelineByPropertyName)]
        [string]$Scope,

        [Parameter(ValueFromPipelineByPropertyName)]
        [string]$PrincipalId,

        [Parameter(ValueFromPipelineByPropertyName)]
        [string]$Role,

        [validateset('PT15M', 'PT30M', 'PT1H', 'PT8H')]
        [string]$duration = 'PT15M',

        [validateset('SelfDeactivate', 'SelfActivate', 'SelfExtend', 'SelfRenew')]
        [string]$RequestType = 'SelfActivate',

        [string]$Justification = 'testing pim'
    )

    process
    {
        $RoleDefinitionId = Switch ($Role)
        {
            'Owner'
            {
                '/providers/Microsoft.Authorization/roleDefinitions/8e3af657-a8ff-443c-a75c-2fe8c4bcb635'
            }
            'Log Analytics Reader'
            {
                '/providers/Microsoft.Authorization/roleDefinitions/73c42c96-874c-492b-b04d-ab87d138a893'
            }
        }
        
        $ScheduleRequest = @{
            Name                      = New-Guid
            Scope                     = $Scope
            PrincipalId               = $PrincipalId
            RoleDefinitionId          = $RoleDefinitionId
            RequestType               = $RequestType
            ExpirationType            = 'AfterDuration'
            ScheduleInfoStartDateTime = Get-Date -Format o
            ExpirationDuration        = $duration
            Justification             = $Justification
            # LinkedRoleEligibilityScheduleId = $Name
        }
        New-AzRoleAssignmentScheduleRequest @ScheduleRequest |
            ForEach-Object {
                $_ | Select-Object PrincipalDisplayName, PrincipalId, ScopeType, ScopeDisplayName, Scope, 
                Status, Name, RoleDefinitionId, RoleDefinitionDisplayName, @{n = 'Start'; e = { $_.ScheduleInfoStartDateTime.ToLocalTime() } },
                @{ n = 'End'; e = { $_.ScheduleInfoStartDateTime.ToLocalTime().AddTicks([System.Xml.XmlConvert]::ToTimeSpan($_.ExpirationDuration).Ticks) } }
            }
    }
}

function New-PimRoleAssignment
{
    param (
        [Parameter(ValueFromPipelineByPropertyName)]
        [string]$Scope,

        [Parameter(ValueFromPipelineByPropertyName)]
        [string]$PrincipalId,

        [Parameter(ValueFromPipelineByPropertyName)]
        [string]$Role,

        [validateset('PT15M', 'PT30M', 'PT1H', 'PT8H')]
        [string]$duration = 'PT1H',

        [validateset('AdminAssign', 'AdminRemove')]
        [string]$RequestType = 'AdminAssign'
    )
    process
    {
        $RoleDefinitionId = Switch ($Role)
        {
            'Owner'
            {
                '/providers/Microsoft.Authorization/roleDefinitions/8e3af657-a8ff-443c-a75c-2fe8c4bcb635'
            }
            'Log Analytics Reader'
            {
                '/providers/Microsoft.Authorization/roleDefinitions/73c42c96-874c-492b-b04d-ab87d138a893'
            }
        }
        
        $ScheduleRequest = @{
            Name                      = New-Guid
            Scope                     = $Scope
            PrincipalId               = $PrincipalId
            RoleDefinitionId          = $RoleDefinitionId
            RequestType               = $RequestType
            ExpirationType            = 'AfterDuration'
            ScheduleInfoStartDateTime = Get-Date -Format o
            ExpirationDuration        = $duration
        }
        New-AzRoleEligibilityScheduleRequest @ScheduleRequest
    }
}