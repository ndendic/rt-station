# Install or upgrade RT Station (rt.exe) on Windows x64.
#
#   irm https://raw.githubusercontent.com/ndendic/rt-station/main/install.ps1 | iex
#
# Works in Windows PowerShell 5.1 and PowerShell 7. Settings (all optional,
# read from environment variables, for example  $env:RT_VERSION = '0.19.0'):
#   RT_VERSION      install this release instead of the latest
#   RT_INSTALL_DIR  folder to install into; default: %LOCALAPPDATA%\Programs\rt
#   RT_BASE_URL     where releases are downloaded from; default:
#                   https://github.com/ndendic/rt-station/releases
#
# Running it again is the upgrade. It needs no administrator rights: it only
# changes your user Path, never the machine Path.

function Install-RtStation {
    $ErrorActionPreference = 'Stop'
    Set-StrictMode -Version 2.0

    $archive = 'rt_windows_amd64.zip'
    $sums = 'checksums.txt'

    # Test mode exists so the download, verify and unpack steps can be checked
    # on a non-Windows machine. It needs both RT_INSTALLER_TEST=1 and
    # RT_INSTALL_DIR, skips the Windows checks, never touches Path and does not
    # run rt.exe.
    $testMode = ($env:RT_INSTALLER_TEST -eq '1') -and [bool]$env:RT_INSTALL_DIR

    if (-not $testMode) {
        if ([Environment]::OSVersion.Platform -ne [PlatformID]::Win32NT) {
            throw 'rt install: this script is for Windows x64. On Linux x86_64 use install.sh. Other platforms are not supported yet.'
        }
        # A 32-bit PowerShell on 64-bit Windows reports x86 here and the real
        # architecture in PROCESSOR_ARCHITEW6432.
        $cpu = $env:PROCESSOR_ARCHITEW6432
        if (-not $cpu) { $cpu = $env:PROCESSOR_ARCHITECTURE }
        if ($cpu -ne 'AMD64') {
            throw "rt install: Windows x64 (AMD64) is the only Windows build (found: $cpu). Other architectures are not supported yet."
        }
        if (-not $env:RT_INSTALL_DIR -and -not $env:LOCALAPPDATA) {
            throw 'rt install: LOCALAPPDATA is not set; set RT_INSTALL_DIR to choose a folder.'
        }
    }

    # Windows PowerShell 5.1 may default to TLS 1.0, which GitHub refuses.
    if ($PSVersionTable.PSVersion.Major -lt 6) {
        [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
    }

    $base = 'https://github.com/ndendic/rt-station/releases'
    if ($env:RT_BASE_URL) { $base = $env:RT_BASE_URL }
    $base = $base.TrimEnd('/')
    if ($env:RT_VERSION) {
        $label = 'v' + $env:RT_VERSION.TrimStart('v')
        $url = "$base/download/$label"
    } else {
        $label = 'latest'
        $url = "$base/latest/download"
    }

    if ($env:RT_INSTALL_DIR) {
        $dir = $env:RT_INSTALL_DIR
    } else {
        $dir = Join-Path $env:LOCALAPPDATA 'Programs\rt'
    }
    $dir = $dir.TrimEnd('\', '/')
    $target = Join-Path $dir 'rt.exe'

    $tmp = Join-Path ([IO.Path]::GetTempPath()) ('rt-install-' + [Guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $tmp | Out-Null
    $savedProgress = $ProgressPreference
    try {
        # The progress bar makes Invoke-WebRequest very slow on 5.1.
        $ProgressPreference = 'SilentlyContinue'

        Write-Host "Downloading rt ($label) from $url"
        $zip = Join-Path $tmp $archive
        $sumsFile = Join-Path $tmp $sums
        foreach ($pair in @(@($archive, $zip), @($sums, $sumsFile))) {
            try {
                Invoke-WebRequest -UseBasicParsing -Uri "$url/$($pair[0])" -OutFile $pair[1]
            } catch {
                throw "rt install: download failed: $url/$($pair[0]) ($($_.Exception.Message))"
            }
        }

        $expected = $null
        foreach ($line in Get-Content -LiteralPath $sumsFile) {
            $parts = $line.Trim() -split '\s+'
            if ($parts.Count -ge 2 -and ($parts[1] -eq $archive -or $parts[1] -eq "*$archive")) {
                $expected = $parts[0].ToLowerInvariant()
                break
            }
        }
        if (-not $expected) { throw "rt install: $sums has no line for $archive" }
        $actual = (Get-FileHash -LiteralPath $zip -Algorithm SHA256).Hash.ToLowerInvariant()
        if ($expected -ne $actual) {
            throw "rt install: checksum mismatch for $archive`n  expected: $expected`n  got:      $actual`nNothing was installed."
        }
        Write-Host "Checksum OK ($actual)"

        $unpacked = Join-Path $tmp 'x'
        Expand-Archive -LiteralPath $zip -DestinationPath $unpacked -Force
        $newExe = Join-Path $unpacked 'rt.exe'
        if (-not (Test-Path -LiteralPath $newExe -PathType Leaf)) {
            throw "rt install: $archive does not contain rt.exe at its root"
        }

        # Windows locks a running exe: it cannot be overwritten or deleted, but
        # it can be renamed. Stage the new file next to the target, move the
        # old rt.exe aside to rt.exe.old, then put the new one in place.
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
        Get-ChildItem -LiteralPath $dir -Filter 'rt.exe.old*' -ErrorAction SilentlyContinue |
            ForEach-Object { Remove-Item -LiteralPath $_.FullName -Force -ErrorAction SilentlyContinue }

        $staged = Join-Path $dir 'rt.exe.new'
        Copy-Item -LiteralPath $newExe -Destination $staged -Force

        $old = $null
        if (Test-Path -LiteralPath $target) {
            $old = Join-Path $dir 'rt.exe.old'
            if (Test-Path -LiteralPath $old) {
                # An earlier rt.exe.old is still in use; pick a fresh name.
                $old = Join-Path $dir ('rt.exe.old-' + [Guid]::NewGuid().ToString('N').Substring(0, 8))
            }
            try {
                Move-Item -LiteralPath $target -Destination $old
            } catch {
                Remove-Item -LiteralPath $staged -Force -ErrorAction SilentlyContinue
                throw "rt install: could not move the old rt.exe aside: $($_.Exception.Message)"
            }
        }
        try {
            Move-Item -LiteralPath $staged -Destination $target
        } catch {
            Remove-Item -LiteralPath $staged -Force -ErrorAction SilentlyContinue
            if ($old) { Move-Item -LiteralPath $old -Destination $target -ErrorAction SilentlyContinue }
            throw "rt install: could not put rt.exe in place: $($_.Exception.Message)"
        }
        if ($old) { Remove-Item -LiteralPath $old -Force -ErrorAction SilentlyContinue }

        if ($testMode) {
            Write-Host "Installed rt.exe to $target (test mode: Path unchanged, rt.exe not run)"
            return
        }

        $installed = 'rt (version unknown)'
        try { $installed = (& $target --version) -join ' ' } catch { }
        Write-Host "Installed $installed to $target"

        # Add the folder to the USER Path when it is missing. Read the raw
        # registry value so entries such as %USERPROFILE%\bin stay unexpanded.
        $key = Get-Item -LiteralPath 'HKCU:\Environment'
        $userPath = [string]$key.GetValue('Path', '', 'DoNotExpandEnvironmentNames')
        $kind = 'ExpandString'
        if ($key.GetValueNames() -contains 'Path') { $kind = $key.GetValueKind('Path').ToString() }
        $entries = @($userPath -split ';' | Where-Object { $_ -ne '' })
        $present = $entries | Where-Object {
            [Environment]::ExpandEnvironmentVariables($_).TrimEnd('\') -ieq $dir
        }
        if (-not $present) {
            $newPath = (@($entries) + $dir) -join ';'
            Set-ItemProperty -LiteralPath 'HKCU:\Environment' -Name 'Path' -Value $newPath -Type $kind
            # Setting any user variable through .NET tells Windows the
            # environment changed, so new terminals pick up the new Path.
            [Environment]::SetEnvironmentVariable('RT_INSTALL_REFRESH', '1', 'User')
            [Environment]::SetEnvironmentVariable('RT_INSTALL_REFRESH', $null, 'User')
            $env:Path = "$env:Path;$dir"
            Write-Host ''
            Write-Host "Added $dir to your user Path. Open a new terminal to use rt there."
        }
    } finally {
        $ProgressPreference = $savedProgress
        Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue
    }
}

Install-RtStation
