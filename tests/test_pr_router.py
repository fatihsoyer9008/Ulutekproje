"""Regression tests for the dependency-free PR review router."""

from __future__ import annotations

import unittest
from pathlib import Path
from unittest.mock import patch

import pr_router


class NumstatParsingTests(unittest.TestCase):
    def test_rename_contains_real_old_and_new_paths(self) -> None:
        entries = pr_router.parse_numstat_z(
            b"4\t4\t\x00old/file.py\x00new/file.py\x00"
        )

        self.assertEqual(entries[0].filenames, ("old/file.py", "new/file.py"))
        self.assertEqual(entries[0].filename, "new/file.py")
        self.assertEqual(entries[0].changed_lines, 8)

    def test_normal_numstat_record_is_preserved(self) -> None:
        entries = pr_router.parse_numstat_z(b"3\t1\tbackend/app/main.py\x00")
        self.assertEqual(entries[0].filenames, ("backend/app/main.py",))


class FilteringTests(unittest.TestCase):
    def test_api_contract_json_files_are_not_filtered(self) -> None:
        for filename in (
            "openapi.json",
            "swagger.json",
            "api/schema.json",
            "contracts/schema.json",
        ):
            with self.subTest(filename=filename):
                self.assertFalse(pr_router.should_ignore(filename))

    def test_only_narrow_generated_and_lock_json_patterns_are_filtered(self) -> None:
        for filename in (
            "package-lock.json",
            "lib/generated/models.g.json",
            "generated/schema.generated.json",
        ):
            with self.subTest(filename=filename):
                self.assertTrue(pr_router.should_ignore(filename))
        self.assertFalse(pr_router.should_ignore("fixtures/response.json"))

    def test_rename_from_ignored_to_contract_path_is_reviewable(self) -> None:
        entry = pr_router.DiffEntry(
            added=2,
            deleted=2,
            filenames=("build/generated.g.json", "contracts/schema.json"),
        )
        self.assertTrue(any(not pr_router.should_ignore(path) for path in entry.filenames))


class RouterIntegrationTests(unittest.TestCase):
    def test_content_changing_critical_migration_rename_keeps_both_paths(self) -> None:
        renamed_migration = (
            b"4\t4\t\x00"
            b"backend/alembic/versions/old_migration.py\x00"
            b"backend/alembic/versions/new_migration.py\x00"
        )
        with (
            patch("pr_router._run_git_bytes", return_value=renamed_migration),
            patch("pr_router.generate_filtered_diff") as generate_diff,
        ):
            result = pr_router.evaluate_pr("base", "head", output_path=Path("ignored"))

        self.assertEqual(
            generate_diff.call_args.args[2],
            [
                "backend/alembic/versions/old_migration.py",
                "backend/alembic/versions/new_migration.py",
            ],
        )
        self.assertIn("migration", result)
