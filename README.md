# 🚀 Office ODT High-Speed Installer
**VERSION: 3.4 (The "Reference Fix" Edition)**  
*Optimized for Developers, Instructors, and IT Professionals.*

An interactive PowerShell script designed to streamline the deployment of Microsoft Office suites using the **Office Deployment Tool (ODT)**. This script eliminates the need for manual XML configuration by building and executing the setup logic dynamically based on your input.

---

## ✨ Key Features

- **Smart Scraping:** Automatically crawls the Microsoft Download Center to ensure the latest ODT engine is used.
- **Office 2024 Ready:** Full support for the new LTSC 2024 versions (Pro Plus & Standard).
- **Granular Customization:** Interactive "Install Scope" selection allowing you to include specific apps (e.g., install only Word and Excel).
- **Robust Architecture:** Supports both 64-bit and 32-bit deployments with custom language localized support (e.g., en-us, he-il).
- **Automated Workflow:** Handles downloading, extraction, XML generation, and installation in one seamless process.
- **Zero Footprint:** Automatically cleans up all temporary files from the system `TEMP` directory upon completion.

---

## 📦 Supported Products

*   **Microsoft 365 Apps** (Enterprise/Business)
*   **Office LTSC 2024** (Professional Plus / Standard)
*   **Update Channels:** Automatic switching between `Current` and `PerpetualVL2024` based on product choice.

---

## 🚀 Quick Start (One-Liner)

Run the script directly from the web without downloading files manually:

```powershell
irm https://raw.githubusercontent.com/8shai7/Office-Downloader/main/downloader.ps1 | iex
```

> [!IMPORTANT]
> **Administrator privileges** are required to perform the actual Office installation.

---

## 🛠 Requirements

- **OS:** Windows 10 / 11 / Windows Server
- **PowerShell:** Version 5.1 or higher
- **Network:** Active internet connection for ODT scraping and Office streaming.

---

## 📝 What's New in v3.4?

- **FIX:** Resolved the `[ref]` variable initialization error within the App Selection logic.
- **Optimization:** Enhanced the User-Agent scraping logic for more reliable ODT engine retrieval.
- **Logic Update:** Corrected update channel mapping for 2024 Perpetual Volume licenses.

---

## 📜 License

This project is licensed under the **MIT License**. Feel free to use, modify, and distribute.

---

**Developed by Shai Tal**  
*A Lone Programmer*
