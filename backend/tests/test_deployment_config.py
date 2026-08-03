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


def test_digitalocean_configures_trusted_client_ip_header() -> None:
    app_spec_file = _REPOSITORY_ROOT / ".do" / "app.yaml"
    content = app_spec_file.read_text(encoding="utf-8")

    expected_proxy_settings = (
        '- key: TRUST_PROXY_HEADERS\n        value: "true"',
        "- key: TRUSTED_CLIENT_IP_HEADER\n        value: do-connecting-ip",
        "- key: TRUSTED_PROXY_CIDRS\n        value: 10.0.0.0/8",
    )

    for expected_setting in expected_proxy_settings:
        assert expected_setting in content
