# Requirements Document

## Introduction

This feature is a set of Windows scripts (`.bat` / `.ps1`) that configure VS Code and Kiro IDE for maximum autonomous agent operation. The scripts enable autopilot/agent mode, suppress approval dialogs, raise iteration limits, and run a background watchdog that detects when the agent halts mid-task and automatically resumes it. A parallel script set targets Kiro IDE, which has its own autopilot mode and configuration paths. Both script sets must work without a paid GitHub Copilot subscription (using the free tier or alternative open-source AI extensions).

## Glossary

- **VS_Code_Script**: The `.bat` / `.ps1` script(s) that configure VS Code for autonomous agent operation.
- **Kiro_Script**: The `.bat` / `.ps1` script(s) that configure Kiro IDE for autonomous agent operation.
- **Settings_Writer**: The component (Python or PowerShell fallback) that reads and merges JSON settings files.
- **Watchdog**: The background PowerShell process that monitors an IDE for a halted agent and sends a resume signal.
- **Agent_File**: A `.agent.md` or equivalent configuration file that defines persistent agent behavior instructions.
- **Steering_File**: A Kiro-specific `.md` file placed in `.kiro/steering/` that provides persistent behavioral instructions to the Kiro agent.
- **Autopilot_Mode**: The IDE operating mode in which the agent executes tasks without per-action human approval.
- **Supervised_Mode**: The IDE operating mode in which the agent pauses for human approval before each action.
- **Halt**: The state in which an agent stops producing output and awaits user input, despite having remaining tasks.
- **Resume_Signal**: A keyboard sequence or UI interaction sent by the Watchdog to re-activate a halted agent.
- **Free_Tier**: GitHub Copilot Free (no paid subscription), which provides limited monthly completions and chat interactions.
- **Alternative_Extension**: A VS Code extension that provides agent/chat capabilities without requiring a GitHub Copilot subscription (e.g., Continue, Cline, Roo Code).
- **settings.json**: The VS Code user-level settings file located at `%APPDATA%\Code\User\settings.json`.
- **cli.json**: The Kiro CLI settings file located at `%USERPROFILE%\.kiro\settings\cli.json`.
- **Backup**: A timestamped copy of a settings file created before modification, named `<original-filename>.pre-autopilot.bak`.

---

## Requirements

### Requirement 1: VS Code Settings Configuration

**User Story:** As a developer, I want the VS Code script to apply all necessary settings for autonomous agent operation, so that I do not have to manually edit settings.json.

#### Acceptance Criteria

1. WHEN the VS_Code_Script is executed, THE Settings_Writer SHALL locate the VS Code `settings.json` file, checking `%APPDATA%\Code\User\settings.json` first, then `%APPDATA%\Code - Insiders\User\settings.json`, and using the first path that exists; IF both paths exist, THE Settings_Writer SHALL use the Stable (`Code`) path.
2. IF no `settings.json` file exists at either path, THEN THE Settings_Writer SHALL create the file and its full parent directory tree before writing settings.
3. WHEN the Settings_Writer is about to modify `settings.json`, THE Settings_Writer SHALL first create a Backup named `settings.json.pre-autopilot.bak` in the same directory; IF the Backup cannot be created, THEN THE Settings_Writer SHALL abort and exit with a non-zero status code without modifying the original file.
4. WHEN the Settings_Writer writes to `settings.json`, THE Settings_Writer SHALL merge the following key-value pairs into the existing JSON object:
   - `"chat.autopilot.enabled": true`
   - `"chat.agent.enabled": true`
   - `"github.copilot.chat.agent.enabled": true`
   - `"chat.agent.maxRequests": 500`
   - `"chat.commandCenter.enabled": true`
   - `"github.copilot.chat.tools.terminal.autoApprove": true`
   - `"chat.tools.autoApprove": true`
   - `"chat.agent.autoApproveTools": true`
5. THE Settings_Writer SHALL preserve all pre-existing keys in `settings.json` that are not in the target key set defined in criterion 4.
6. WHEN the Settings_Writer completes successfully, THE VS_Code_Script SHALL print to stdout a summary table listing each key from criterion 4 and whether it was ADDED, UPDATED, or ALREADY CORRECT.
7. IF Python is not available on the system PATH, THEN THE Settings_Writer SHALL automatically fall back to a PowerShell-based JSON merge; IF PowerShell is also unavailable, THEN THE Settings_Writer SHALL exit with a non-zero status code and print an error message identifying the missing dependency.
8. IF `settings.json` contains malformed JSON at the time of reading, THEN THE Settings_Writer SHALL log a parse error to stdout, skip modification, and exit with a non-zero status code without creating or overwriting the Backup.

---

### Requirement 2: VS Code Agent File Creation

**User Story:** As a developer, I want a persistent agent instruction file deployed to VS Code, so that the agent never halts or asks for confirmation regardless of which session I start.

#### Acceptance Criteria

1. WHEN the VS_Code_Script is executed, THE VS_Code_Script SHALL create the parent directory `%USERPROFILE%\.copilot\agents\` if it does not already exist.
2. WHEN the VS_Code_Script is executed, THE VS_Code_Script SHALL write an Agent_File at `%USERPROFILE%\.copilot\agents\autopilot-persistent.agent.md` containing the content defined by the current script execution.
3. THE Agent_File SHALL instruct the agent to never pause for user confirmation before taking an action.
4. THE Agent_File SHALL instruct the agent to auto-retry failed operations up to 5 times before reporting a failure, and to process all pending tasks sequentially until none remain before indicating all tasks are complete.
5. THE Agent_File SHALL grant permission for all built-in tools without per-tool approval prompts, expressed as a wildcard tool grant in the file's front-matter or configuration block.
6. IF the Agent_File already exists at the target path, THEN THE VS_Code_Script SHALL overwrite it with the content defined by the current script execution without prompting the user.

---

### Requirement 3: VS Code Free-Tier and Alternative Extension Support

**User Story:** As a developer without a paid Copilot subscription, I want the script to configure a working autonomous agent setup, so that I can use autopilot features at no cost.

#### Acceptance Criteria

1. WHEN the VS_Code_Script is executed, THE VS_Code_Script SHALL check whether the GitHub Copilot extension (`GitHub.copilot`) is listed in the output of `code --list-extensions` and print a status line indicating INSTALLED or NOT FOUND.
2. WHERE the GitHub Copilot extension is not installed or the check returns NOT FOUND, THE VS_Code_Script SHALL print step-by-step instructions for installing the extension via the VS Code marketplace and signing in to a GitHub account using GitHub Copilot Free (no credit card required).
3. WHERE the GitHub Copilot extension is not installed or not authenticated, THE VS_Code_Script SHALL print a note that the "Continue" extension (`continue.dev`, extension ID `Continue.continue`) is a zero-cost alternative supporting local and API-based models, and SHALL include a commented-out alternative settings block for Continue in the script output.
4. WHEN the VS_Code_Script prints its summary, THE VS_Code_Script SHALL include a line stating that GitHub Copilot Free provides 2,000 inline code suggestions and 50 premium chat requests per month, and that agent mode is available on the free tier without a paid subscription.

---

### Requirement 4: VS Code Watchdog Auto-Resume

**User Story:** As a developer running long autonomous tasks, I want a background watchdog process that detects when the agent halts and automatically sends a resume signal, so that tasks complete without my intervention.

#### Acceptance Criteria

1. WHEN the VS_Code_Script is executed, THE VS_Code_Script SHALL write a PowerShell watchdog script at `%USERPROFILE%\.copilot\autopilot_watchdog.ps1`; IF the file already exists, THE VS_Code_Script SHALL overwrite it with the current version.
2. WHILE the Watchdog is running, THE Watchdog SHALL poll for a running VS Code process (`Code.exe` or `Code - Insiders.exe`) at a configurable interval between 1 and 60 seconds (default: 8 seconds).
3. WHEN the VS Code window title remains identical across consecutive poll samples for a cumulative duration equal to or exceeding a configurable idle threshold between 10 and 300 seconds (default: 25 seconds), THE Watchdog SHALL classify the agent as halted and reset the idle timer.
4. WHEN a Halt is detected, THE Watchdog SHALL bring the VS Code window to the foreground and send the Resume_Signal text `"continue working on the remaining tasks"` followed by Enter to the active chat input, then reset the idle timer to prevent an immediate re-trigger.
5. IF the VS Code window cannot be brought to the foreground during a resume attempt, THEN THE Watchdog SHALL log the failure with a timestamp and skip that resume attempt without crashing.
6. WHEN a Resume_Signal has been sent, THE Watchdog SHALL wait a configurable cooldown period between 5 and 300 seconds (default: 15 seconds) before resuming normal polling.
7. WHILE the Watchdog is running, THE Watchdog SHALL log each halt detection and resume attempt to the console with a timestamp in `HH:mm:ss` format.
8. IF no VS Code process is found during a poll cycle, THEN THE Watchdog SHALL log a waiting message with a timestamp and continue polling without exiting.
9. WHEN the VS_Code_Script is executed, THE VS_Code_Script SHALL create a launcher batch file at `%USERPROFILE%\.copilot\Start-Autopilot-Watchdog.bat` that starts the Watchdog in a new PowerShell window with `-ExecutionPolicy Bypass`.

---

### Requirement 5: Kiro IDE Settings Configuration

**User Story:** As a developer using Kiro IDE, I want the Kiro script to configure Kiro for full autopilot operation, so that Kiro operates autonomously without per-action approval prompts.

#### Acceptance Criteria

1. WHEN the Kiro_Script is executed, THE Settings_Writer SHALL locate the Kiro settings file at `%USERPROFILE%\.kiro\settings\cli.json`.
2. IF the Kiro settings file does not exist, THEN THE Settings_Writer SHALL create the full directory path `%USERPROFILE%\.kiro\settings\` and the `cli.json` file before writing settings.
3. WHEN the Settings_Writer is about to modify `cli.json`, THE Settings_Writer SHALL first create a Backup named `cli.json.pre-autopilot.bak` in the same directory (`%USERPROFILE%\.kiro\settings\`); IF the Backup cannot be created, THEN THE Settings_Writer SHALL abort without modifying the original file.
4. THE Settings_Writer SHALL merge the following key-value pairs into the Kiro settings JSON object: `"autoApprove": true` and `"supervisedMode": false`.
5. THE Settings_Writer SHALL preserve all pre-existing keys in `cli.json` that are not `autoApprove` or `supervisedMode`.
6. IF `cli.json` contains malformed JSON at the time of reading, THEN THE Settings_Writer SHALL log a parse error to stdout, skip modification, and exit with a non-zero status code without creating or overwriting the Backup.
7. WHEN the Kiro_Script completes successfully, THE Kiro_Script SHALL print to stdout a summary table listing each key from criterion 4 and whether it was ADDED, UPDATED, or ALREADY CORRECT (defined as the key existing with the required value).

---

### Requirement 6: Kiro Steering File Creation

**User Story:** As a developer using Kiro IDE, I want a persistent steering file deployed to my Kiro configuration, so that the Kiro agent always operates in autopilot mode and never halts mid-task.

#### Acceptance Criteria

1. WHEN the Kiro_Script is executed, THE Kiro_Script SHALL create the parent directory `%USERPROFILE%\.kiro\steering\` if it does not already exist.
2. WHEN the Kiro_Script is executed, THE Kiro_Script SHALL write a Steering_File at `%USERPROFILE%\.kiro\steering\autopilot-persistent.md` encoded in UTF-8.
3. THE Steering_File SHALL begin with a YAML front-matter block containing `inclusion: always` so Kiro loads it in every session.
4. THE Steering_File SHALL instruct the Kiro agent to operate in Autopilot_Mode and never pause for user confirmation before taking an action.
5. THE Steering_File SHALL instruct the Kiro agent to auto-retry failed operations up to 5 times with a 3-second delay between retries before reporting a failure.
6. THE Steering_File SHALL instruct the Kiro agent to process all pending tasks sequentially until none remain before indicating all tasks are complete.
7. IF the Steering_File already exists at the target path, THEN THE Kiro_Script SHALL overwrite it with the content defined by the current script execution without prompting the user.

---

### Requirement 7: Kiro Watchdog Auto-Resume

**User Story:** As a developer running long Kiro tasks, I want a background watchdog that detects when Kiro's agent halts and automatically resumes it, so that tasks complete without my intervention.

#### Acceptance Criteria

1. WHEN the Kiro_Script is executed, THE Kiro_Script SHALL write a PowerShell watchdog script at `%USERPROFILE%\.kiro\autopilot_watchdog.ps1`; IF the file already exists, THE Kiro_Script SHALL overwrite it with the current version.
2. WHILE the Watchdog is running, THE Watchdog SHALL poll for a running Kiro process (`Kiro.exe`) at a configurable interval between 1 and 60 seconds (default: 8 seconds).
3. IF no Kiro process is found during a poll cycle, THEN THE Watchdog SHALL log a waiting message with a timestamp and continue polling without exiting.
4. WHEN the Kiro window title remains identical across consecutive poll samples for a cumulative duration equal to or exceeding a configurable idle threshold between 10 and 300 seconds (default: 25 seconds), THE Watchdog SHALL classify the Kiro agent as halted and reset the idle timer.
5. WHEN a Halt is detected and the Kiro window is reachable, THE Watchdog SHALL bring the Kiro window to the foreground and send the Resume_Signal text `"continue working on the remaining tasks"` followed by Enter to the active chat input, then reset the idle timer to prevent an immediate re-trigger.
6. IF the Kiro window cannot be brought to the foreground during a resume attempt, THEN THE Watchdog SHALL log the failure with a timestamp and resume polling without crashing.
7. WHEN a Resume_Signal has been sent, THE Watchdog SHALL wait a configurable cooldown period between 5 and 300 seconds (default: 15 seconds) before resuming normal polling.
8. WHILE the Watchdog is running, THE Watchdog SHALL log each halt detection and resume attempt to the console with a timestamp in `HH:mm:ss` format.
9. WHEN the Kiro_Script is executed, THE Kiro_Script SHALL create a launcher batch file at `%USERPROFILE%\.kiro\Start-Autopilot-Watchdog.bat` that starts the Kiro Watchdog in a new PowerShell window with `-ExecutionPolicy Bypass`.

---

### Requirement 8: Script Robustness and Error Handling

**User Story:** As a developer, I want the scripts to handle missing dependencies and unexpected states gracefully, so that they do not silently fail or corrupt my settings.

#### Acceptance Criteria

1. IF Python is unavailable on the system PATH, THEN THE Settings_Writer SHALL automatically and silently fall back to PowerShell for all JSON read/write operations without requiring user intervention.
2. IF both Python and PowerShell are unavailable, THEN THE Settings_Writer SHALL print an error message identifying the missing dependencies and exit with a non-zero status code.
3. IF the target settings file contains malformed JSON, THEN THE Settings_Writer SHALL log a parse error to stdout identifying the file path, restore the most recent valid Backup if one exists, and exit with a non-zero status code; IF the Backup restoration also fails, THEN THE Settings_Writer SHALL log a restoration failure error and exit with a non-zero status code.
4. WHILE the Watchdog is running and the IDE process is not found, THE Watchdog SHALL log a waiting message with a timestamp every 5 seconds and continue polling; IF the IDE process is not found after 360 consecutive poll cycles (approximately 30 minutes at the default interval), THE Watchdog SHALL log a timeout warning and continue polling indefinitely.
5. IF the Watchdog fails to bring the IDE window to the foreground, THEN THE Watchdog SHALL log the failure with a timestamp and skip that resume attempt without crashing.
6. WHEN either script completes execution (successfully or with errors), THE script SHALL print a summary section to stdout listing: (a) each file created or modified with its full path, (b) each file that failed to be created or modified with the reason, and (c) the next steps the user must take to activate the configured setup.

---

### Requirement 9: Script Idempotency

**User Story:** As a developer, I want to be able to re-run either script safely at any time, so that running it twice does not duplicate entries or corrupt settings.

#### Acceptance Criteria

1. WHEN the VS_Code_Script is executed on a system where it has previously been run, THE Settings_Writer SHALL compare each target key's current value in `settings.json` against the required value and update only keys whose current value differs from the required value, leaving all other keys unchanged.
2. WHEN the Kiro_Script is executed on a system where it has previously been run, THE Settings_Writer SHALL compare each target key's current value in `cli.json` against the required value and update only keys whose current value differs from the required value, leaving all other keys unchanged.
3. WHEN either script creates an Agent_File or Steering_File and the target file already exists, THE script SHALL overwrite the file with the content defined by the current script execution without prompting the user and without appending to the existing content.
4. WHEN either script creates a Watchdog script or launcher batch file and the target file already exists, THE script SHALL overwrite the file with the content defined by the current script execution without prompting the user and without appending to the existing content.
5. WHEN either script is run a second time with no changes to the target configuration, THE script's summary output SHALL report all keys as ALREADY CORRECT and all files as UP TO DATE, with no files modified.
