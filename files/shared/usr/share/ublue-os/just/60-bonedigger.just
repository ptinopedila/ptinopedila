# vim: set ft=make :

# bonedigger version v0.2.0
BONEDIGGER_VERSION := "v0.2.0"

export BONEDIGGER_BRAND := "ptinopedila Bug Report"
export BONEDIGGER_ISSUE_URL := "https://github.com/ptinopedila/ptinopedila/issues/new"
export BONEDIGGER_FEATURE_URL := "https://github.com/ptinopedila/ptinopedila/issues/new"

# Collect a previewed, privacy-respecting report and create an issue directly with gh.
[group('System')]
report *args:
    BONEDIGGER_VERSION="{{ BONEDIGGER_VERSION }}" \
    BONEDIGGER_BRAND="${BONEDIGGER_BRAND}" \
    BONEDIGGER_ISSUE_URL="${BONEDIGGER_ISSUE_URL}" \
    BONEDIGGER_FEATURE_URL="${BONEDIGGER_FEATURE_URL}" \
    /usr/libexec/bonedigger-report {{ args }}
