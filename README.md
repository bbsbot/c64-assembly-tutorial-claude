# 🕹️ C64 AI Development Swarm

**The ultimate "Zero-to-Hero" repository for Commodore 64 development. Powered by Claude Code.**

This repository transforms [Claude Code]() into a world-class Commodore 64 Development Team. Whether you are a seasoned assembly veteran or a complete beginner who just wants to build their first game, this repo provides the **Skills**, **Personas**, and **Automated Toolchains** to make it happen.  [More Resources here](RESOURCES_DIRECTORY.md)

## 🚀 The "One-Command" Vision

Our goal is simple: You start with an empty folder and a Claude Pro plan. You run one command, and Claude **installs everything**—Java, Kick Assembler, VICE, and the project structure—so you can start coding your game immediately.

---

## 🛠️ Quick Start Guide

### 1. Prerequisites

* **Claude Pro or Max Plan:** Required for high-volume development with Claude Code.
* **Node.js (LTS):** Necessary to run the MCP servers that bridge Claude to your C64.
* **Git:** To clone this repository and manage your project versions.

### 2. Install Claude Code

Open your terminal (PowerShell on Windows, or Terminal on macOS/Linux) and run the native installer:

```bash
# Windows (PowerShell)
& ([scriptblock]::Create((irm https://claude.ai/install.ps1))) stable

# macOS/Linux
curl -fsSL https://claude.ai/install.sh | bash -s stable

```

*After installation, run `claude` to authenticate with your Anthropic account.*

### 3. Initialize Your Swarm

Clone this repository into your new project folder and let the AI take over:

```bash
git clone https://github.com/your-repo/c64-swarm.git .
claude

```

**Once inside Claude Code, simply type:**

> "Let's get started. Initialize the environment and onboard me."

---

## 🧠 What Happens Next?

Claude will read the `skills/` directory and execute the following automated workflow:

### 📥 Automated Provisioning

Claude uses the `provisioning/bootstrap.md` skill to:

1. **Check for Java:** Essential for running the Kick Assembler.
2. **Install Kick Assembler:** Downloads the latest `.jar` and sets up the build path.
3. **Setup VICE Emulator:** Locates or assists in installing the VICE emulator for real-time testing.

### 🤝 The Adaptive Onboarding

The `collaboration/onboarding.md` skill triggers an interview. Claude will ask about your experience level to adapt its coaching style:

* **Beginner Mode:** Claude acts as a **Mentor**, explaining concepts like Zero-Page and OpCodes as you go.
* **Expert Mode:** Claude acts as a **Senior Partner**, focusing on cycle-exact timing, illegal opcodes, and advanced REU banking.

### 🏗️ Project Scaffolding

Claude will automatically generate the canonical C64 project structure:

* `/src`: Your 6502 assembly files.
* `/assets`: Raw graphics and SID music.
* `/build`: Auto-generated `.prg` and `.d64` files.

---

## 📂 Repository Structure

| Folder | Description |
| --- | --- |
| **`.claude/`** | Global instructions (`CLAUDE.md`) and Agent Personas (`AGENTS.md`). |
| **`skills/provisioning/`** | The "Auto-Installer" logic for your toolchain. |
| **`skills/collaboration/`** | Logic for pair-programming and user experience levels. |
| **`skills/geos-pro/`** | Expert-level GEOS skills including REU (RAM Expansion) mastery. |
| **`skills/graphics-vic-ii/`** | Master-class routines for sprite multiplexing and raster timing. |
| **`skills/communication-bbs/`** | RS232 drivers and PETSCII protocols for terminal/BBS apps. |
| **`skills/asset-pipeline/`** | Automation for Aseprite (via Pixel Plugin) and Disk Management. |
| **`RESOURCE_DIRECTORY.md`** | Links to Commodore 64 hardware and software resources. |

---

## 🕹️ Ready to build?

Just tell Claude what you want to create:

* *"Help me design a parallax scrolling shooter."*
* *"I want to build a GEOS utility that uses an REU for fast data processing."*
* *"Let's start a BBS terminal program with custom PETSCII menus."*

**The 8-bit future is in your hands. Let's get to work.**# c64-assembly-tutorial-claude
