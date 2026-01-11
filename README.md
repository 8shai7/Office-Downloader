# Office Deployment Tool – Interactive PowerShell Installer

Interactive PowerShell script for downloading and optionally installing Microsoft Office using the **Microsoft Office Deployment Tool (ODT)**.

Designed to run **directly from the internet** using:

```powershell
irm "github.com/8shai7/Office-Downloader/blob/main/downloader.ps1" | iex
```

No manual XML editing required.

---

## ✨ Features

- Automatically downloads the **Office Deployment Tool**
- Interactive selection of:
  - Office product (Microsoft 365 Apps, Office LTSC 2024, Visio, Project)
  - Architecture (32-bit / 64-bit)
  - Update channel
  - Language
  - Optional exact build version
  - Apps to exclude (Word, Excel, Outlook, etc.)
  - Shared Computer Licensing (RDS / VDI)
  - Download-only or Download + Install
- Generates a valid `configuration.xml`
- Executes:
  - `setup.exe /download`
  - `setup.exe /configure` (optional)
- Fully compatible with `irm | iex`
- No external dependencies

---

## 📦 Supported Products

- Microsoft 365 Apps for Enterprise  
- Office LTSC 2024
  - Professional Plus
  - Standard
- Visio LTSC 2024
- Project LTSC 2024

---

## 🖥 Requirements

- Windows 10 / Windows 11 / Windows Server
- PowerShell 5.1 or newer
- Internet connection
- **Administrator privileges recommended**
  - Required for installation
  - Download-only usually works without elevation

---

## 🚀 Usage

```powershell
irm "github.com/8shai7/Office-Downloader/blob/main/downloader.ps1" | iex
```

---

## 📜 License

MIT License
