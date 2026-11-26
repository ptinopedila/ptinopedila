#!/usr/bin/env python3
"""Offline checks through the baked ujust entry point; never change host policy."""
from __future__ import annotations
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import sys

if len(sys.argv) > 1:
    source = Path(sys.argv[1])
    # Compare the files Flatpak and Homebrew read, including inherited defaults
    # that would be invisible to the downstream package-audit manifest.
    for directory, pattern, profiles in [
        ('usr/share/flatpak/preinstall.d', '*.preinstall', ('shared', 'home')),
        ('usr/share/ublue-os/homebrew/preinstall.d', '*.Brewfile', ('shared',)),
    ]:
        expected = {p.name: p.read_bytes() for profile in profiles
                    for p in (source / 'files' / profile / directory).glob(pattern)}
        actual = {p.name: p.read_bytes() for p in (Path('/') / directory).glob(pattern)}
        assert actual == expected, f'Application defaults differ from Home: {directory}'
    for path in (source / 'files/shared/usr/libexec/ptinopedila').iterdir():
        if path.is_file():
            installed = Path('/usr/libexec/ptinopedila') / path.name
            assert installed.read_bytes() == path.read_bytes(), f'Baked helper differs: {path.name}'
    assert Path('/usr/share/ublue-os/just/90-ptinopedila.just').read_bytes() == (source / 'files/shared/usr/share/ublue-os/just/60-custom.just').read_bytes()
    assert Path('/usr/share/ublue-os/just/91-ptinopedila-report.just').read_bytes() == (source / 'files/shared/usr/share/ublue-os/just/60-bonedigger.just').read_bytes()
    sysctl_source = source / 'files/secureblue/usr/etc/sysctl.d/hardening.conf'
    assert Path('/etc/sysctl.d/hardening.conf').read_bytes() == sysctl_source.read_bytes(), 'Stale sysctl configuration in baked image'
    print('PASS baked production helper and recipe byte comparison')

for recipe, action in [('setup-vms', 'setup'), ('toggle-vms', 'toggle')]:
    definition = subprocess.check_output(['ujust', '--show', recipe], text=True)
    assert f'/usr/libexec/ptinopedila/manage-vm-flatpaks {action}' in definition, definition

def run_checked(*arguments, **keywords):
    try:
        return subprocess.run(*arguments, **keywords)
    except subprocess.CalledProcessError as error:
        print(error.stdout or '', file=sys.stderr)
        print(error.stderr or '', file=sys.stderr)
        raise

with tempfile.TemporaryDirectory(prefix='ptinopedila-workstation-check-') as directory:
    root = Path(directory)
    bin_directory = root / 'bin'
    bin_directory.mkdir()
    log = root / 'calls.jsonl'
    capture = bin_directory / 'capture'
    capture.write_text('''#!/usr/bin/python3
import json,os,sys
with open(os.environ['PTINOPEDILA_TEST_LOG'],'a') as output:
    output.write(json.dumps(sys.argv[1:])+'\\n')
''')
    capture.chmod(0o755)
    environment = dict(os.environ, PTINOPEDILA_TEST_LOG=str(log))
    # Override only the invoked backend. Keep the real baked ujust and Justfile.
    cases = [
        ('install-dotfiles', ['--github', 'user', 'repo'], 'DOTFILES_INSTALLER', ['--github', 'user', 'repo']),
        ('install-conda', ['anaconda'], 'CONDA_INSTALLER', ['--distribution', 'anaconda']),
        ('install-dynare', [], 'DYNARE_INSTALLER', []),
        ('install-deepseek-codex', ['--uninstall'], 'DEEPSEEK_CODEX_INSTALLER', ['--uninstall']),
        ('deepseek-codex-desktop', ['off'], 'DEEPSEEK_CODEX_INSTALLER', ['--desktop', 'off']),
        ('install-r-vscode', [], 'R_VSCODE_INSTALLER', []),
        ('install-r-workbench', ['--accept-positron-license'], 'R_WORKBENCH_INSTALLER', ['--accept-positron-license']),
        ('update-r-workbench', ['--accept-positron-license'], 'R_WORKBENCH_INSTALLER', ['--update', '--accept-positron-license']),
        ('install-languagetool', ['--port=8082'], 'LANGUAGETOOL_INSTALLER', ['--port=8082']),
        ('install-word-lookup', ['--copy-skill'], 'WORD_LOOKUP_INSTALLER', ['--copy-skill']),
        ('configure-latex', ['aux space', 'pdf space'], 'LATEX_CONFIGURATOR', ['--aux-dir', 'aux space', '--pdf-dir', 'pdf space']),
        ('configure-vscode-latex', ['--languagetool-port=8082', 'aux space', 'pdf space'], 'VSCODE_LATEX_CONFIGURATOR', ['--aux-dir', 'aux space', '--pdf-dir', 'pdf space', '--languagetool-host', 'localhost', '--languagetool-port', '8082']),
        ('toggle-exitnode', ['disable'], 'EXITNODE_TOGGLER', ['disable']),
        ('toggle-bluetooth-on-boot', [], 'BLUETOOTH_TOGGLER', []),
        ('set-faillock', ['status'], 'FAILLOCK_MANAGER', ['status']),
        ('package-audit', ['--save', '--config=config with spaces', '--csv-dir=csv space'], 'PACKAGE_AUDITOR', ['--save', '--config', 'config with spaces', '--csv-dir', 'csv space']),
        ('report', ['--resume', 'draft space'], 'BONEDIGGER_REPORT', ['--resume', 'draft space']),
    ]
    summary = subprocess.check_output(['ujust', '--summary'], text=True).split()
    required = {row[0] for row in cases} | {'install-ptinopedila-brew', 'toggle-mac-randomization', 'enable-cups', 'disable-cups'}
    assert required <= set(summary), required - set(summary)
    for recipe, arguments, variable, expected in cases:
        log.unlink(missing_ok=True)
        env = dict(environment, **{f'PTINOPEDILA_{variable}': str(capture)})
        run_checked(['ujust', '--yes', recipe, *arguments], env=env, cwd=root, check=True, capture_output=True)
        calls = [json.loads(line) for line in log.read_text().splitlines()]
        assert calls == [expected], (recipe, calls, expected)
        print(f'PASS baked recipe argument forwarding: {recipe}')

    for name in ['sudo', 'brew', 'flatpak']:
        (bin_directory / name).symlink_to(capture)
    environment['PATH'] = f'{bin_directory}:' + os.environ['PATH']
    for recipe in ['install-ptinopedila-brew', 'toggle-mac-randomization', 'enable-cups', 'disable-cups']:
        log.unlink(missing_ok=True)
        run_checked(['ujust', '--yes', recipe], env=environment, cwd=root, check=True, capture_output=True)
        calls = [json.loads(line) for line in log.read_text().splitlines()]
        assert calls, recipe
        if recipe == 'install-ptinopedila-brew':
            bundles = [call for call in calls if call and call[0] == 'bundle']
            assert len(bundles) == 8, bundles
        if recipe == 'toggle-mac-randomization':
            assert calls == [['/usr/libexec/ptinopedila/toggle-mac-randomization']], calls
        print(f'PASS baked recipe backend routing: {recipe}')

    # Run the real comment-preserving YAML mutation using the image interpreter.
    yaml_path = root / 'raffi.yaml'
    yaml_path.write_text('# retained comment\ngeneral:\n  ui_type: native\n')
    run_checked(['/usr/libexec/ptinopedila/configure-word-lookup-raffi', '--config', str(yaml_path)], check=True)
    from ruamel.yaml import YAML
    content = YAML().load(yaml_path.read_text())
    assert content['addons']['script_filters'][0]['keyword'] == 'word'
    assert '# retained comment' in yaml_path.read_text()
    print('PASS real ruamel YAML mutation and comment preservation')

    # Verify the real office wrapper preserves filenames and selects LibreOffice.
    source = root / 'document with spaces.odt'
    source.touch()
    log.unlink(missing_ok=True)
    run_checked(['/usr/bin/office-to-pdf', str(source), str(root)], env=environment, check=True)
    arguments = json.loads(log.read_text())
    assert arguments == ['run', 'org.libreoffice.LibreOffice', '--headless', '--convert-to', 'pdf', '--outdir', str(root), str(source)], arguments
    print('PASS baked office-to-pdf backend and argument routing')

for command in ['bash', 'python3', 'zsh', 'git', 'curl', 'jq', 'flatpak', 'xdg-open', 'realpath', 'pkg-config', 'distrobox', 'podman', 'tailscale', 'firewall-cmd', 'authselect', 'gum']:
    assert shutil.which(command), f'Missing runtime prerequisite: {command}'
print('PASS basic custom-recipe host prerequisites')
