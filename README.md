# Delivery Pulse for macOS

Download the latest macOS DMG from [Releases](https://github.com/anitnilay20/delivery-pulse-releases/releases/latest), then drag Delivery Pulse into Applications. The universal build supports Apple Silicon and Intel Macs.

This repository contains only installers, signed updater archives, signatures, and the update manifest. Application source remains private. GitHub-generated source archives contain only this distribution README.

## Setup

To load delivery metrics, install Git and [GitHub CLI](https://cli.github.com/), sign in using `gh auth login` with access to your organization's repositories, and select your local mono checkout when prompted. Each person sees metrics for their own authenticated GitHub account.

Builds are ad-hoc signed, not Apple-notarized. Only for an installer you obtained from this repository and trust, clear quarantine after copying it into Applications:

```sh
xattr -cr "/Applications/Delivery Pulse.app"
```

## Updates and local data

Install version 1.3.1 or later manually once to enable the public update feed. Future updates can be checked and installed inside the app without access to the private source repository. Archives and their versions are verified against the app's embedded updater public key.

Your SQLite database and settings remain in your per-user macOS Application Support directory, outside the installed app bundle. Replacing or updating the app does not delete them. Personal metrics and credentials are not included in installers or published here.
