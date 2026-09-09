# Discover Gallery Apps Which Support SCIM Provisioning

Reports Microsoft Entra gallery applications in the current tenant that support SCIM provisioning. The script identifies gallery service principals from the Microsoft application catalog, checks whether they have synchronization jobs, reads their synchronization schema, and exports the provisioning capabilities to `SCIMGalleryAppsReport.csv`.

## How it works

1. The script connects to Microsoft Graph using an existing Graph connection or one of the connection commands included in the script.
2. It retrieves the tenant's service principals and Microsoft Entra application templates.
3. It filters application templates to exclude custom applications and mobile device management applications, and keeps templates that support synchronization.
4. It checks each matching enterprise application for synchronization jobs.
5. For applications with a synchronization job, it reads the schema and detects User and Group object mappings and their supported flow types.
6. It writes the results to `SCIMGalleryAppsReport.csv` in the current directory.

## Prerequisites

- A Microsoft Entra tenant with gallery applications available to inspect.
- An account or access token with permission to read service principals, application templates, synchronization jobs, and synchronization schemas.
- PowerShell 7 for local testing.
- The Microsoft Graph PowerShell modules used by the script:
	- `Microsoft.Graph.Authentication`
	- `Microsoft.Graph.Applications`
	- `Microsoft.Graph.Beta.Applications`

Install the required modules for the current user:

```powershell
Install-Module Microsoft.Graph.Authentication -Scope CurrentUser
Install-Module Microsoft.Graph.Applications -Scope CurrentUser
Install-Module Microsoft.Graph.Beta.Applications -Scope CurrentUser
```

## Permissions

The interactive connection in the script requests these delegated Microsoft Graph scopes:

| Scope | Purpose |
| --- | --- |
| `Application.Read.All` | Read service principals and application templates. |
| `Synchronization.Read.All` | Read synchronization jobs and their schemas. |

The signed-in account must be allowed to consent to these scopes. Depending on tenant consent settings, an administrator may need to grant consent before the script can run.

## Run the report

Open PowerShell in this folder and run the script:

```powershell
pwsh ./Invoke-SCIMGalleryAppReport.ps1
```

By default, the script starts an interactive Microsoft Graph sign-in:

```powershell
Connect-MgGraph -Scopes "Application.Read.All", "Synchronization.Read.All"
```

After authentication, it invokes `Invoke-SCIMGalleryAppReport` automatically. The report is written to the current working directory, so run the script from the folder where you want the CSV file created.

### Connect with a browser token

The script also includes an alternative for a token copied to the clipboard. The clipboard value must contain a bearer token, with or without the `Bearer ` prefix:

```powershell
Connect-MgGraph -AccessToken $((Get-Clipboard).Replace("Bearer ", "") | ConvertTo-SecureString -AsPlainText -Force)
Invoke-SCIMGalleryAppReport
```

Use a short-lived token only, and avoid storing access tokens in scripts, command history, or source control.

## Report output

When at least one matching gallery service principal is found, the script creates `SCIMGalleryAppsReport.csv` with these columns:

| Column | Description |
| --- | --- |
| `DisplayName` | Enterprise application display name. |
| `AppId` | Application ID of the service principal. |
| `ObjectId` | Object ID of the service principal. |
| `Provisioningstatus` | `Enabled` when a synchronization job is found; otherwise `Disabled`. |
| `Targetdirectory` | Target directory reported by the synchronization schema. |
| `SupportsUserprov` | Indicates whether the schema contains a User object mapping.  |
| `Supporteduseraction` | Flow types reported for the User object mapping. |
| `SupportsGroupprov` | Indicates whether the schema contains a Group object mapping. |
| `SupportedGroupActions` | Flow types reported for the Group object mapping. |

If `Provisioningstatus` is `Disabled`, no information can be provided about user or group provisioning.

The CSV is overwritten on each run. It uses comma delimiters and does not include PowerShell type information.

If no matching gallery service principals are found, the script writes a message and does not create a report file. Applications that cannot be queried because of access errors or missing synchronization jobs are skipped by the script's error handling.

## Troubleshooting

- **Authorization or consent error:** Verify that the signed-in account has `Application.Read.All` and `Synchronization.Read.All`, and that admin consent has been granted when required.
- **Module not found:** Install the three Microsoft Graph modules listed in the prerequisites section, then reopen PowerShell if necessary.
- **No applications reported:** Confirm that the tenant contains gallery service principals whose application templates support synchronization. Custom applications and templates categorized as mobile device management are excluded.
- **Applications are missing from the report:** Check the permissions and review whether the service principal has a readable synchronization job and schema. The script skips applications when those Graph requests fail.
- **Report saved in the wrong location:** Check the current directory with `Get-Location` before running the script. The output path is `$PWD\SCIMGalleryAppsReport.csv`.

## Notes

- The report describes the gallery applications and synchronization schema currently visible to the signed-in identity; it does not create, enable, or modify provisioning jobs.
- A service principal being listed does not by itself confirm that provisioning is actively running. Review the application’s provisioning settings and provisioning logs in the Microsoft Entra admin center before relying on the result for deployment decisions.
- The script uses both stable Microsoft Graph and beta application cmdlets. Review Graph PowerShell module changes before using it in an unattended or production reporting process.
