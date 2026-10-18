"""Exercise the real installer/chezmoi with isolated HOME and mocked system commands.
Run: python3 -m unittest discover -s tests -v
No packages, locale, live desktop, or login shell are changed.
"""
import json
import os
from pathlib import Path
import pty
import select
import shutil
import shlex
import sys
import subprocess
import tempfile
import time
import unittest

REPO = Path(__file__).resolve().parents[1]
CHEZMOI = shutil.which('chezmoi')
SWITCHES = 'settings packages omarchy personalize japanese bar hyprland cli neovim ghostty files aur latex rclone change-shell downloads fonts mozkey rustup vscode wezterm mime cloud-mounts linger neovim-latest'.split()


class InstallerTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.home = self.root/'home'
        self.home.mkdir()
        self.bin = self.root/'bin'
        self.bin.mkdir()
        self.log = self.root/'commands.log'
        self.omarchy = self.root/'omarchy'
        self.omarchy.mkdir()
        self.env = dict(os.environ, HOME=str(self.home),
                        XDG_CONFIG_HOME=str(self.home/'.config'),
                        XDG_STATE_HOME=str(self.home/'.local/state'),
                        XDG_CACHE_HOME=str(self.home/'.cache'),
                        OMARCHY_PATH=str(self.omarchy),
                        PATH=f'{self.bin}:/usr/bin:/bin',
                        TEST_LOG=str(self.log), TEST_INSTALLED='',
                        GIT_CONFIG_GLOBAL='/dev/null',
                        DOTFILES_PROFILE='')
        (self.bin/'chezmoi').symlink_to(CHEZMOI)
        self.env['TEST_AVAILABLE'] = ''
        self.mock('pacman', 'if [[ $1 == -Q ]]; then [[ " $TEST_INSTALLED " == *" $2 "* ]]; exit; fi\nif [[ $1 == -Si ]]; then [[ " $TEST_AVAILABLE " == *" $2 "* ]]; exit; fi\nprintf "pacman %s\\n" "$*" >> "$TEST_LOG"')
        real_python = shlex.quote(sys.executable)
        self.mock('python3', 'if [[ ${1:-} == */scripts/install-extras.py ]]; then printf "extra %s\\n" "$2" >> "$TEST_LOG"; exit "${TEST_EXTRA_EXIT:-0}"; fi\nexec '+real_python+' "$@"')
        for name in ('sudo', 'omarchy', 'yay', 'rustup', 'systemctl', 'fc-cache'):
            self.mock(name, f'printf "{name} %s\\n" "$*" >> "$TEST_LOG"')
        # Existing Omarchy apps must not be downloaded/reinstalled.
        for name in ('nvim', 'ghostty', 'cargo'):
            self.mock(name, 'exit 0')

    def mock(self, name, body):
        p = self.bin/name
        p.write_text('#!/bin/bash\nset -eu\n'+body+'\n')
        p.chmod(0o755)

    def options(self, **selected):
        selected.setdefault('settings', True)
        selected.setdefault('packages', True)
        return [('' if selected.get(k.replace('-', '_'), False) else '--no-') +
                (f'--{k}' if selected.get(k.replace('-', '_'), False) else k)
                for k in SWITCHES]

    def run_install(self, *extra, expect=0, **selected):
        p = subprocess.run(['bash', str(REPO/'install.sh'), '--non-interactive',
                            *self.options(**selected), *extra], env=self.env,
                           text=True, capture_output=True, timeout=30)
        self.assertEqual(p.returncode, expect, p.stdout+p.stderr)
        return p

    @property
    def profile(self):
        return self.home/'.config/chezmoi/dotfiles.json'

    def managed(self):
        p = subprocess.run([CHEZMOI, '-S', str(REPO), 'managed', '--include=files,symlinks'],
                           env=self.env, text=True, capture_output=True, check=True)
        return p.stdout.splitlines()

    def test_dry_run_no_profile_no_privileged_commands(self):
        self.run_install('--dry-run', omarchy=True, cli=True, neovim=True, ghostty=True)
        self.assertFalse(self.profile.exists())
        self.assertFalse(self.log.exists())
        self.assertFalse((self.home/'.zshrc').exists())

    def test_unconfigured_source_manages_personal_configuration(self):
        files = self.managed()
        for name in ('.config/hypr/hyprland.lua', '.zshrc', '.config/omarchy/shell.json',
                     '.config/vscode/setting.json', '.config/mimeapps.list'):
            self.assertIn(name, files)
        self.assertNotIn('install.sh', files)
        self.assertNotIn('README.md', files)
        self.assertNotIn('.config/ghostty/config', files)

    def test_normal_defaults_enable_installation_and_sync(self):
        p = subprocess.run(['bash', str(REPO/'install.sh'), '--non-interactive', '--configure-only'],
                           env=self.env, text=True, capture_output=True)
        self.assertEqual(p.returncode, 0, p.stdout+p.stderr)
        data = json.loads(self.profile.read_text())
        for key in ('hyprland', 'cli', 'neovim', 'files', 'japanese',
                    'vscode', 'wezterm', 'mime', 'latex', 'rclone', 'change_shell'):
            self.assertTrue(data[key], key)
        self.assertFalse(data['ghostty'])

    def test_explicit_exclusion_wins_over_default(self):
        p = subprocess.run(['bash', str(REPO/'install.sh'), '--non-interactive', '--configure-only',
                            '--no-hyprland', '--no-fonts'], env=self.env, text=True, capture_output=True)
        self.assertEqual(p.returncode, 0, p.stdout+p.stderr)
        data = json.loads(self.profile.read_text())
        self.assertFalse(data['hyprland'])
        self.assertFalse(data['fonts'])
        self.assertTrue(data['bar'])
        self.assertFalse(any(name.startswith('.config/hypr/') for name in self.managed()))

    def test_group_selection_persists_and_filters_targets(self):
        self.run_install('--configure-only', cli=True)
        self.assertTrue(json.loads(self.profile.read_text())['cli'])
        files = self.managed()
        self.assertIn('.zshrc', files)
        self.assertNotIn('.gitconfig', files)
        self.assertFalse(any(p.startswith('.config/hypr/') for p in files))
        self.assertFalse(any('/.git/' in p for p in files))
        self.assertFalse(any('mozkey-ibg/config1.db' in p for p in files))
        self.assertFalse(self.log.exists())

    def test_all_groups_and_references(self):
        self.run_install('--configure-only', **{k.replace('-', '_'): True for k in SWITCHES})
        files = self.managed()
        for name in ('.config/hypr/bindings.lua', '.config/omarchy/shell.json',
                     '.config/nvim/init.lua', '.config/wezterm/wezterm.lua',
                     '.local/share/applications/Yazi.desktop', '.config/fcitx5/conf/mozkey-ibg.conf'):
            self.assertIn(name, files)
        for name in ('README.md', 'install.sh', '.config/ghostty/config'):
            self.assertNotIn(name, files)
        self.assertFalse(any(p.startswith(('tests/', 'scripts/')) for p in files))
        for name in ('.local/share/fonts/HackGen/LICENSE', '.config/mimeapps.list', '.config/mozkey-ibg/config1.db',
                     '.config/vscode/setting.json', '.config/wezterm/wezterm.lua'):
            self.assertIn(name, files)

    def test_existing_omarchy_apps_skipped_packages_only_missing(self):
        self.env['TEST_INSTALLED'] = 'git eza zsh'
        self.run_install('--git-name', 'A "quoted" User', '--git-email', 'test@example.invalid',
                         omarchy=True, personalize=True, cli=True, neovim=True, ghostty=True)
        log = self.log.read_text()
        self.assertIn('omarchy pkg add', log)
        self.assertNotIn(' neovim', log)
        self.assertNotIn(' ghostty', log)
        self.assertNotIn(' eza ', log)
        self.assertNotIn('brew', log)
        self.assertNotIn('pacman -Sy', log)
        config = (self.home/'.gitconfig').read_text()
        self.assertNotIn('JEEBIS27', config)
        self.assertNotIn('helper = store', config)
        self.assertIn('test@example.invalid', config)
        parsed = subprocess.check_output(['git', 'config', '--file', str(self.home/'.gitconfig'), 'user.name'], text=True)
        self.assertEqual(parsed.strip(), 'A "quoted" User')

    def test_backup_existing_and_record_new_files(self):
        original = '[user]\n name = Old User\n'
        (self.home/'.gitconfig').write_text(original)
        self.run_install('--git-name', 'New User', personalize=True)
        backups = list((self.home/'.local/state/dotfiles/backups').iterdir())
        self.assertEqual((backups[0]/'files/.gitconfig').read_text(), original)
        manifest = json.loads((backups[0]/'manifest.json').read_text())
        self.assertIn({'path': '.gitconfig', 'existed': True}, manifest)
        self.assertIn({'path': '.config/delta/themes.gitconfig', 'existed': False}, manifest)

    def test_missing_neovim_and_ghostty_use_pacman(self):
        (self.bin/'nvim').unlink()
        (self.bin/'ghostty').unlink()
        # Expose only required tools so the host's real apps cannot satisfy lookup.
        for tool in ('bash', 'python3', 'dirname', 'id', 'git', 'mktemp', 'date', 'mkdir', 'cp', 'install', 'mv', 'rm'):
            if not (self.bin/tool).exists():
                (self.bin/tool).symlink_to(shutil.which(tool))
        self.env['PATH'] = str(self.bin)
        self.run_install(neovim=True, ghostty=True)
        log = self.log.read_text()
        self.assertIn('sudo pacman -S --needed --noconfirm', log)
        self.assertIn('neovim', log)
        self.assertIn('ghostty', log)

    def test_yay_bootstrap_is_planned_before_aur_transaction(self):
        (self.bin/'yay').unlink()
        for tool in ('bash', 'dirname', 'id', 'git', 'mktemp', 'date', 'mkdir', 'cp', 'install', 'mv', 'rm'):
            if not (self.bin/tool).exists():
                (self.bin/tool).symlink_to(shutil.which(tool))
        self.env['PATH'] = str(self.bin)
        self.run_install(aur=True, mozkey=True, omarchy=True)
        log = self.log.read_text()
        self.assertIn('extra yay', log)
        self.assertLess(log.index('extra yay'), log.index('omarchy pkg aur add'))

    def test_rclone_without_remotes_fails_before_install(self):
        self.mock('rclone', 'printf "other:\\n"')
        self.run_install(rclone=True, cloud_mounts=True, expect=1)
        self.assertFalse(self.log.exists())
        self.assertFalse(self.profile.exists())

    def test_package_failure_does_not_apply_or_save(self):
        self.mock('omarchy', 'exit 23')
        self.run_install(omarchy=True, cli=True, expect=23)
        self.assertFalse(self.profile.exists())
        self.assertFalse((self.home/'.zshrc').exists())

    def test_japanese_without_aur_uses_official_mozc(self):
        self.run_install(japanese=True)
        log = self.log.read_text()
        self.assertIn('fcitx5-mozc', log)
        self.assertNotIn('mozkey-ibg-bin', log)
        self.assertNotIn('yay ', log)
        self.assertIn('sudo localectl set-locale LANG=ja_JP.UTF-8', log)
        self.assertFalse((self.home/'.config/mozkey-ibg/config1.db').exists())
        self.assertFalse((self.home/'.config/fcitx5/conf/mozkey-ibg.conf').exists())

    def test_authenticated_rclone_uses_fuse3_without_linger(self):
        self.mock('rclone', 'printf "gdrive:\\nonedrive:\\n"')
        self.run_install(rclone=True, cloud_mounts=True)
        log = self.log.read_text()
        self.assertIn('systemctl --user enable --now', log)
        self.assertNotIn('linger', log)
        service = (self.home/'.config/systemd/user/rclone-gdrive.service').read_text()
        self.assertIn('/usr/bin/fusermount3', service)
        self.assertNotIn('--allow-non-empty', service)

    def test_explicit_empty_email_clears_saved_default(self):
        self.run_install('--configure-only', '--git-email', 'old@example.invalid', personalize=True)
        self.run_install('--configure-only', '--git-email', '', personalize=True)
        self.assertEqual(json.loads(self.profile.read_text())['git_email'], '')

    def test_original_tools_restored_and_special_installers_selected(self):
        self.run_install(cli=True, downloads=True, fonts=True, mozkey=True, rustup=True)
        log = self.log.read_text()
        for text in ('stow', 'curl', 'wget', 'extra mozkey', 'extra rustup'):
            self.assertIn(text, log)
        self.assertEqual((self.home/'.config/mozkey-ibg/config1.db').read_bytes(),
                         (REPO/'dot_config/private_mozkey-ibg/config1.db').read_bytes())
        self.assertFalse((self.home/'.Brewfile').exists())

    def test_official_packages_preferred_over_special_installers(self):
        self.env['TEST_AVAILABLE'] = 'ttf-hackgen mozkey-ibg-bin'
        self.run_install(fonts=True, mozkey=True)
        log = self.log.read_text()
        self.assertNotIn('ttf-hackgen', log)
        self.assertIn('mozkey-ibg-bin', log)
        self.assertNotIn('extra hackgen', log)
        self.assertNotIn('extra mozkey', log)

    def test_bundled_fonts_sync_without_external_installer(self):
        self.run_install(fonts=True)
        source = REPO/'dot_local/share/fonts/HackGen'
        target = self.home/'.local/share/fonts/HackGen'
        for font in source.iterdir():
            self.assertEqual((target/font.name).read_bytes(), font.read_bytes())
        log = self.log.read_text()
        self.assertIn('fc-cache -f ', log)
        self.assertNotIn('extra hackgen', log)
        self.assertNotIn('ttf-hackgen', log)

    def test_normal_apply_updates_font_cache_once_and_honors_exclusion(self):
        self.run_install('--configure-only', fonts=True)
        for _ in range(2):
            subprocess.run([CHEZMOI, '-S', str(REPO), 'apply', '--force'],
                           env=self.env, text=True, capture_output=True, check=True)
        self.assertEqual(self.log.read_text().count('fc-cache -f '), 1)
        self.run_install('--configure-only', fonts=False)
        subprocess.run([CHEZMOI, '-S', str(REPO), 'apply', '--force'],
                       env=self.env, text=True, capture_output=True, check=True)
        self.assertEqual(self.log.read_text().count('fc-cache -f '), 1)

    def test_font_exclusion_preserves_existing_fonts(self):
        target = self.home/'.local/share/fonts/HackGen'
        target.mkdir(parents=True)
        (target/'HackGen35ConsoleNF-Regular.ttf').write_bytes(b'existing font')
        self.run_install(cli=True, fonts=False)
        self.assertEqual((target/'HackGen35ConsoleNF-Regular.ttf').read_bytes(), b'existing font')
        self.assertFalse((target/'LICENSE').exists())
        self.assertNotIn('fc-cache', self.log.read_text())

    def test_chezmoi_can_be_bootstrapped_when_missing(self):
        (self.bin/'chezmoi').unlink()
        for tool in ('bash', 'dirname', 'id', 'git', 'mktemp', 'date', 'mkdir', 'cp', 'install', 'mv', 'rm'):
            if not (self.bin/tool).exists():
                (self.bin/tool).symlink_to(shutil.which(tool))
        self.env['PATH'] = str(self.bin)
        self.env['TEST_CHEZMOI'] = CHEZMOI
        self.mock('sudo', 'printf "sudo %s\\n" "$*" >> "$TEST_LOG"\n/bin/ln -s "$TEST_CHEZMOI" "'+str(self.bin/'chezmoi')+'"')
        self.run_install()
        self.assertIn('chezmoi', self.log.read_text())
        self.assertTrue(self.profile.exists())

    def test_rclone_can_install_before_authentication(self):
        self.run_install(rclone=True)
        self.assertTrue((self.home/'.config/systemd/user/rclone-gdrive.service').exists())
        self.assertNotIn('systemctl', self.log.read_text())

    def test_upstream_neovim_remains_an_available_option(self):
        self.run_install(neovim=True, neovim_latest=True)
        log = self.log.read_text()
        self.assertIn('extra neovim', log)
        self.assertNotIn(' neovim ', log.replace('extra neovim', ''))

    def test_special_installer_failure_does_not_apply_configs(self):
        self.env['TEST_EXTRA_EXIT'] = '21'
        self.run_install(mozkey=True, cli=True, expect=21)
        self.assertFalse((self.home/'.zshrc').exists())
        self.assertFalse(self.profile.exists())

    def test_owner_preset_selects_previously_managed_configs(self):
        p = subprocess.run(['bash', str(REPO/'install.sh'), '--non-interactive', '--preset', 'owner', '--configure-only'],
                           env=self.env, text=True, capture_output=True)
        self.assertEqual(p.returncode, 0, p.stdout+p.stderr)
        data = json.loads(self.profile.read_text())
        for key in ('cli', 'downloads', 'fonts', 'mozkey', 'rustup', 'vscode', 'wezterm', 'mime', 'hyprland'):
            self.assertTrue(data[key], key)
        self.assertFalse(data['cloud_mounts'])
        self.assertFalse(data['linger'])
        for name in ('.config/mimeapps.list', '.config/mozkey-ibg/config1.db', '.config/vscode/setting.json', '.config/wezterm/wezterm.lua'):
            self.assertIn(name, self.managed())

    def test_declining_settings_keeps_configs_and_system_settings(self):
        original = '# existing zsh settings\n'
        (self.home/'.zshrc').write_text(original)
        self.run_install(settings=False, packages=True, cli=True, japanese=True)
        self.assertEqual((self.home/'.zshrc').read_text(), original)
        self.assertEqual(self.managed(), [])
        log = self.log.read_text()
        self.assertIn('pacman -S', log)
        self.assertNotIn('localectl', log)
        self.assertNotIn('locale-gen', log)

    def test_declining_packages_can_still_sync_settings(self):
        self.run_install(settings=True, packages=False, cli=True)
        self.assertTrue((self.home/'.zshrc').exists())
        self.assertFalse(self.log.exists())

    def test_old_ghostty_profile_does_not_restore_ghostty_sync(self):
        self.run_install('--configure-only', ghostty=True, wezterm=True)
        self.assertNotIn('.config/ghostty/config', self.managed())
        self.assertIn('.config/wezterm/wezterm.lua', self.managed())
        p = subprocess.run(['bash', str(REPO/'install.sh'), '--non-interactive', '--configure-only'],
                           env=self.env, text=True, capture_output=True)
        self.assertEqual(p.returncode, 0, p.stdout+p.stderr)
        self.assertFalse(json.loads(self.profile.read_text())['ghostty'])

    def test_existing_wezterm_is_reused_and_its_config_is_synced(self):
        self.mock('wezterm', 'exit 0')
        self.run_install(wezterm=True)
        self.assertTrue((self.home/'.config/wezterm/wezterm.lua').exists())
        self.assertFalse((self.home/'.config/ghostty/config').exists())
        self.assertFalse(self.log.exists())

    def test_japanese_group_no_overrides_saved_mozkey_choice(self):
        self.run_install('--configure-only', japanese=True, mozkey=True)
        p = subprocess.run(['bash', str(REPO/'install.sh'), '--non-interactive', '--configure-only',
                            '--no-japanese'], env=self.env, text=True, capture_output=True)
        self.assertEqual(p.returncode, 0, p.stdout+p.stderr)
        data = json.loads(self.profile.read_text())
        self.assertFalse(data['japanese'])
        self.assertFalse(data['mozkey'])

    def test_invalid_combinations_fail_before_changes(self):
        self.run_install(change_shell=True, expect=1)
        self.run_install(bar=True, expect=1)
        self.assertFalse(self.log.exists())
        self.assertFalse(self.profile.exists())

    def test_saved_defaults_reused_without_questions(self):
        self.run_install('--configure-only', personalize=True, cli=True)
        p = subprocess.run(['bash', str(REPO/'install.sh'), '--non-interactive', '--configure-only'],
                           env=self.env, capture_output=True, text=True)
        self.assertEqual(p.returncode, 0, p.stdout+p.stderr)
        profile = json.loads(self.profile.read_text())
        self.assertTrue(profile['cli'])
        self.assertFalse(profile['bar'])

    def test_interactive_questions_complete_before_mutations_and_cancel(self):
        master, slave = pty.openpty()
        self.addCleanup(os.close, master)
        p = subprocess.Popen(['bash', str(REPO/'install.sh')], env=self.env,
                             stdin=slave, stdout=slave, stderr=slave)
        os.close(slave)
        output = b''
        # Answer all choices no; the final confirmation also cancels.
        deadline = time.monotonic()+15
        while p.poll() is None and time.monotonic() < deadline:
            ready, _, _ = select.select([master], [], [], .1)
            if ready:
                try: chunk = os.read(master, 65536)
                except OSError: break
                output += chunk
                if chunk.rstrip().endswith(b':'):
                    self.assertFalse(self.log.exists())
                    self.assertFalse(self.profile.exists())
                    os.write(master, b'n\n')
        if p.poll() is None: p.kill(); self.fail(output.decode())
        self.assertEqual(p.wait(), 0, output.decode())
        self.assertIn('導入プラン'.encode(), output)
        self.assertEqual(output.count(b'[Y/n]:'), 3, output.decode())
        self.assertEqual(output.count(b'[y/N]:'), 1, output.decode())
        self.assertFalse(self.log.exists())
        self.assertFalse(self.profile.exists())


if __name__ == '__main__':
    unittest.main()
