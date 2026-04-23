#!/usr/bin/env python3
# /// script
# requires-python = ">=3.12"
# dependencies = ["rich>=13,<15"]
# ///
"""
Upgrades all packages via `uv sync --upgrade`, then rewrites the >= lower
bounds in pyproject.toml to match the resolved versions in uv.lock.

Covers:
  - [project.dependencies]
  - [project.optional-dependencies.*]
  - [dependency-groups.*]

Usage:
    uv run uv-upgrade.py
"""

import re
import shutil
import subprocess
import sys
import time
from pathlib import Path

from rich import box
from rich.console import Console
from rich.panel import Panel
from rich.table import Table

console = Console()


def parse_lock_versions(lock_path: Path, /) -> dict[str, str]:
    resolved: dict[str, str] = {}
    for m in re.finditer(
        r'^name = "(.+?)"\nversion = "(.+?)"',
        lock_path.read_text(),
        re.MULTILINE,
    ):
        resolved[m.group(1).lower()] = m.group(2)
    return resolved


def update_lower_bounds(
    toml_text: str,
    resolved: dict[str, str],
) -> list[tuple[int, str, str, str, str, str]]:
    """Returns (line_number, package, old_version, new_version, old_line, new_line) tuples."""
    changes: list[tuple[int, str, str, str, str, str]] = []

    lines = toml_text.splitlines()
    new_lines = []

    for i, line in enumerate(lines):
        new_line = line
        for m in re.finditer(
            r'"([A-Za-z0-9_.-]+(?:\[[^\]]+\])?)(>=[\d.,<>=!^ ]+)"', line
        ):
            pkg_raw = m.group(1)
            constraint = m.group(2)
            version = resolved.get(pkg_raw.lower())
            if not version:
                continue
            old_ver_match = re.search(r">=(\d[\d.]*)", constraint)
            if not old_ver_match or old_ver_match.group(1) == version:
                continue
            old_ver = old_ver_match.group(1)
            new_constraint = re.sub(r">=[\d.]+", f">={version}", constraint)
            new_line = new_line.replace(
                f'"{pkg_raw}{constraint}"',
                f'"{pkg_raw}{new_constraint}"',
            )
            changes.append(
                (i + 1, pkg_raw, old_ver, version, line.strip(), new_line.strip())
            )
        new_lines.append(new_line)

    return changes, "\n".join(new_lines) + "\n" if toml_text.endswith(
        "\n"
    ) else "\n".join(new_lines)


def main() -> None:
    console.print()
    console.rule("[bold cyan]uv upgrade[/bold cyan]", style="cyan")
    console.print()

    # ── Preflight ─────────────────────────────────────────────────────────
    if not shutil.which("uv"):
        console.print("[red bold]✗[/red bold] uv not found on PATH. Install it first.")
        sys.exit(1)

    root = Path.cwd()
    toml_path = root / "pyproject.toml"
    lock_path = root / "uv.lock"

    if not toml_path.exists():
        console.print(
            f"[red bold]✗[/red bold] No pyproject.toml found in [dim]{root}[/dim]"
        )
        sys.exit(1)

    console.print(f"  [bold]Project:[/bold]  [dim]{root}[/dim]")
    console.print(f"  [bold]Config:[/bold]   [dim]{toml_path}[/dim]")
    console.print()

    # ── Run uv sync --upgrade ─────────────────────────────────────────────
    with console.status(
        "[bold cyan]Running uv sync --upgrade --all-extras --all-groups ...[/bold cyan]"
    ):
        t0 = time.monotonic()
        result = subprocess.run(
            ["uv", "sync", "--upgrade", "--all-extras", "--all-groups"],
            cwd=root,
            stdin=subprocess.DEVNULL,
            capture_output=True,
            text=True,
        )
        elapsed = time.monotonic() - t0

    if result.returncode != 0:
        console.print(
            f"[red bold]✗ uv sync failed[/red bold] (exit code {result.returncode})"
        )
        if result.stderr.strip():
            console.print(
                Panel(
                    result.stderr.strip(),
                    title="[red]stderr[/red]",
                    border_style="red",
                    box=box.ROUNDED,
                )
            )
        sys.exit(result.returncode)

    console.print(
        f"  [green bold]✓[/green bold] uv sync completed in [bold]{elapsed:.1f}s[/bold]"
    )

    # ── Parse lock and update bounds ──────────────────────────────────────
    if not lock_path.exists():
        console.print("[yellow]  ⚠ No uv.lock found — skipping version bump[/yellow]")
        return

    resolved = parse_lock_versions(lock_path)
    console.print(f"  [dim]{len(resolved)} packages resolved in lockfile[/dim]")

    original = toml_path.read_text()
    changes, updated = update_lower_bounds(original, resolved)

    if not changes:
        console.print()
        console.print(
            Panel(
                "[green]All lower bounds already match the resolved versions.[/green]",
                title="[bold cyan]No changes needed[/bold cyan]",
                border_style="green",
                box=box.ROUNDED,
                padding=(0, 2),
            )
        )
        console.print()
        return

    # ── Write and show diff ───────────────────────────────────────────────
    toml_path.write_text(updated)

    table = Table(
        box=box.SIMPLE_HEAVY,
        show_header=True,
        header_style="bold cyan",
        padding=(0, 1),
        title=f"[bold]{len(changes)} version bound{'s' if len(changes) != 1 else ''} updated[/bold]",
        title_style="",
    )
    table.add_column("Line", style="dim", no_wrap=True, width=5)
    table.add_column("Package", style="bold white", no_wrap=True)
    table.add_column("Old", style="red", no_wrap=True)
    table.add_column("", style="dim", no_wrap=True, width=2)
    table.add_column("New", style="green bold", no_wrap=True)

    for line_no, pkg, old_ver, new_ver, _, _ in changes:
        table.add_row(str(line_no), pkg, f">={old_ver}", "→", f">={new_ver}")

    console.print()
    console.print(table)
    console.print()
    console.print(f"  [green bold]✓[/green bold] Updated [bold]{toml_path.name}[/bold]")
    console.print(
        "  [dim]Run [bold]uv sync[/bold] again if needed to lock the changes.[/dim]"
    )
    console.print()


if __name__ == "__main__":
    main()
