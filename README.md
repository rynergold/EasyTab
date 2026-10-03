<div align="center">

<img src="assets/AppIcon_1024.png" alt="EasyTab Icon" width="128">

# EasyTab

**Fast, lightweight Command+Tab window switcher for macOS.**

Default macOS `Cmd + Tab` only switches between **Applications**, not individual **Windows**.

[![Checks](https://github.com/rynergold/EasyTab/actions/workflows/ci.yml/badge.svg)](https://github.com/rynergold/EasyTab/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![Release](https://img.shields.io/github/v/release/rynergold/EasyTab?color=orange)](https://github.com/rynergold/EasyTab/releases)
[![Platform: macOS](https://img.shields.io/badge/platform-macOS-0078D4)](https://github.com/rynergold/EasyTab)
[![Homebrew](https://img.shields.io/badge/homebrew-cask-FBB040?logo=homebrew&logoColor=white)](Casks/easytab.rb)

[Why EasyTab](#-why-easytab) · [Features & Controls](#-features--controls) · [Installation](#-installation) · [Contributing](CONTRIBUTING.md) · [License](#-license--legal-notice)

</div>

---

## 💡 Why EasyTab?

* **True Alt-Tab on macOS**: Press `⌘ Cmd + Tab` to cycle through every open window across all apps and spaces in real-time Most-Recently-Used (MRU) order.
* **Insanely Lightweight**: Compiled pure Swift with native AppKit + SwiftUI. The entire app bundle is **< 300 KB** and uses **0.0% CPU** at idle.
* **Free forever**: I hate installing a QoL tool to be introduced to bloated irrelevant features, A SIGN IN 🤬😡🌋🤯, AND PAYING FOR SOMETHING SO SMALL LIKE THIS. IF YOU WANT MONEY, ASK FOR DONATIONS.


---

## ✨ Features & Controls

| Shortcut | Action |
| :--- | :--- |
| `⌘ Cmd + Tab` | Open switcher / cycle forward to next window (MRU order) |
| `Release ⌘ Cmd` | Instantly focus & raise selected window |
| `S` | Instant window search (filter by app name or window title) |
| `Enter` / `Release ⌘` | Confirm selected search result |
| `Esc` | Cancel switcher without changing window |


---

## 📦 Installation

### Option 1: Homebrew (Recommended)
```bash
brew install --cask easytab
```

### Option 2: Direct Download (`.dmg`)
1. Download the latest **`EasyTab.dmg`** from [Releases](https://github.com/rynergold/EasyTab/releases).
2. Open the `.dmg` and drag **EasyTab.app** into your **Applications** folder.

### Option 3: Build from Source
```bash
git clone https://github.com/rynergold/EasyTab.git
cd EasyTab
./scripts/build_app.sh
open build/EasyTab.app
```

> **Note on Permissions**: macOS requires **Accessibility permission** for any app that intercepts global hotkeys and switches windows. On first launch, EasyTab will prompt you to enable it in **System Settings > Privacy & Security > Accessibility** because EasyTab is free open-source software and not signed with a paid Apple Developer certificate, macOS Gatekeeper may show a warning on first launch. Simply **Right-Click > Open** (or run `xattr -d com.apple.quarantine /Applications/EasyTab.app`).


---

## 📄 License & Legal Notice

EasyTab is open-source software licensed under the **[MIT License](LICENSE)**.

> **Copyright (c) 2026 EasyTab Contributors. All rights reserved.**  
> *The software is provided "as is", without warranty of any kind, express or implied. In no event shall the authors or copyright holders be liable for any claim, damages, or other liability.*
