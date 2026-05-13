# Invoke-SCCMClientActions

A PowerShell script that triggers Configuration Manager (SCCM/MECM) client agent actions on local or remote computers — the same actions exposed in the **Configuration Manager** applet in Control Panel under the **Actions** tab, but scripted and bulk-runnable.

## Features

- Triggers **14 standard SCCM client actions** via the `SMS_Client` CIM class
- Runs against the **local machine** or **one or more remote computers**
- Run **all actions** or a **filtered subset** with tab-completed names
- Optional **`-Credential`** parameter for remote authentication
- Configurable **delay between actions** to avoid hammering the client
- Verifies the SCCM client is installed/reachable before triggering
- Color-coded per-action status and warnings on failure
- Pipeline-friendly (`'PC01','PC02' | .\Invoke-SCCMClientActions.ps1`)

## Actions Triggered

| Action | Schedule ID |
| --- | --- |
| Machine Policy Retrieval & Evaluation Cycle | `{00000000-0000-0000-0000-000000000021}` |
| Machine Policy Evaluation Cycle | `{00000000-0000-0000-0000-000000000022}` |
| User Policy Retrieval Cycle | `{00000000-0000-0000-0000-000000000026}` |
| User Policy Evaluation Cycle | `{00000000-0000-0000-0000-000000000027}` |
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

## Requirements

- Windows PowerShell 5.1 or PowerShell 7+
- SCCM/MECM client installed on the target machine
- **Local runs:** an elevated (Administrator) PowerShell session
- **Remote runs:** admin rights on the target plus WMI/DCOM (or WinRM) connectivity

## Usage

### Run every action on the local computer (no file download required)

```powershell
irm https://raw.githubusercontent.com/bcheng-esri/Invoke-SCCMClientActions/refs/heads/main/Invoke-SCCMClientActions.ps1 | iex
```

### Run only specific actions

```powershell
.\Invoke-SCCMClientActions.ps1 -Action 'Machine Policy Retrieval & Evaluation Cycle','Software Updates Scan Cycle'
```

> Tip: tab-complete the value of `-Action` to see all supported names.

### Run against remote computers

```powershell
.\Invoke-SCCMClientActions.ps1 -ComputerName 'PC01','PC02'
```

### Run remotely with alternate credentials

```powershell
.\Invoke-SCCMClientActions.ps1 -ComputerName 'PC01','PC02' -Credential (Get-Credential)
```

### Pipeline a list of computers

```powershell
Get-Content .\machines.txt | .\Invoke-SCCMClientActions.ps1
```

### Adjust the delay between actions

```powershell
.\Invoke-SCCMClientActions.ps1 -DelaySeconds 5
```

## Parameters

| Parameter | Type | Default | Description |
| --- | --- | --- | --- |
| `ComputerName` | `string[]` | local computer | One or more target computers. Accepts pipeline input. |
| `Action` | `string[]` | all actions | Specific action(s) to run. If omitted, every action is triggered. |
| `DelaySeconds` | `int` (0–60) | `2` | Seconds to wait between triggering each action. |
| `Credential` | `PSCredential` | none | Credentials used for remote connections. |

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
| Machine / User Policy | `PolicyAgent.log`, `PolicyEvaluator.log` |
| Hardware Inventory | `InventoryAgent.log` |
| Software Inventory | `InventoryAgent.log` |
| Application Deployment Evaluation | `AppDiscovery.log`, `AppEnforce.log` |
| Software Updates Scan | `ScanAgent.log`, `WUAHandler.log` |
| Software Updates Deployment Evaluation | `UpdatesDeployment.log`, `UpdatesHandler.log` |

CMTrace (shipped with the SCCM client) is the recommended viewer.

## Troubleshooting

- **"SCCM client not detected or not reachable"** — the `root\ccm` namespace is missing. Confirm the client is installed and the **SMS Agent Host** (`CcmExec`) service is running.
- **Access denied on remote machines** — make sure your account is a local administrator on the target and that DCOM/WMI (or WinRM) is allowed through the firewall.
- **Action triggers but nothing seems to happen** — some actions (e.g. hardware inventory) only do work when their internal schedule says they're due. Check the corresponding log to confirm execution.

## License

MIT — feel free to use, modify, and redistribute.
