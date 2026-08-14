"""Classify pull-request diffs and produce a token-efficient review input.

The script deliberately uses only the Python standard library so it can run in
GitHub Actions without installing project dependencies.
"""

from __future__ import annotations

import argparse
import subprocess
from dataclasses import dataclass
from pathlib import Path

SMALL_MAX = 150
MEDIUM_MAX = 600

IGNORED_SUFFIXES = (
    ".g.dart",
    ".freezed.dart",
    ".lock",
    ".png",
    ".jpg",
    ".jpeg",
    ".svg",
    ".webp",
    ".json",
    ".md",
)
IGNORED_PATH_PARTS = (
    "/generated/",
    "/build/",
    "/assets/",
)

# A critical path is always retained, even if its extension would normally be
# filtered. This prevents contracts and security configuration from being
# hidden merely because they use Markdown or JSON.
CRITICAL_KEYWORDS = (
    "auth",
    "alembic",
    "migration",
    "security",
    "finance",
    "payment",
    "settlement",
    "debt",
    "rate_limit",
    "workflow",
    "docker-compose",
    "api_contract",
)


@dataclass(frozen=True)
class DiffEntry:
    added: int | None
    deleted: int | None
    filename: str

    @property
    def changed_lines(self) -> int:
        if self.added is None or self.deleted is None:
            return 0
        return self.added + self.deleted


def _run_git(*args: str) -> str:
    result = subprocess.run(
        ["git", *args],
        capture_output=True,
        text=True,
        encoding="utf-8",
        errors="replace",
        check=False,
    )
    if result.returncode != 0:
        message = result.stderr.strip() or "Bilinmeyen Git hatası"
        raise RuntimeError(message)
    return result.stdout


def get_git_diff_stats(base_ref: str, head_ref: str) -> list[DiffEntry]:
    output = _run_git("diff", f"{base_ref}...{head_ref}", "--numstat")
    entries: list[DiffEntry] = []
    for line in output.splitlines():
        parts = line.split("\t", maxsplit=2)
        if len(parts) != 3:
            continue
        added, deleted, filename = parts
        entries.append(
            DiffEntry(
                added=None if added == "-" else int(added),
                deleted=None if deleted == "-" else int(deleted),
                filename=filename,
            )
        )
    return entries


def critical_triggers(filename: str) -> tuple[str, ...]:
    normalized = filename.replace("\\", "/").lower()
    return tuple(keyword for keyword in CRITICAL_KEYWORDS if keyword in normalized)


def should_ignore(filename: str) -> bool:
    normalized = f"/{filename.replace('\\', '/').lower().lstrip('/')}"
    if critical_triggers(normalized):
        return False
    if normalized.endswith(IGNORED_SUFFIXES):
        return True
    return any(part in normalized for part in IGNORED_PATH_PARTS)


def generate_filtered_diff(
    base_ref: str,
    head_ref: str,
    valid_files: list[str],
    output_path: Path,
) -> None:
    output_path.parent.mkdir(parents=True, exist_ok=True)
    if not valid_files:
        output_path.write_text("", encoding="utf-8")
        return

    diff = _run_git(
        "diff",
        f"{base_ref}...{head_ref}",
        "--no-ext-diff",
        "--unified=3",
        "--",
        *valid_files,
    )
    output_path.write_text(diff, encoding="utf-8", newline="\n")


def evaluate_pr(base_ref: str, head_ref: str, output_path: Path) -> str:
    entries = get_git_diff_stats(base_ref, head_ref)
    valid_entries = [entry for entry in entries if not should_ignore(entry.filename)]
    valid_files = list(dict.fromkeys(entry.filename for entry in valid_entries))
    generate_filtered_diff(base_ref, head_ref, valid_files, output_path)

    meaningful_lines = sum(entry.changed_lines for entry in valid_entries)
    triggers = sorted(
        {
            trigger
            for entry in valid_entries
            for trigger in critical_triggers(entry.filename)
        }
    )

    lines = [
        "<!-- AI_PR_ROUTER -->",
        "## AI PR inceleme yönlendirmesi",
        "",
        f"- Anlamlı değişiklik: `{meaningful_lines} satır`",
        f"- İncelenecek dosya: `{len(valid_files)}`",
        "- Generated, lock ve görsel asset dosyaları filtrelendi.",
    ]
    if triggers:
        lines.append(f"- Kritik alanlar: `{', '.join(triggers)}`")

    lines.extend(["", "---", ""])
    if triggers:
        lines.extend(
            [
                "### Karar: Derin inceleme",
                (
                    "Kritik auth, güvenlik, migration veya finansal mantık "
                    "değişikliği bulundu."
                ),
            ]
        )
    elif meaningful_lines > MEDIUM_MAX:
        lines.extend(
            [
                "### Karar: Derin inceleme",
                f"Değişiklik büyük: `{meaningful_lines} satır`.",
            ]
        )
    elif meaningful_lines > SMALL_MAX:
        lines.extend(
            [
                "### Karar: Aşamalı inceleme",
                (
                    "Önce hızlı modelle özet çıkarın; riskli bölümleri derin "
                    "incelemeye aktarın."
                ),
            ]
        )
    else:
        lines.extend(
            [
                "### Karar: Hızlı inceleme",
                f"Değişiklik küçük: `{meaningful_lines} satır`.",
            ]
        )

    lines.extend(
        [
            "",
            (
                "Token tasarrufu için incelemede workflow artifact'i içindeki "
                "`filtered_diff.txt` dosyasını kullanın."
            ),
        ]
    )
    return "\n".join(lines)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="PR diff'ini sınıflandır ve filtrelenmiş diff üret."
    )
    parser.add_argument("base_ref")
    parser.add_argument("head_ref")
    parser.add_argument(
        "--output",
        type=Path,
        default=Path("filtered_diff.txt"),
        help="Filtrelenmiş diff çıktı yolu.",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    try:
        print(evaluate_pr(args.base_ref, args.head_ref, args.output))
    except (OSError, RuntimeError, ValueError) as error:
        print(f"PR diff'i değerlendirilemedi: {error}")
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
