"""Validate upstream installation paths without changing the host or using the network."""
import hashlib
import importlib.util
import io
import json
import os
from pathlib import Path
import subprocess
import tarfile
import tempfile
import unittest
from unittest.mock import patch

SPEC = importlib.util.spec_from_file_location('extras', Path(__file__).resolve().parents[1]/'scripts/install-extras.py')
extras = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(extras)


class ExtrasTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)

    def test_download_checks_sha_and_removes_corrupt_payload(self):
        target = self.root/'asset'
        with patch.object(extras.urllib.request, 'urlopen', return_value=io.BytesIO(b'payload')):
            extras.download('https://example.invalid/asset', target, hashlib.sha256(b'payload').hexdigest())
        self.assertEqual(target.read_bytes(), b'payload')
        with patch.object(extras.urllib.request, 'urlopen', return_value=io.BytesIO(b'corrupt')):
            with self.assertRaises(ValueError):
                extras.download('https://example.invalid/asset', target, '0'*64)
        self.assertFalse(target.exists())
        with self.assertRaises(ValueError):
            extras.download('http://example.invalid/asset', target)

    def test_mozkey_uses_checked_in_verified_package_definition(self):
        def run(*args, **kwargs):
            recipe = (Path(kwargs['cwd'])/'PKGBUILD').read_text()
            self.assertIn("pkgver=0.10.4", recipe)
            self.assertIn('33b8f01927c35f512fd4a8bdca4c23165f6532766f21e0580673dc6679ef958f', recipe)
            self.assertIn("depends=('fcitx5'", recipe)
            self.assertIn('--noconfirm', args)
        with patch.object(extras.platform, 'machine', return_value='x86_64'), patch.object(extras, 'run', side_effect=run) as call:
            extras.mozkey(True)
        self.assertEqual(call.call_count, 1)
        with patch.object(extras.platform, 'machine', return_value='aarch64'):
            with self.assertRaises(RuntimeError):
                extras.mozkey(True)

    def test_rustup_preserves_existing_stable_and_default(self):
        with patch.object(extras.shutil, 'which', return_value='/toolchain/rustup'), \
             patch.object(extras.subprocess, 'check_output', return_value='stable-x86_64-unknown-linux-gnu (default)\n'), \
             patch.object(extras.subprocess, 'run', return_value=subprocess.CompletedProcess([], 0)), \
             patch.object(extras, 'run') as run:
            extras.rustup()
        run.assert_not_called()

    def test_rustup_can_initialize_stable(self):
        with patch.object(extras.shutil, 'which', return_value='/toolchain/rustup'), \
             patch.object(extras.subprocess, 'check_output', return_value='no installed toolchains\n'), \
             patch.object(extras.subprocess, 'run', return_value=subprocess.CompletedProcess([], 1)), \
             patch.object(extras, 'run') as run:
            extras.rustup()
        self.assertEqual(run.call_args_list[0].args, ('/toolchain/rustup', 'toolchain', 'install', 'stable'))
        self.assertEqual(run.call_args_list[1].args, ('/toolchain/rustup', 'default', 'stable'))

    def test_neovim_requires_a_published_digest(self):
        def fetch(url, path, digest=None):
            Path(path).write_text(json.dumps({'assets': [{'name': 'nvim-linux-x86_64.tar.gz', 'digest': None}]}))
        with patch.object(extras.platform, 'machine', return_value='x86_64'), \
             patch.object(extras, 'download', side_effect=fetch):
            with self.assertRaises(RuntimeError):
                extras.neovim()

    def test_neovim_installs_verified_tarball_and_rejects_escape(self):
        unsafe = False
        def fetch(url, path, digest=None):
            if url.endswith('/latest'):
                Path(path).write_text(json.dumps({'assets': [{'name': 'nvim-linux-x86_64.tar.gz',
                    'digest': 'sha256:'+'a'*64, 'browser_download_url': 'https://example.invalid/nvim.tar.gz'}]}))
            else:
                self.assertEqual(digest, 'a'*64)
                with tarfile.open(path, 'w:gz') as tar:
                    member = tarfile.TarInfo('nvim-linux-x86_64/bin/nvim')
                    member.size = 4; member.mode = 0o755
                    tar.addfile(member, io.BytesIO(b'nvim'))
                    if unsafe:
                        member = tarfile.TarInfo('../../outside')
                        member.size = 1
                        tar.addfile(member, io.BytesIO(b'x'))
        with patch.object(extras.platform, 'machine', return_value='x86_64'), \
             patch.object(extras.Path, 'home', return_value=self.root/'home'), \
             patch.object(extras, 'download', side_effect=fetch):
            extras.neovim()
            self.assertEqual((self.root/'home/.local/bin/nvim').read_bytes(), b'nvim')
            unsafe = True
            with self.assertRaises(tarfile.OutsideDestinationError):
                extras.neovim()


if __name__ == '__main__':
    unittest.main()
