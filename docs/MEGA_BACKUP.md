# QX Studio — MEGA project backup

This workflow prepares one portable backup file per QX Studio project. It does not sign in to MEGA or use a MEGA API.

## Upload a project backup

1. Open **My projects** in QX Studio.
2. Open the project actions menu and choose **Export backup for MEGA**.
3. Review the privacy warning and confirm.
4. Save the generated `.qxbackup` file. On Android, save it in Downloads.
5. Open the official MEGA app, choose Upload, browse to Downloads, and upload that project's `.qxbackup` file.

Each project creates a separate backup file. QX Studio does not receive or store the MEGA password.

## Restore a project

1. Download the required `.qxbackup` file from MEGA to the device.
2. In QX Studio, open **My projects** and choose the restore icon.
3. Select the downloaded `.qxbackup` file.
4. QX Studio validates the format and every file's SHA-256 digest, then restores it as a **new project**.

Restore never replaces an existing project or workspace.

## Format and safety limits

- Format: versioned JSON with Base64 file contents and per-file SHA-256 hashes.
- Maximum total original file data: 12 MB per project.
- Maximum generated backup file: 18 MB.
- Maximum 3,000 files and 3,000 directories.
- ZIP is not used by this workflow.
- The local `.qxbackup` file is **not encrypted by QX Studio**. Do not include passwords, private keys, or other secrets in a project backup. Keep the local file in a protected location; upload it to your MEGA account using the official MEGA app.
- This is a manual transfer workflow: QX Studio creates and validates the backup; the MEGA app performs the cloud upload/download.
