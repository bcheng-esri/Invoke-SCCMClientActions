<#
.SYNOPSIS
    Triggers all (or selected) SCCM/MECM client actions on the local or a remote machine.

.DESCRIPTION
    This script invokes Configuration Manager client agent schedules by their well-known
    Schedule IDs via the SMS_Client WMI/CIM class (root\ccm namespace). It can run
    against the local computer or one or more remote computers, and supports running
    all standard actions or a filtered subset.

    Common Schedule IDs triggered:
        {00000000-0000-0000-0000-000000000021}  Machine Policy Retrieval & Evaluation Cycle
        {00000000-0000-0000-0000-000000000022}  Machine Policy Evaluation Cycle
        {00000000-0000-0000-0000-000000000026}  User Policy Retrieval Cycle
        {00000000-0000-0000-0000-000000000027}  User Policy Evaluation Cycle
        {00000000-0000-0000-0000-000000000001}  Hardware Inventory Cycle
        {00000000-0000-0000-0000-000000000002}  Software Inventory Cycle
        {00000000-0000-0000-0000-000000000003}  Discovery Data Collection Cycle
        {00000000-0000-0000-0000-000000000010}  File Collection Cycle
        {00000000-0000-0000-0000-000000000031}  Software Metering Usage Report Cycle
        {00000000-0000-0000-0000-000000000032}  Windows Installer Source List Update Cycle
        {00000000-0000-0000-0000-000000000040}  State Message Refresh
        {00000000-0000-0000-0000-000000000042}  Application Deployment Evaluation Cycle
        {00000000-0000-0000-0000-000000000113}  Software Updates Scan Cycle
        {00000000-0000-0000-0000-000000000108}  Software Updates Deployment Evaluation Cycle

.PARAMETER ComputerName
    One or more computers to run actions against. Defaults to the local machine.

.PARAMETER Action
    Optional. One or more specific actions to run. If omitted, all actions are run.
    Use tab-completion on the parameter to see valid names.

.PARAMETER DelaySeconds
    Number of seconds to wait between triggering actions. Default is 2 seconds.

.PARAMETER Credential
    Optional credentials used when connecting to remote computers.

.EXAMPLE
    .\Invoke-SCCMClientActions.ps1
    Runs every standard action on the local computer.

.EXAMPLE
    .\Invoke-SCCMClientActions.ps1 -Action 'Machine Policy Retrieval & Evaluation Cycle','Software Updates Scan Cycle'
    Runs only the two specified actions on the local computer.

.EXAMPLE
    .\Invoke-SCCMClientActions.ps1 -ComputerName 'PC01','PC02' -Credential (Get-Credential)
    Runs every standard action on two remote computers using supplied credentials.

.NOTES
    Requirements:
        - The SCCM/MECM client must be installed on the target computer.
        - Run with administrative rights (locally elevated; remotely via an admin account).
        - Remote use requires WinRM/WMI connectivity (TCP 135 + dynamic DCOM, or PSRemoting).
#>

[CmdletBinding()]
param (
    [Parameter(ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
    [Alias('CN', 'Computer', 'PSComputerName')]
    [string[]]$ComputerName = $env:COMPUTERNAME,

    [Parameter()]
    [ValidateSet(
        'Machine Policy Retrieval & Evaluation Cycle',
        'Machine Policy Evaluation Cycle',
        'User Policy Retrieval Cycle',
        'User Policy Evaluation Cycle',
        'Hardware Inventory Cycle',
        'Software Inventory Cycle',
        'Discovery Data Collection Cycle',
        'File Collection Cycle',
        'Software Metering Usage Report Cycle',
        'Windows Installer Source List Update Cycle',
        'State Message Refresh',
        'Application Deployment Evaluation Cycle',
        'Software Updates Scan Cycle',
        'Software Updates Deployment Evaluation Cycle'
    )]
    [string[]]$Action,

    [Parameter()]
    [ValidateRange(0, 60)]
    [int]$DelaySeconds = 2,

    [Parameter()]
    [System.Management.Automation.PSCredential]
    [System.Management.Automation.Credential()]
    $Credential = [System.Management.Automation.PSCredential]::Empty
)

# Map of friendly names to SCCM ScheduleIDs
$ScheduleMap = [ordered]@{
    'Machine Policy Retrieval & Evaluation Cycle' = '{00000000-0000-0000-0000-000000000021}'
    'Machine Policy Evaluation Cycle'             = '{00000000-0000-0000-0000-000000000022}'
    'User Policy Retrieval Cycle'                 = '{00000000-0000-0000-0000-000000000026}'
    'User Policy Evaluation Cycle'                = '{00000000-0000-0000-0000-000000000027}'
    'Hardware Inventory Cycle'                    = '{00000000-0000-0000-0000-000000000001}'
    'Software Inventory Cycle'                    = '{00000000-0000-0000-0000-000000000002}'
    'Discovery Data Collection Cycle'             = '{00000000-0000-0000-0000-000000000003}'
    'File Collection Cycle'                       = '{00000000-0000-0000-0000-000000000010}'
    'Software Metering Usage Report Cycle'        = '{00000000-0000-0000-0000-000000000031}'
    'Windows Installer Source List Update Cycle'  = '{00000000-0000-0000-0000-000000000032}'
    'State Message Refresh'                       = '{00000000-0000-0000-0000-000000000040}'
    'Application Deployment Evaluation Cycle'     = '{00000000-0000-0000-0000-000000000042}'
    'Software Updates Scan Cycle'                 = '{00000000-0000-0000-0000-000000000113}'
    'Software Updates Deployment Evaluation Cycle'= '{00000000-0000-0000-0000-000000000108}'
}

# Decide which actions to run
if ($PSBoundParameters.ContainsKey('Action')) {
    $SelectedActions = $Action
} else {
    $SelectedActions = $ScheduleMap.Keys
}

Write-Verbose ("Selected {0} action(s) to run." -f $SelectedActions.Count)

foreach ($Computer in $ComputerName) {

    Write-Host ""
    Write-Host ("===== {0} =====" -f $Computer) -ForegroundColor Cyan

    # Build CIM session parameters
    $cimParams = @{ ErrorAction = 'Stop' }
    if ($Computer -ne $env:COMPUTERNAME -and $Computer -ne 'localhost' -and $Computer -ne '.') {
        $cimParams['ComputerName'] = $Computer
        if ($Credential -and $Credential -ne [System.Management.Automation.PSCredential]::Empty) {
            $cimParams['Credential'] = $Credential
        }
    }

    # Verify the SCCM client is present before doing anything else
    try {
        $client = Get-CimInstance -Namespace 'root\ccm' -ClassName 'SMS_Client' @cimParams
        Write-Verbose ("SCCM client version: {0}" -f $client.ClientVersion)
    }
    catch {
        Write-Warning ("[{0}] SCCM client not detected or not reachable: {1}" -f $Computer, $_.Exception.Message)
        continue
    }

    # Trigger each requested schedule
    foreach ($name in $SelectedActions) {

        $scheduleId = $ScheduleMap[$name]
        Write-Host (" -> {0}" -f $name) -NoNewline

        try {
            Invoke-CimMethod -Namespace 'root\ccm' `
                             -ClassName 'SMS_Client' `
                             -MethodName 'TriggerSchedule' `
                             -Arguments @{ sScheduleID = $scheduleId } `
                             @cimParams | Out-Null

            Write-Host "  [OK]" -ForegroundColor Green
        }
        catch {
            Write-Host "  [FAILED]" -ForegroundColor Red
            Write-Warning ("    {0}" -f $_.Exception.Message)
        }

        if ($DelaySeconds -gt 0) {
            Start-Sleep -Seconds $DelaySeconds
        }
    }
}


Write-Host ""
Write-Host "All requested SCCM client actions have been dispatched." -ForegroundColor Cyan
Write-Host "Note: actions run asynchronously on the client. Check CCM logs (e.g. PolicyAgent.log, ScanAgent.log, AppEnforce.log) for status." -ForegroundColor DarkGray

