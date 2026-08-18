from pathlib import Path

_REPOSITORY_ROOT = Path(__file__).resolve().parents[2]

_RUNTIME_CONFIG_FILES = (
    _REPOSITORY_ROOT / "backend" / "Dockerfile",
    _REPOSITORY_ROOT / "docker-compose.yml",
    _REPOSITORY_ROOT / "docker-compose.prod.yml",
)


def test_uvicorn_runtime_commands_disable_proxy_header_processing() -> None:
    for config_file in _RUNTIME_CONFIG_FILES:
        content = config_file.read_text(encoding="utf-8")

        assert (
            "--no-proxy-headers" in content
        ), f"{config_file} must disable Uvicorn proxy-header processing"


def test_production_compose_binds_ports_to_loopback_only() -> None:
    content = (_REPOSITORY_ROOT / "docker-compose.prod.yml").read_text(
        encoding="utf-8"
    )

    expected_bindings = (
        '"127.0.0.1:${POSTGRES_PORT:-5432}:5432"',
        '"127.0.0.1:${REDIS_PORT:-6379}:6379"',
        '"127.0.0.1:8000:8000"',
    )
    for binding in expected_bindings:
        assert binding in content, (
            f"docker-compose.prod.yml must contain the loopback binding {binding}"
        )


def test_api_service_declares_a_healthcheck() -> None:
    for config_file in ("docker-compose.yml", "docker-compose.prod.yml"):
        content = (_REPOSITORY_ROOT / config_file).read_text(encoding="utf-8")
        api_block = content.split("\n  api:", 1)[1]

        assert "healthcheck:" in api_block, (
            f"{config_file} api service must declare a healthcheck"
        )
        assert "/health" in api_block, (
            f"{config_file} api healthcheck must probe the /health endpoint"
        )
