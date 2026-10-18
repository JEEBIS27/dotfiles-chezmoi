#!/usr/bin/env python3
"""Install upstream tools not supplied by the selected Arch repositories.

Invoked by install.sh after its questions, plan, and package prerequisites.
Mozkey is pinned; Neovim's latest asset uses GitHub's SHA-256 digest.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import platform
import shutil
import subprocess
import tarfile
import tempfile
import urllib.request


def run(*args, **kwargs):
    print('+', ' '.join(map(str, args)), flush=True)
    return subprocess.run(list(map(str, args)), check=True, **kwargs)


def download(url, destination, sha256=None):
    if not url.startswith('https://'):
        raise ValueError('Downloads require HTTPS')
    req = urllib.request.Request(url, headers={'User-Agent': 'JEEBIS27-dotfiles-installer'})
    digest = hashlib.sha256()
    with urllib.request.urlopen(req, timeout=60) as response, open(destination, 'wb') as out:
        for chunk in iter(lambda: response.read(1024 * 1024), b''):
            digest.update(chunk)
            out.write(chunk)
    if sha256 and digest.hexdigest() != sha256:
        Path(destination).unlink()
        raise ValueError(f'SHA-256 mismatch: {url}')


def mozkey(non_interactive):
    if platform.machine() != 'x86_64':
        raise RuntimeError('The verified Mozkey Arch binary is x86_64 only; use an upstream-supported build for this architecture')
    recipe = Path(__file__).with_name('mozkey.PKGBUILD')
    with tempfile.TemporaryDirectory(prefix='dotfiles-mozkey-') as tmp:
        shutil.copy2(recipe, Path(tmp)/'PKGBUILD')
        args = ['makepkg', '--syncdeps', '--install', '--needed']
        if non_interactive:
            args.append('--noconfirm')
        run(*args, cwd=tmp)


def yay(non_interactive):
    if shutil.which('yay'):
        return
    with tempfile.TemporaryDirectory(prefix='dotfiles-yay-') as tmp:
        target = Path(tmp)/'yay-bin'
        run('git', 'clone', '--depth=1', 'https://aur.archlinux.org/yay-bin.git', target)
        args = ['makepkg', '--syncdeps', '--install', '--needed']
        if non_interactive:
            args.append('--noconfirm')
        run(*args, cwd=target)


def rustup():
    binary = shutil.which('rustup')
    if not binary:
        candidate = Path.home()/'.cargo/bin/rustup'
        if candidate.is_file():
            binary = str(candidate)
    if not binary:
        with tempfile.TemporaryDirectory() as tmp:
            script = Path(tmp)/'rustup-init.sh'
            download('https://sh.rustup.rs', script)
            run('/bin/sh', script, '-y', '--no-modify-path', '--default-toolchain', 'none',
                env=dict(os.environ, RUSTUP_INIT_SKIP_PATH_CHECK='yes'))
        binary = str(Path.home()/'.cargo/bin/rustup')
    installed = subprocess.check_output([binary, 'toolchain', 'list'], text=True)
    if not any(line.startswith('stable-') for line in installed.splitlines()):
        run(binary, 'toolchain', 'install', 'stable')
    # Preserve an existing default/nightly choice.
    if subprocess.run([binary, 'show', 'active-toolchain'], capture_output=True).returncode:
        run(binary, 'default', 'stable')


def neovim():
    arch = {'x86_64': 'x86_64', 'aarch64': 'arm64'}.get(platform.machine())
    if not arch:
        raise RuntimeError('Neovim upstream tarball supports x86_64/aarch64 here')
    with tempfile.TemporaryDirectory() as tmp:
        tmp = Path(tmp)
        metadata = tmp/'release.json'
        download('https://api.github.com/repos/neovim/neovim/releases/latest', metadata)
        release = json.loads(metadata.read_text())
        name = f'nvim-linux-{arch}.tar.gz'
        asset = next(a for a in release['assets'] if a['name'] == name)
        digest = asset.get('digest') or ''
        if not digest.startswith('sha256:'):
            raise RuntimeError('Neovim release asset has no SHA-256 digest')
        archive = tmp/name
        download(asset['browser_download_url'], archive, digest.removeprefix('sha256:'))
        extracted = tmp/'unpacked'
        with tarfile.open(archive) as tar:
            tar.extractall(extracted, filter='data')
        root = extracted/f'nvim-linux-{arch}'
        if not (root/'bin/nvim').is_file():
            raise ValueError('Unexpected Neovim archive structure')
        shutil.copytree(root, Path.home()/'.local', dirs_exist_ok=True)
        print('Neovim installed in ~/.local/bin/nvim (takes precedence over /usr/bin)')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('tool', choices=['mozkey', 'yay', 'rustup', 'neovim'])
    parser.add_argument('--non-interactive', action='store_true')
    args = parser.parse_args()
    if args.tool in ('mozkey', 'yay'):
        globals()[args.tool](args.non_interactive)
    else:
        globals()[args.tool]()


if __name__ == '__main__':
    main()
