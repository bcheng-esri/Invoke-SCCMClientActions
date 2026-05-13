# Invoke-SCCMClientActions

A PowerShell script that triggers every standard Configuration Manager (SCCM/MECM) machine-level client agent action on the local computer — the same actions exposed in the **Configuration Manager** applet in Control Panel under the **Actions** tab, but scripted and runnable in a single command.

## Features

- Triggers **all 12 standard machine-level SCCM client actions** via the `SMS_Client` CIM class
- Fixed **5-second pause** between actions to avoid hammering the client
- Verifies the SCCM client is installed/reachable before triggering
- Color-coded per-action status and warnings on failure

## Actions Triggered

| Action | Schedule ID |
| --- | --- |
| Machine Policy Retrieval & Evaluation Cycle | `{00000000-0000-0000-0000-000000000021}` |
| Machine Policy Evaluation Cycle | `{00000000-0000-0000-0000-000000000022}` |
| Hardware Inventory Cycle | `{00000000-0000-0000-0000-000000000001}` |
| Software Inventory Cycle | `{00000000-0000-0000-0000-000000000002}` |
| Discovery Data Collection Cycle | `{00000000-0000-0000-0000-000000000003}` |
| File Collection Cycle | `{00000000-0000-0000-0000-000000000010}` |
| Software Metering Usage Report Cycle | `{00000000-0000-0000-0000-000000000031}` |
| Windows Installer Source List Update Cycle | `{00000000-0000-0000-0000-000000000032}` |
| State Message Refresh | `{00000000-0000-0000-0000-000000000040}` |
| Application Deployment Evaluation Cycle | `{00000000-0000-0000-0000-000000000042}` |
| Software Updates Scan Cycle | `{00000000-0000-0000-0000-000000000113}` |
| Software Updates Deployment Evaluation Cycle | `{00000000-0000-0000-0000-000000000108}` |

> User Policy Retrieval and User Policy Evaluation cycles are intentionally omitted; this script only triggers machine-level actions.

## Requirements

- Windows PowerShell 5.1 or PowerShell 7+
- SCCM/MECM client installed on the local machine
- An **elevated (Administrator)** PowerShell session

## Usage

```powershell
irm https://raw.githubusercontent.com/bcheng-esri/Invoke-SCCMClientActions/refs/heads/main/Invoke-SCCMClientActions.ps1 | iex
```

That's it — no parameters. The script runs all 12 actions back-to-back with a 5-second pause between each.

## How It Works

The script calls the `TriggerSchedule` method of the `SMS_Client` class in the `root\ccm` WMI/CIM namespace, passing the appropriate Schedule ID GUID for each action. This is the same mechanism the SCCM client itself uses internally — no third-party modules are required.

```powershell
Invoke-CimMethod -Namespace 'root\ccm' `
                 -ClassName 'SMS_Client' `
                 -MethodName 'TriggerSchedule' `
                 -Arguments @{ sScheduleID = $scheduleId }
```

## Verifying Results

The actions run **asynchronously** on the client. To confirm what each action did, inspect the relevant client log under `C:\Windows\CCM\Logs`:

| Action | Log to check |
| --- | --- |
| Machine Policy | `PolicyAgent.log`, `PolicyEvaluator.log` |
| Hardware Inventory | `InventoryAgent.log` |
| Software Inventory | `InventoryAgent.log` |
| Application Deployment Evaluation | `AppDiscovery.log`, `AppEnforce.log` |
| Software Updates Scan | `ScanAgent.log`, `WUAHandler.log` |
| Software Updates Deployment Evaluation | `UpdatesDeployment.log`, `UpdatesHandler.log` |

CMTrace (shipped with the SCCM client) is the recommended viewer.

## Troubleshooting

- **"SCCM client not detected or not reachable"** — the `root\ccm` namespace is missing. Confirm the client is installed and the **SMS Agent Host** (`CcmExec`) service is running.
- **"Access denied"** — run PowerShell as Administrator.
- **Action triggers but nothing seems to happen** — some actions (e.g. hardware inventory) only do work when their internal schedule says they're due. Check the corresponding log to confirm execution.

## License

MIT — feel free to use, modify, and redistribute.
