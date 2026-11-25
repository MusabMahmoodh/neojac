impl resolve_cli_version -> str {
    return os.environ.get("JAC_VERSION", "0.39.1");
}
