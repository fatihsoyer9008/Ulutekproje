import os

import pytest

_REQUIRED_VALUES = frozenset({"1", "true", "yes"})


def postgres_test_database_url() -> str:
    database_url = os.getenv("POSTGRES_TEST_DATABASE_URL")
    require_postgres = (
        os.getenv("REQUIRE_POSTGRES_TESTS", "").strip().casefold() in _REQUIRED_VALUES
    )

    if not database_url:
        if require_postgres:
            pytest.fail(
                "POSTGRES_TEST_DATABASE_URL is required when "
                "REQUIRE_POSTGRES_TESTS is enabled"
            )
        pytest.skip("POSTGRES_TEST_DATABASE_URL is required for PostgreSQL tests")

    if not database_url.startswith("postgresql+asyncpg://"):
        pytest.fail("POSTGRES_TEST_DATABASE_URL must use PostgreSQL with asyncpg")

    return database_url
