Office Deployment Tool – Interactive PowerShell Installer

Interactive PowerShell script for downloading and optionally installing Microsoft Office using the Microsoft Office Deployment Tool (ODT).

Designed to run directly from the internet using:

irm <SCRIPT_URL> | iex


No manual XML editing required.

✨ Features

Automatically downloads the Office Deployment Tool

Interactive selection of:

Office product (Microsoft 365 Apps, Office LTSC 2024, Visio, Project)

Architecture (32-bit / 64-bit)

Update channel

Language

Optional exact build version

Apps to exclude (Word, Excel, Outlook, etc.)

Shared Computer Licensing (RDS / VDI)

Download-only or Download + Install

Generates a valid configuration.xml

Executes:

setup.exe /download

setup.exe /configure (optional)

Fully compatible with irm | iex

No external dependencies

📦 Supported Products

Microsoft 365 Apps for Enterprise

Office LTSC 2024

Professional Plus

Standard

Visio LTSC 2024

Project LTSC 2024

🖥 Requirements

Windows 10 / Windows 11 / Windows Server

PowerShell 5.1+

Internet connection

Administrator privileges recommended

Required for installation

Download-only works without elevation in most cases

🚀 Usage
Run directly from GitHub (example)
irm https://raw.githubusercontent.com/<user>/<repo>/main/Install-OfficeODT.ps1 | iex

Interactive prompts include

Office product selection

Architecture (64-bit default)

Language (en-us default)

Update channel (Microsoft 365 Apps only)

Optional exact build version

Apps to exclude

Shared Computer Licensing (RDS / VDI)

Download only or install immediately

📁 Output Structure

All files are created in a temporary working directory:

%TEMP%\ODT_YYYYMMDD_HHMMSS\
│
├─ officedeploymenttool.exe
├─ configuration.xml
├─ OfficeSource\        ← downloaded Office files
├─ ODT\setup.exe
└─ logs


The generated configuration.xml can be reused for future installs.

ℹ Version & Channel Notes

Channel controls the update stream

Version is optional and pins a specific build

If no version is specified, ODT downloads the latest available build for the selected channel

This follows Microsoft’s recommended deployment model.

🧩 Common Use Cases
Offline installation

Run script in download-only mode

Copy OfficeSource + configuration.xml to another machine

Run:

setup.exe /configure configuration.xml

RDS / VDI environments

Enable SharedComputerLicensing

Exclude unused apps (e.g. Access, Publisher)

Enterprise / unattended deployment

Fully silent installation

EULA accepted automatically

Suitable for automation pipelines

🛠 Troubleshooting

Installer exits immediately

Run PowerShell as Administrator

Unexpected apps installed

Review ExcludeApp entries in configuration.xml

Specified version not found

That build may no longer be available on the selected channel

Logs are stored in the script’s temporary working directory.

⚠ Disclaimer

This project uses official Microsoft deployment tools and public Microsoft download endpoints.
Always test in a non-production environment before wide deployment.
