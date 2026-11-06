<div align="center">
  <img src="assets/banner.svg" alt="Clean — a lightweight macOS storage cleaner" width="100%">
</div>

<h3 align="center">Your Mac is full. Now you can see why.</h3>

<p align="center">
  <img alt="version" src="https://img.shields.io/badge/version-1.0-8B5CF6?style=flat-square">
  <img alt="platform" src="https://img.shields.io/badge/macOS-26.4%2B-111111?style=flat-square&logo=apple&logoColor=white">
  <img alt="SwiftUI" src="https://img.shields.io/badge/SwiftUI-native-4C7DFF?style=flat-square&logo=swift&logoColor=white">
  <img alt="download size" src="https://img.shields.io/badge/download-860%20KB-30D158?style=flat-square">
</p>

---

**Clean** is a tiny, native macOS app that shows you what every app on your Mac is *actually* costing. For each installed app it adds up three things and lets you trash any of them in one click:

| | What it is | Where it lives |
|:--|:--|:--|
| 🔵 **App** | The application bundle itself | `/Applications` |
| 🟠 **Cache** | Rebuildable caches and logs | `~/Library/Caches`, `Logs`, `HTTPStorages` |
| 🟣 **Data** | Leftover app data and settings | `~/Library/Application Support`, `Containers`, `Preferences`, `Saved Application State`, `Group Containers` |

Sizes are real on-disk allocations, not estimates. Everything you select goes to the **Trash** — never deleted outright, so you can always put it back.

<div align="center">
  <img src="Clean/ss.png" alt="Clean showing per-app App, Cache and Data sizes" width="100%">
</div>

## Install

Open **Terminal** on your Mac and paste these three lines:

```bash
git clone https://github.com/roshandhiman/Clean.git
cd Clean
open dist/Clean-1.0.dmg
```

Then drag **Clean** into your **Applications** folder. Done.

**First launch:** the app isn't notarized, so macOS will block it once. Right-click **Clean** → **Open** → **Open**. After that it launches normally.

<details>
<summary>Or download it in a single command</summary>

```bash
curl -L -o /tmp/Clean.dmg https://github.com/roshandhiman/Clean/raw/main/dist/Clean-1.0.dmg && open /tmp/Clean.dmg
```

</details>

## Build from source

```bash
git clone https://github.com/roshandhiman/Clean.git
cd Clean
open Clean.xcodeproj
```

Press **⌘R** to run. No dependencies, no setup, no package manager.

## Requirements

- macOS **26.4** or later
- Xcode 26+ *(only if you're building from source)*

## Safety

- No admin password, no `sudo`.
- No background agents or login items.
- No network calls, no telemetry, no analytics.
- Deletions use the system Trash API, so every action is reversible.
- Apple system apps (`com.apple.*`) are skipped automatically.

---

<p align="center">
  Built by <a href="https://github.com/roshandhiman"><b>Roshanpreet Singh Dhiman</b></a>
</p>
