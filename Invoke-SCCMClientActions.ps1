<#
.SYNOPSIS
    Triggers all standard SCCM/MECM machine-level client actions on the local machine.

.DESCRIPTION
    This script invokes every standard Configuration Manager machine-level client
    agent schedule by its well-known Schedule ID via the SMS_Client WMI/CIM class
    (root\ccm namespace). It runs against the local computer only. A fixed
    5-second delay is applied between each action.

    Schedule IDs triggered:
        {00000000-0000-0000-0000-000000000021}  Machine Policy Retrieval & Evaluation Cycle
        {00000000-0000-0000-0000-000000000022}  Machine Policy Evaluation Cycle
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

.EXAMPLE
    .\Invoke-SCCMClientActions.ps1
    Runs every standard machine-level action on the local computer with a 5-second
    pause between each.

.NOTES
    Requirements:
        - The SCCM/MECM client must be installed on the local computer.
        - Run from an elevated (Administrator) PowerShell session.
#>

[CmdletBinding()]
param ()

# Fixed delay between actions, in seconds
$DelaySeconds = 5

# Map of friendly names to SCCM ScheduleIDs - all actions will be triggered
$ScheduleMap = [ordered]@{
    'Machine Policy Retrieval & Evaluation Cycle' = '{00000000-0000-0000-0000-000000000021}'
    'Machine Policy Evaluation Cycle'             = '{00000000-0000-0000-0000-000000000022}'
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

Write-Host ""
Write-Host ("===== {0} =====" -f $env:COMPUTERNAME) -ForegroundColor Cyan

# Verify the SCCM client is present before doing anything else
try {
    $client = Get-CimInstance -Namespace 'root\ccm' -ClassName 'SMS_Client' -ErrorAction Stop
    Write-Verbose ("SCCM client version: {0}" -f $client.ClientVersion)
}
catch {
    Write-Warning ("SCCM client not detected or not reachable: {0}" -f $_.Exception.Message)
    Write-Warning "Ensure the SMS Agent Host (CcmExec) service is running and you are running this script elevated."
    return
}

# Trigger every schedule
foreach ($name in $ScheduleMap.Keys) {

    $scheduleId = $ScheduleMap[$name]
    Write-Host (" -> {0}" -f $name) -NoNewline

    try {
        Invoke-CimMethod -Namespace 'root\ccm' `
                         -ClassName 'SMS_Client' `
                         -MethodName 'TriggerSchedule' `
                         -Arguments @{ sScheduleID = $scheduleId } `
                         -ErrorAction Stop | Out-Null

        Write-Host "  [OK]" -ForegroundColor Green
    }
    catch {
        Write-Host "  [FAILED]" -ForegroundColor Red
        Write-Warning ("    {0}" -f $_.Exception.Message)
    }

    Start-Sleep -Seconds $DelaySeconds
}

Write-Host ""
Write-Host "All SCCM client actions have been dispatched." -ForegroundColor Cyan
Write-Host "Note: actions run asynchronously on the client. Check CCM logs (e.g. PolicyAgent.log, ScanAgent.log, AppEnforce.log) for status." -ForegroundColor DarkGray
