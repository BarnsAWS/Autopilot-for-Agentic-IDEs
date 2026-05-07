"""
settings_writer.py — Settings_Writer component for autopilot-enabler.

Provides merge_settings(settings_path, required_keys) which:
  - Locates the settings file; creates parent directories and file if absent.
  - Creates a .pre-autopilot.bak backup before any write; raises immediately
    (PermissionError / OSError) if the backup fails — does NOT modify the
    original file.
  - Skips backup and raises json.JSONDecodeError if the JSON is malformed;
    logs parse error to stdout.
  - Merges required keys using ADDED / UPDATED / ALREADY CORRECT classification.
  - Preserves all pre-existing keys not in the required set.
  - Returns a change report dict.

CLI entry point (main):
  python settings_writer.py --settings-path <path> --keys '<json>'
  Exits 0 on success, 1 on error.

Requirements: 1.1, 1.2, 1.3, 1.4, 1.5, 1.8, 5.1, 5.2, 5.3, 5.4, 5.5, 5.6,
              8.3, 9.1, 9.2
"""

import argparse
import json
import os
import shutil
import sys


# ---------------------------------------------------------------------------
# Change-classification constants
# ---------------------------------------------------------------------------
ADDED = "ADDED"
UPDATED = "UPDATED"
ALREADY_CORRECT = "ALREADY CORRECT"


def _backup_path(settings_path: str) -> str:
    """Return the canonical backup path for a given settings file path."""
    return settings_path + ".pre-autopilot.bak"


def merge_settings(settings_path: str, required_keys: dict) -> dict:
    """
    Read existing JSON from *settings_path*, merge *required_keys* into it,
    write the result back, and return a change report.

    Parameters
    ----------
    settings_path : str
        Absolute (or relative) path to the JSON settings file.
    required_keys : dict
        Mapping of key → required value to merge into the settings file.

    Returns
    -------
    dict
        Change report: { key: "ADDED" | "UPDATED" | "ALREADY CORRECT" }

    Raises
    ------
    json.JSONDecodeError
        When the settings file contains malformed JSON. A parse error is
        printed to stdout before raising. No backup is created.
    PermissionError / OSError
        When the backup cannot be created (raised immediately; original file
        is not modified). Also propagated if the final write fails.
    """
    settings_path = os.path.abspath(settings_path)
    bak_path = _backup_path(settings_path)

    # ------------------------------------------------------------------
    # 1. Locate / create the settings file (requirements 1.2, 5.2)
    # ------------------------------------------------------------------
    if not os.path.exists(settings_path):
        parent_dir = os.path.dirname(settings_path)
        if parent_dir:
            os.makedirs(parent_dir, exist_ok=True)
        # Write an empty JSON object so the file exists and is valid.
        with open(settings_path, "w", encoding="utf-8") as fh:
            fh.write("{}\n")

    # ------------------------------------------------------------------
    # 2. Read and parse existing JSON (requirements 1.8, 5.6, 8.3)
    #    Malformed JSON: log error, do NOT create backup, raise.
    # ------------------------------------------------------------------
    with open(settings_path, "r", encoding="utf-8") as fh:
        raw = fh.read()

    stripped = raw.strip()
    if stripped == "" or stripped == "{}":
        existing_settings: dict = {}
    else:
        try:
            existing_settings = json.loads(raw)
        except json.JSONDecodeError as exc:
            # Log parse error to stdout, do NOT create backup, raise.
            print(
                f"[settings_writer] ERROR: Malformed JSON in '{settings_path}': {exc}",
                file=sys.stdout,
            )
            raise

        if not isinstance(existing_settings, dict):
            # Treat a non-object root as a parse-level error.
            msg = (
                f"[settings_writer] ERROR: Expected a JSON object in "
                f"'{settings_path}', got {type(existing_settings).__name__}."
            )
            print(msg, file=sys.stdout)
            raise json.JSONDecodeError(msg, raw, 0)

    # ------------------------------------------------------------------
    # 3. Create backup before any write (requirements 1.3, 5.3)
    #    If backup fails, raise immediately — do NOT modify original.
    # ------------------------------------------------------------------
    try:
        shutil.copy2(settings_path, bak_path)
    except (PermissionError, OSError):
        # Re-raise so the caller / CLI layer can handle it.
        raise

    # ------------------------------------------------------------------
    # 4. Classify changes and build merged settings (requirements 1.4, 1.5,
    #    5.4, 5.5, 9.1, 9.2)
    # ------------------------------------------------------------------
    change_report: dict = {}
    merged = dict(existing_settings)  # shallow copy — preserves all existing keys

    for key, required_value in required_keys.items():
        if key not in existing_settings:
            change_report[key] = ADDED
        elif existing_settings[key] != required_value:
            change_report[key] = UPDATED
        else:
            change_report[key] = ALREADY_CORRECT

        merged[key] = required_value  # upsert

    # ------------------------------------------------------------------
    # 5. Write merged settings back (only if something changed)
    # ------------------------------------------------------------------
    needs_write = any(v != ALREADY_CORRECT for v in change_report.values())

    if needs_write:
        with open(settings_path, "w", encoding="utf-8") as fh:
            json.dump(merged, fh, indent=4, ensure_ascii=False)
            fh.write("\n")

    return change_report


# ---------------------------------------------------------------------------
# CLI entry point
# ---------------------------------------------------------------------------
def main() -> None:
    """
    Command-line interface for the bat script invocation.

    Usage:
        python settings_writer.py --settings-path <path> --keys '<json>'

    Prints one line per key: "  KEY_NAME: STATUS"
    Exits 0 on success, 1 on any error.
    """
    parser = argparse.ArgumentParser(
        description="Merge required keys into a JSON settings file."
    )
    parser.add_argument(
        "--settings-path",
        required=True,
        help="Path to the JSON settings file to update.",
    )
    parser.add_argument(
        "--keys",
        required=True,
        help="JSON string mapping required keys to their required values.",
    )
    args = parser.parse_args()

    try:
        required_keys = json.loads(args.keys)
    except json.JSONDecodeError as exc:
        print(f"[settings_writer] ERROR: Invalid --keys JSON: {exc}")
        sys.exit(1)

    if not isinstance(required_keys, dict):
        print("[settings_writer] ERROR: --keys must be a JSON object.")
        sys.exit(1)

    try:
        report = merge_settings(args.settings_path, required_keys)
    except json.JSONDecodeError:
        # Error already printed inside merge_settings.
        sys.exit(1)
    except (PermissionError, OSError) as exc:
        print(f"[settings_writer] ERROR: {exc}")
        sys.exit(1)

    for key, status in report.items():
        print(f"  {key}: {status}")


if __name__ == "__main__":
    main()
