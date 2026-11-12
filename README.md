# RT Station

RT Station is a single binary, `rt`. With it your computer or server runs a
**Studio**, and a Studio holds **Workspaces**. A Workspace is one folder; in it
you make artifacts (Pages, Bases, Apps, Themes, Plugins), and People and Agents
work there. `rt` serves each Workspace live from its folder. The **Studio
Desk**, which `rt` also runs, is the page where you list, start and stop the
Workspaces of your Studio.

This repository holds the installers and the released binaries. The source code
is not public.

## Install

**Linux (x86_64)**

```sh
curl -fsSL https://raw.githubusercontent.com/ndendic/rt-station/main/install.sh | sh
```

This puts `rt` in `~/.local/bin` (no sudo). If that folder is not on your
`PATH`, the installer prints the line to add to your shell profile.

**Windows (x64), in PowerShell**

```powershell
irm https://raw.githubusercontent.com/ndendic/rt-station/main/install.ps1 | iex
```

This puts `rt.exe` in `%LOCALAPPDATA%\Programs\rt` (no administrator rights) and
adds that folder to your user `Path`. Open a new terminal afterwards.

Both installers download the release archive and `checksums.txt`, check the
archive's SHA-256 against it, and stop without changing anything if they do not
match. Then they run `rt --version` to show what was installed.

Check that it works:

```sh
rt --version
```

## First steps

```sh
rt init my-first      # make a Workspace in the folder my-first
rt run my-first       # run it; its log (JSON lines) names the address
```

Open http://localhost:8080, the port a new Workspace uses (`PORT` in `my-first/.env`;
the log line `"server started"` shows the address it listens on). The first time,
make the Workspace's administrator at http://localhost:8080/admin/setup. Then `my-first/pages/README.md` shows how to publish your
first Page. `rt` alone lists every command.

## Options

Both installers read these environment variables. All are optional.

| Variable | What it does | Default |
|---|---|---|
| `RT_VERSION` | Install this release instead of the latest, for example `0.21.1` | latest release |
| `RT_INSTALL_DIR` | Install into this folder | Linux: `~/.local/bin`, Windows: `%LOCALAPPDATA%\Programs\rt` |
| `RT_FORCE=1` | Linux only: replace `rt` even when it is a symlink (see below) | off |
| `RT_BASE_URL` | Download releases from another place, for example a mirror | `https://github.com/ndendic/rt-station/releases` |

### Install a specific version

Linux:

```sh
curl -fsSL https://raw.githubusercontent.com/ndendic/rt-station/main/install.sh | RT_VERSION=0.21.1 sh
```

Windows:

```powershell
$env:RT_VERSION = '0.21.1'; irm https://raw.githubusercontent.com/ndendic/rt-station/main/install.ps1 | iex
```

`0.21.1` is the current release and `0.19.0` was the first public one. Every version is listed on the
[Releases page](https://github.com/ndendic/rt-station/releases); use any of
them (with or without the leading `v`).

### Symlinks on Linux

If `~/.local/bin/rt` is a symlink, the Linux installer stops and explains why.
A symlink there usually means someone linked `rt` to their own build, and the
installer will not replace it silently. Remove the link, or run the installer
with `RT_FORCE=1`.

## Upgrade

Run the same install command again. It replaces the binary with the latest
release (or with `RT_VERSION`).

- On Linux the new file is renamed over the old one, so an `rt` that is already
  running keeps working. Restart it to use the new version.
- On Windows a running `rt.exe` cannot be overwritten, so the installer renames
  it to `rt.exe.old` first and puts the new `rt.exe` in its place. The next run
  of the installer deletes old `rt.exe.old` files that are no longer in use.
  Restart running Workspaces to use the new version.

## Uninstall

**Linux**

```sh
rm ~/.local/bin/rt
```

**Windows**

1. Delete the folder `%LOCALAPPDATA%\Programs\rt`.
2. Remove that folder from your user `Path`: Settings, search "environment
   variables", "Edit environment variables for your account", `Path`.

**Data `rt` keeps (both systems)**

`rt` keeps the machine's state in `.rt` in your home folder (`~/.rt` on Linux,
`%USERPROFILE%\.rt` on Windows), or in `RT_HOME` if you set it. That folder
holds the list of Workspaces on this machine, the Studio Desk, archives and local
backups. Delete it only if you want all of that gone. Your Workspaces are
ordinary folders wherever you created them; uninstalling `rt` does not touch
them.

If you ran `rt agents global`, it also copied agent skills into
`~/.claude/skills`. Remove those folders by hand if you no longer want them.

## Verify a download by hand

Each release has a `checksums.txt` with the SHA-256 of every archive.

Linux:

```sh
curl -fsSLO https://github.com/ndendic/rt-station/releases/latest/download/rt_linux_amd64.tar.gz
curl -fsSLO https://github.com/ndendic/rt-station/releases/latest/download/checksums.txt
sha256sum --check --ignore-missing checksums.txt
```

Windows (PowerShell):

```powershell
$base = 'https://github.com/ndendic/rt-station/releases/latest/download'
Invoke-WebRequest "$base/rt_windows_amd64.zip" -OutFile rt_windows_amd64.zip -UseBasicParsing
Invoke-WebRequest "$base/checksums.txt" -OutFile checksums.txt -UseBasicParsing
(Get-FileHash rt_windows_amd64.zip -Algorithm SHA256).Hash.ToLower()
Select-String rt_windows_amd64.zip checksums.txt
```

The two hashes must be the same.

## Supported platforms

| System | Architecture | Archive |
|---|---|---|
| Linux | x86_64 (amd64) | `rt_linux_amd64.tar.gz` |
| Windows | x64 (amd64) | `rt_windows_amd64.zip` |

Other systems and architectures (macOS, Linux on ARM, Windows on ARM) are not
supported yet.

## Releases

Every version is on the
[Releases page](https://github.com/ndendic/rt-station/releases). A release has
the two archives above, `checksums.txt` and `THIRD_PARTY_NOTICES.md`. The
binaries are built from the private source and published here; this repository
itself contains no source code.

## Licences

- **RT Coat**, the UI library built into `rt`, is under the MIT licence.
- **Datastar**, which RT Station uses for live pages, is under the MIT licence.
- Every other third-party component in the binary and its licence is listed in
  `THIRD_PARTY_NOTICES.md`, attached to each release:
  [latest THIRD_PARTY_NOTICES.md](https://github.com/ndendic/rt-station/releases/latest/download/THIRD_PARTY_NOTICES.md).

> **TODO (owner):** decide and state the licence for the `rt` binary itself and
> for the installer scripts in this repository.
