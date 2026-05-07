# Implementation Plan: autopilot-enabler

## Overview

Implement the autopilot-enabler as two Windows batch scripts (`enable_vscode_autopilot.bat` and `enable_kiro_autopilot.bat`) plus supporting components: a Python Settings_Writer with PowerShell fallback, VS Code and Kiro agent/steering files, two watchdog PowerShell scripts, two watchdog launcher batch files, and a property-based + integration test suite.

All scripts are deployed to the project root (`VS Code Autopilot Enable\`). Tests live in `tests\`.

---

## Tasks

- [ ] 1. Set up project structure and test framework
  - Create `tests\` directory
  - Create `tests\__init__.py` (empty, marks package)
  - Create `tests\requirements.txt` pinning `hypothesis==6.112.2` and `pytest==8.3.2`
  - Verify `pytest` and `hypothesis` are importable
  - _Requirements: 8.1 (robustness), design §7.5_

- [ ] 2. Implement the Settings_Writer Python component
  - [-] 2.1 Write `settings_writer.py` with `merge_settings(settings_path, required_keys)` function
    - Locate settings file; create parent directories and file if absent
    - Create `.pre-autopilot.bak` backup before any write; abort with non-zero exit if backup fails
    - Skip backup and abort if JSON is malformed; log parse error to stdout
    - Merge required keys using change-classification logic (ADDED / UPDATED / ALREADY CORRECT)
    - Preserve all pre-existing keys not in the required set
    - Return change report dict; raise on unrecoverable errors
    - _Requirements: 1.1, 1.2, 1.3, 1.4, 1.5, 1.8, 5.1, 5.2, 5.3, 5.4, 5.5, 5.6, 8.3, 9.1, 9.2_

  - [ ]* 2.2 Write property test: Settings merge preserves existing keys (Property 1)
    - **Property 1: Settings merge preserves existing keys**
    - **Validates: Requirements 1.4, 1.5, 5.4, 5.5, 9.1, 9.2**
    - Use `hypothesis` to generate random JSON objects and required key sets
    - Assert every original key not in the required set is unchanged after merge
    - File: `tests\test_settings_writer.py`

  - [ ]* 2.3 Write property test: Settings merge sets all required keys (Property 2)
    - **Property 2: Settings merge sets all required keys to required values**
    - **Validates: Requirements 1.4, 5.4, 9.1, 9.2**
    - Generate random existing JSON objects (including empty); assert all required keys have required values after merge
    - File: `tests\test_settings_writer.py`

  - [ ]* 2.4 Write property test: Change report classification (Property 3)
    - **Property 3: Change report correctly classifies every key**
    - **Validates: Requirements 1.6, 5.7, 9.5**
    - Generate random JSON objects with varying key presence and values; assert ADDED / UPDATED / ALREADY CORRECT classification is correct for every key
    - File: `tests\test_settings_writer.py`

  - [ ]* 2.5 Write property test: Second run idempotency (Property 8)
    - **Property 8: Second run produces no modifications**
    - **Validates: Requirements 9.1, 9.2, 9.3, 9.4, 9.5**
    - Run `merge_settings` twice on the same object; assert second run returns all keys as ALREADY CORRECT and writes no changes
    - File: `tests\test_settings_writer.py`

  - [ ]* 2.6 Write unit tests for Settings_Writer error paths
    - Backup creation failure aborts write (mock `shutil.copy2` → `PermissionError`; verify original unchanged)
    - Malformed JSON skips backup and modification (pass truncated JSON; verify no backup, no write, non-zero exit)
    - File: `tests\test_settings_writer.py`

- [ ] 3. Checkpoint — Ensure all Settings_Writer tests pass
  - Run `pytest tests\test_settings_writer.py -v`; fix any failures before continuing.

- [ ] 4. Implement the Settings_Writer PowerShell fallback
  - [-] 4.1 Write `settings_writer_fallback.ps1` implementing the same backup + merge + change-report logic in PowerShell
    - Use `ConvertFrom-Json` / `ConvertTo-Json -Depth 10`
    - Use `Add-Member -Force` to upsert each required key
    - Emit the same ADDED / UPDATED / ALREADY CORRECT output format as the Python component
    - _Requirements: 1.7, 8.1, 8.2_

  - [ ]* 4.2 Write unit tests for PowerShell fallback invocation
    - Python unavailable falls back to PowerShell (mock `python` as not found; verify fallback invoked)
    - Both Python and PowerShell unavailable → error message and non-zero exit
    - File: `tests\test_settings_writer.py`

- [ ] 5. Implement VS Code agent file content
  - [-] 5.1 Write `vscode_agent_file_content.md` (the template for `autopilot-persistent.agent.md`)
    - Include YAML front-matter: `name`, `description`, `tools: ['*']`
    - Body: never-pause directive, auto-retry protocol (5 retries), sequential task queue processing, `[ERROR]` / `[SKIP]` log markers
    - _Requirements: 2.2, 2.3, 2.4, 2.5_

- [ ] 6. Implement VS Code watchdog script
  - [ ] 6.1 Write `vscode_autopilot_watchdog.ps1` (the template embedded in the bat script)
    - Configurable parameters at top: `$checkInterval=8`, `$idleThreshold=25`, `$cooldownPeriod=15`
    - Poll for `Code.exe` or `Code - Insiders.exe`; log waiting message if not found
    - Halt detection: track `lastTitle` and `lastActivityTime`; declare halt when idle ≥ `$idleThreshold`
    - Resume signal: `SetForegroundWindow` via P/Invoke → `SendKeys("^+i")` → type resume text → `SendKeys("{ENTER}")`
    - Log failure and skip if `SetForegroundWindow` returns false or hwnd is 0
    - Post-resume cooldown sleep; reset `lastActivityTime`
    - Log every event with `[HH:mm:ss]` timestamp
    - Log timeout warning after 360 consecutive no-process cycles
    - _Requirements: 4.1, 4.2, 4.3, 4.4, 4.5, 4.6, 4.7, 4.8, 8.4, 8.5_

  - [ ]* 6.2 Write property test: Watchdog halt detection threshold (Property 5)
    - **Property 5: Watchdog halt detection threshold**
    - **Validates: Requirements 4.3, 7.4**
    - Extract halt-detection logic into a pure Python helper; use Hypothesis to generate random title sequences with timestamps; assert halt declared iff idle ≥ threshold
    - File: `tests\test_watchdog_logic.py`

  - [ ]* 6.3 Write property test: Watchdog log timestamp format (Property 6)
    - **Property 6: Watchdog log entries contain valid timestamps**
    - **Validates: Requirements 4.7, 7.8**
    - Generate random watchdog events; assert every emitted log line matches `\d{2}:\d{2}:\d{2}` with valid ranges
    - File: `tests\test_watchdog_logic.py`

  - [ ]* 6.4 Write property test: Watchdog configurable parameter range validation (Property 7)
    - **Property 7: Watchdog configurable parameters are range-validated**
    - **Validates: Requirements 4.2, 4.6, 7.2, 7.7**
    - Generate values inside and outside [1,60] / [5,300] ranges; assert acceptance within bounds and rejection/clamping outside
    - File: `tests\test_watchdog_logic.py`

  - [ ]* 6.5 Write unit tests for watchdog edge cases
    - Process not found → waiting message logged, no crash
    - `SetForegroundWindow` fails → failure logged, no resume sent, polling continues
    - File: `tests\test_watchdog_logic.py`

- [ ] 7. Checkpoint — Ensure all watchdog tests pass
  - Run `pytest tests\test_watchdog_logic.py -v`; fix any failures before continuing.

- [ ] 8. Implement VS Code watchdog launcher
  - [ ] 8.1 Write `vscode_Start-Autopilot-Watchdog.bat` (the template for the deployed launcher)
    - Launch `autopilot_watchdog.ps1` in a new PowerShell window with `-ExecutionPolicy Bypass`
    - Reference the correct deployed path `%USERPROFILE%\.copilot\autopilot_watchdog.ps1`
    - _Requirements: 4.9_

  - [ ]* 8.2 Write unit test: Launcher contains correct invocation
    - Read the launcher bat content; assert it contains `-ExecutionPolicy Bypass` and the correct `.ps1` path
    - File: `tests\test_settings_writer.py`

- [ ] 9. Implement VS Code entry script
  - [ ] 9.1 Write `enable_vscode_autopilot.bat`
    - `setlocal enabledelayedexpansion`; check exit codes after each major step
    - Locate `settings.json` (stable path preferred; create if absent)
    - Write `%TEMP%\autopilot_setup.py` from embedded heredoc; invoke Python; fall back to `settings_writer_fallback.ps1` if Python unavailable
    - Print per-key summary table (ADDED / UPDATED / ALREADY CORRECT)
    - Create `%USERPROFILE%\.copilot\agents\` directory; write `autopilot-persistent.agent.md` (overwrite if exists)
    - Write `%USERPROFILE%\.copilot\autopilot_watchdog.ps1` (overwrite if exists)
    - Write `%USERPROFILE%\.copilot\Start-Autopilot-Watchdog.bat` (overwrite if exists)
    - Check `code --list-extensions` for `GitHub.copilot`; print INSTALLED or NOT FOUND
    - Print free-tier guidance (2,000 suggestions / 50 premium requests / agent mode on free tier)
    - Print Continue extension alternative note with commented-out settings block
    - Print final summary: files created/modified, files failed with reason, next steps
    - Exit code 0 on success, non-zero on any unrecoverable error
    - _Requirements: 1.1–1.8, 2.1–2.6, 3.1–3.4, 4.1, 4.9, 8.1–8.2, 8.6, 9.1, 9.3, 9.4, 9.5_

  - [ ]* 9.2 Write unit tests for VS Code entry script behavior
    - Agent file overwritten without prompt (pre-create with different content; verify new content after run)
    - Copilot extension installed → INSTALLED status line present
    - Copilot extension not installed → installation instructions printed
    - File: `tests\test_settings_writer.py`

- [ ] 10. Implement Kiro steering file content
  - [-] 10.1 Write `kiro_steering_file_content.md` (the template for `autopilot-persistent.md`)
    - YAML front-matter: `inclusion: always`
    - Body: Autopilot_Mode directive, never-pause directive, auto-retry protocol (5 retries, 3-second delay), sequential task queue processing
    - Encode UTF-8
    - _Requirements: 6.2, 6.3, 6.4, 6.5, 6.6_

- [ ] 11. Implement Kiro watchdog script
  - [ ] 11.1 Write `kiro_autopilot_watchdog.ps1` (the template embedded in the Kiro bat script)
    - Structurally identical to the VS Code watchdog; monitor `Kiro.exe` instead of `Code.exe`
    - Deploy target: `%USERPROFILE%\.kiro\autopilot_watchdog.ps1`
    - All configurable parameters, halt detection, resume signal, logging, and timeout logic identical to VS Code watchdog
    - _Requirements: 7.1, 7.2, 7.3, 7.4, 7.5, 7.6, 7.7, 7.8, 8.4, 8.5_

- [ ] 12. Implement Kiro watchdog launcher
  - [ ] 12.1 Write `kiro_Start-Autopilot-Watchdog.bat` (the template for the deployed Kiro launcher)
    - Launch `autopilot_watchdog.ps1` in a new PowerShell window with `-ExecutionPolicy Bypass`
    - Reference the correct deployed path `%USERPROFILE%\.kiro\autopilot_watchdog.ps1`
    - _Requirements: 7.9_

- [ ] 13. Implement Kiro entry script
  - [ ] 13.1 Write `enable_kiro_autopilot.bat`
    - `setlocal enabledelayedexpansion`; check exit codes after each major step
    - Locate `cli.json` at `%USERPROFILE%\.kiro\settings\cli.json`; create full directory path and file if absent
    - Write `%TEMP%\autopilot_setup.py` from embedded heredoc; invoke Python; fall back to PowerShell if Python unavailable
    - Print per-key summary table (ADDED / UPDATED / ALREADY CORRECT) for `autoApprove` and `supervisedMode`
    - Create `%USERPROFILE%\.kiro\steering\` directory; write `autopilot-persistent.md` encoded UTF-8 (overwrite if exists)
    - Write `%USERPROFILE%\.kiro\autopilot_watchdog.ps1` (overwrite if exists)
    - Write `%USERPROFILE%\.kiro\Start-Autopilot-Watchdog.bat` (overwrite if exists)
    - Print final summary: files created/modified, files failed with reason, next steps
    - Exit code 0 on success, non-zero on any unrecoverable error
    - _Requirements: 5.1–5.7, 6.1–6.7, 7.1, 7.9, 8.1–8.2, 8.6, 9.2, 9.3, 9.4, 9.5_

  - [ ]* 13.2 Write unit tests for Kiro entry script behavior
    - Steering file overwritten without prompt (pre-create with different content; verify new content after run)
    - File: `tests\test_settings_writer.py`

- [ ] 14. Implement VS Code path resolution property test
  - [ ] 14.1 Write property test: VS Code path resolution priority (Property 4)
    - **Property 4: VS Code path resolution priority**
    - **Validates: Requirements 1.1, 1.2**
    - Enumerate all 4 combinations of stable/insiders path existence; assert stable selected when present, insiders when only it exists, stable created when neither exists
    - File: `tests\test_settings_writer.py`

- [ ] 15. Implement integration and smoke tests
  - [ ] 15.1 Write `tests\test_integration.ps1` (Pester integration tests against sandboxed filesystem)
    - Full VS Code script execution on a clean system (no `settings.json`)
    - Full VS Code script execution on a system with existing `settings.json`
    - Full Kiro script execution on a clean system
    - Full Kiro script execution on a system with existing `cli.json`
    - Re-run of each script verifies idempotency (all ALREADY CORRECT / UP TO DATE)
    - _Requirements: 9.1–9.5, design §7.4_

- [ ] 16. Final checkpoint — Ensure all tests pass
  - Run `pytest tests\ -v` and `Invoke-Pester tests\test_integration.ps1 -Output Detailed`
  - Fix any failures; verify all scripts are present in the project root with correct content.

---

## Notes

- Tasks marked with `*` are optional and can be skipped for a faster MVP
- Each task references specific requirements for traceability
- Checkpoints ensure incremental validation at logical boundaries
- Property tests (Properties 1–8) validate universal correctness guarantees; unit tests validate specific examples and edge cases
- The Python `settings_writer.py` is both a standalone module (importable by tests) and the source for the heredoc embedded in each bat script
- `vscode_autopilot_watchdog.ps1` and `kiro_autopilot_watchdog.ps1` are standalone template files; the bat scripts embed their content as heredocs at deploy time
- All output files (`.bat`, `.ps1`, `.md`, `.py`) are created in the project root; tests live in `tests\`

## Task Dependency Graph

```json
{
  "waves": [
    { "id": 0, "tasks": ["1.1"] },
    { "id": 1, "tasks": ["2.1", "4.1", "5.1", "10.1"] },
    { "id": 2, "tasks": ["2.2", "2.3", "2.4", "2.5", "2.6", "4.2", "14.1"] },
    { "id": 3, "tasks": ["6.1", "8.1", "11.1", "12.1"] },
    { "id": 4, "tasks": ["6.2", "6.3", "6.4", "6.5", "8.2"] },
    { "id": 5, "tasks": ["9.1", "13.1"] },
    { "id": 6, "tasks": ["9.2", "13.2", "15.1"] }
  ]
}
```
