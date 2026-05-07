# Autopilot for Agentic IDEs

> **Autopilot for agentic IDEs.** Enable full autonomous agent operation across VS Code, Kiro IDE, and Antigravity — removes approval dialogs, iteration caps, and mid-task halts so your agent can complete tasks end-to-end without interruption.

Autopilot for Agentic IDEs is a set of Windows scripts that configure **VS Code**, **Kiro IDE**, and **Antigravity** for maximum autonomous agent operation. One script per IDE. No manual JSON editing. Fully idempotent — safe to re-run at any time.

---

## What It Does

| Feature | VS Code | Kiro |
|---|---|---|
| Enables agent / autopilot mode | ✅ | ✅ |
| Suppresses per-action approval dialogs | ✅ | ✅ |
| Raises agent iteration limit to 500 | ✅ | — |
| Deploys persistent "never-halt" instruction file | ✅ `.agent.md` | ✅ steering file |
| Deploys background watchdog that auto-resumes a halted agent | ✅ | ✅ |
| Backs up your settings before touching them | ✅ | ✅ |
| Works without a paid GitHub Copilot subscription | ✅ | ✅ |

---

## Supported IDEs

This project enables autopilot mode on three leading agentic IDEs:

- **VS Code** with GitHub Copilot — Enables agent mode, suppresses approval dialogs, and raises iteration limits
- **Kiro IDE** (Amazon's agentic IDE) — Configures autopilot mode and deploys persistent steering instructions
- **Antigravity** (Google's agentic IDE) — Enables full autonomous operation with automatic retry and resumption capabilities

---

## Quick Start

### VS Code

```bat
enable_vscode_autopilot.bat
```

### Kiro IDE

```bat
enable_kiro_autopilot.bat
```

Both scripts require no arguments. Run them from any directory. They are safe to re-run — a second run with no changes reports everything as `ALREADY CORRECT`.

---

## Prerequisites

| Requirement | Notes |
|---|---|
| Windows 10 / 11 | Scripts use `.bat` + PowerShell |
| Python 3.x **or** PowerShell 5+ | Python is preferred; PowerShell is the automatic fallback |
| VS Code (Stable or Insiders) | For the VS Code script |
| Kiro IDE | For the Kiro script |
| GitHub account (free) | For GitHub Copilot Free — no credit card required |

---

## Detailed Installation

### Step 1 — Clone or download this repository

```bat
git clone https://github.com/BarnsAWS/Autopilot-for-Agentic-IDEs.git
cd "Autopilot-for-Agentic-IDEs"
```

Or download the ZIP from the GitHub releases page and extract it.

### Step 2 — Run the script for your IDE

**VS Code:**
```bat
enable_vscode_autopilot.bat
```

**Kiro:**
```bat
enable_kiro_autopilot.bat
```

### Step 3 — Start the watchdog (optional but recommended)

After the script runs, a watchdog launcher is placed at:

- VS Code: `%USERPROFILE%\.copilot\Start-Autopilot-Watchdog.bat`
- Kiro: `%USERPROFILE%\.kiro\Start-Autopilot-Watchdog.bat`

Double-click the launcher (or run it from a terminal) before starting a long autonomous task. The watchdog runs in its own PowerShell window and automatically sends a resume signal if the agent goes idle.

### Step 4 — Restart your IDE

Restart VS Code or Kiro to pick up the new settings.

---

## What Gets Installed

### VS Code

| File | Location | Purpose |
|---|---|---|
| `settings.json` (modified) | `%APPDATA%\Code\User\` | Enables autopilot, raises limits, suppresses approvals |
| `settings.json.pre-autopilot.bak` | Same directory | Backup of your original settings |
| `autopilot-persistent.agent.md` | `%USERPROFILE%\.copilot\agents\` | Persistent "never-halt" agent instructions |
| `autopilot_watchdog.ps1` | `%USERPROFILE%\.copilot\` | Background watchdog script |
| `Start-Autopilot-Watchdog.bat` | `%USERPROFILE%\.copilot\` | One-click watchdog launcher |

**Settings applied to `settings.json`:**

```json
{
    "chat.autopilot.enabled": true,
    "chat.agent.enabled": true,
    "github.copilot.chat.agent.enabled": true,
    "chat.agent.maxRequests": 500,
    "chat.commandCenter.enabled": true,
    "github.copilot.chat.tools.terminal.autoApprove": true,
    "chat.tools.autoApprove": true,
    "chat.agent.autoApproveTools": true
}
```

### Kiro IDE

| File | Location | Purpose |
|---|---|---|
| `cli.json` (modified) | `%USERPROFILE%\.kiro\settings\` | Enables autoApprove, disables supervisedMode |
| `cli.json.pre-autopilot.bak` | Same directory | Backup of your original settings |
| `autopilot-persistent.md` | `%USERPROFILE%\.kiro\steering\` | Persistent steering file loaded every session |
| `autopilot_watchdog.ps1` | `%USERPROFILE%\.kiro\` | Background watchdog script |
| `Start-Autopilot-Watchdog.bat` | `%USERPROFILE%\.kiro\` | One-click watchdog launcher |

**Settings applied to `cli.json`:**

```json
{
    "autoApprove": true,
    "supervisedMode": false
}
```

---

## The Watchdog

The watchdog is a PowerShell background process that monitors your IDE for a halted agent and automatically sends a resume signal.

**How it works:**
1. Polls for the IDE process every 8 seconds (configurable).
2. Tracks the IDE window title. If the title stays unchanged for 25 seconds (configurable), the agent is classified as halted.
3. Brings the IDE window to the foreground and types `"continue working on the remaining tasks"` + Enter into the active chat input.
4. Waits 15 seconds (configurable cooldown) before resuming normal polling.

**Configurable parameters** (edit the top of `autopilot_watchdog.ps1`):

| Parameter | Default | Range | Description |
|---|---|---|---|
| `$checkInterval` | 8 s | 1–60 s | How often to poll the IDE process |
| `$idleThreshold` | 25 s | 10–300 s | Seconds of unchanged title before halt is declared |
| `$cooldownPeriod` | 15 s | 5–300 s | Post-resume wait before resuming normal polling |

**Sample watchdog log output:**
```
[14:32:01] Active. Idle: 3s / 25s threshold
[14:32:09] Active. Idle: 11s / 25s threshold
[14:32:17] Active. Idle: 19s / 25s threshold
[14:32:25] HALT DETECTED — idle 25s. Sending resume #1...
[14:32:26] Resume sent successfully.
[14:32:41] Active. Idle: 0s / 25s threshold
```

---

## GitHub Copilot Free Tier

You do not need a paid subscription. GitHub Copilot Free provides:

- **2,000** inline code suggestions per month
- **50** premium chat requests per month
- **Agent mode** is available on the free tier

To get started: install the `GitHub.copilot` extension in VS Code, sign in with any GitHub account, and select the Free plan. No credit card required.

**Zero-cost alternative:** The [Continue](https://continue.dev) extension (`Continue.continue`) supports local models (Ollama, LM Studio) and API-based models with no subscription required.

---

## Kiro IDE and Steering Files

[Kiro](https://kiro.dev) is Amazon's agentic IDE. It supports two operating modes:

- **Autopilot mode** — the agent executes tasks end-to-end without per-action approval.
- **Supervised mode** — the agent pauses for approval before each action.

This project configures Kiro for Autopilot mode and deploys a **steering file** — a Markdown file with `inclusion: always` front-matter that Kiro loads in every session. The steering file instructs the agent to:

- Never pause for user confirmation
- Auto-retry failed operations up to 5 times (3-second delay between retries)
- Process all pending tasks sequentially before signaling completion

---

## Project Files

```
VS Code Autopilot Enable/
├── enable_vscode_autopilot.bat          # VS Code setup script (run this)
├── enable_kiro_autopilot.bat            # Kiro setup script (run this)
├── settings_writer.py                   # Python JSON merge component
├── settings_writer_fallback.ps1         # PowerShell fallback for settings merge
├── vscode_agent_file_content.md         # Template for VS Code agent file
├── kiro_steering_file_content.md        # Template for Kiro steering file
├── vscode_autopilot_watchdog.ps1        # VS Code watchdog template
├── kiro_autopilot_watchdog.ps1          # Kiro watchdog template
├── README.md                            # This file
└── .kiro/
    └── specs/
        └── autopilot-enabler/
            ├── requirements.md          # Full requirements specification
            ├── design.md                # Architecture and design document
            └── tasks.md                 # Implementation task list
```

---

## Safety

- **Backups first.** The settings writer always creates a `.pre-autopilot.bak` backup before modifying any settings file. If the backup fails, the original file is not touched.
- **Idempotent.** Running either script twice produces no changes on the second run. Every key is compared before writing.
- **Non-destructive.** Existing settings keys not in the required set are always preserved.
- **Malformed JSON protection.** If your settings file contains invalid JSON, the script logs the error and exits without modifying or backing up the file.

---

## Reverting

To undo the changes made by either script, restore the backup:

**VS Code:**
```bat
copy "%APPDATA%\Code\User\settings.json.pre-autopilot.bak" "%APPDATA%\Code\User\settings.json"
```

**Kiro:**
```bat
copy "%USERPROFILE%\.kiro\settings\cli.json.pre-autopilot.bak" "%USERPROFILE%\.kiro\settings\cli.json"
```

---

## Contributing

Pull requests welcome. Please keep changes focused and test with both a clean system (no existing settings) and a system with existing settings to verify idempotency.

---

## License

MIT
