# Delivery Pulse for macOS

Download the latest macOS DMG from [Releases](https://github.com/anitnilay20/delivery-pulse-releases/releases/latest), then drag Delivery Pulse into Applications. The universal build supports Apple Silicon and Intel Macs.

This repository contains only public installation instructions, the installer script, installers, signed updater archives, signatures, and the update manifest. Application source remains private. GitHub-generated source archives contain only the public distribution files.

## Install from Terminal

Download and inspect the script, then run it:

```sh
curl -fL --proto '=https' --proto-redir '=https' \
  https://raw.githubusercontent.com/anitnilay20/delivery-pulse-releases/main/install.sh \
  -o /tmp/delivery-pulse-install.sh
less /tmp/delivery-pulse-install.sh
bash /tmp/delivery-pulse-install.sh
```

The script downloads the latest universal DMG, verifies its SHA-256 digest against GitHub release metadata, checks code-signature integrity and app identity, installs into `/Applications`, and removes **only** Delivery Pulse's `com.apple.quarantine` attribute. These checks do not make the ad-hoc build Apple-notarized; run it only if you trust this distribution. Gatekeeper is not disabled globally.

Quit the app before replacing it. An existing install is backed up alongside the new app; the SQLite database and settings in Application Support are untouched. Do not run the script with `sudo`. Use `--user` to install into `~/Applications` if `/Applications` is not writable, or `--dry-run` to download and verify without installing or changing quarantine. No GitHub login is required, but an existing `gh` login can avoid anonymous API rate limits.

## Setup

To load delivery metrics, install Git and [GitHub CLI](https://cli.github.com/), sign in using `gh auth login` with access to your organization's repositories, and select your local mono checkout when prompted. Each person sees metrics for their own authenticated GitHub account.

Builds are ad-hoc signed, not Apple-notarized. Only for an installer you obtained from this repository and trust, clear quarantine after copying it into Applications:

```sh
xattr -cr "/Applications/Delivery Pulse.app"
```

## Updates and local data

Install version 1.3.1 or later manually once to enable the public update feed. Future updates can be checked and installed inside the app without access to the private source repository. Archives and their versions are verified against the app's embedded updater public key.

Your SQLite database and settings remain in your per-user macOS Application Support directory, outside the installed app bundle. Replacing or updating the app does not delete them. Personal metrics and credentials are not included in installers or published here.
