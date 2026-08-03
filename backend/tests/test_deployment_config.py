from pathlib import Path

_REPOSITORY_ROOT = Path(__file__).resolve().parents[2]

_RUNTIME_CONFIG_FILES = (
    _REPOSITORY_ROOT / "backend" / "Dockerfile",
    _REPOSITORY_ROOT / "docker-compose.yml",
    _REPOSITORY_ROOT / ".do" / "app.yaml",
)


def test_uvicorn_runtime_commands_disable_proxy_header_processing() -> None:
    for config_file in _RUNTIME_CONFIG_FILES:
        content = config_file.read_text(encoding="utf-8")

        assert (
            "--no-proxy-headers" in content
        ), f"{config_file} must disable Uvicorn proxy-header processing"
