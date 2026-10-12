#!/bin/bash
# Installs only Delivery Pulse from its public GitHub releases.
set -euo pipefail

REPOSITORY='anitnilay20/delivery-pulse-releases'
INSTALL_DIR='/Applications'
DRY_RUN=0
for argument in "$@"; do
  case "$argument" in
    --user) INSTALL_DIR="$HOME/Applications" ;;
    --dry-run) DRY_RUN=1 ;;
    --help|-h)
      printf 'Usage: bash install.sh [--user] [--dry-run]\n\n--user     Install into your ~/Applications instead of /Applications.\n--dry-run  Download, verify, and inspect without installing or removing quarantine.\n'
      exit 0 ;;
    *) printf 'Unknown option: %s\n' "$argument" >&2; exit 1 ;;
  esac
done

fail() { printf 'Error: %s\n' "$*" >&2; exit 1; }
[[ "$(uname -s)" == Darwin ]] || fail 'This installer supports macOS only.'
for command in curl plutil hdiutil shasum ditto codesign xattr; do
  command -v "$command" >/dev/null || fail "Missing macOS utility: $command"
done

APP_NAME='Delivery Pulse.app'
TARGET="$INSTALL_DIR/$APP_NAME"
WORK_DIR=$(mktemp -d "${TMPDIR:-/tmp}/delivery-pulse-download.XXXXXX")
STAGE_DIR=''
MOUNTED=0
BACKUP=''
cleanup() {
  status=$?
  trap - EXIT
  if [[ -n "$BACKUP" && ! -e "$TARGET" && -d "$BACKUP" ]]; then
    mv "$BACKUP" "$TARGET" || printf 'Restore your previous app from: %s\n' "$BACKUP" >&2
  fi
  if [[ "$MOUNTED" == 1 ]]; then hdiutil detach "$WORK_DIR/mount" -quiet || true; fi
  # Both directories are created by mktemp, never the installed app or app data.
  if [[ -n "$STAGE_DIR" ]]; then rm -rf "$STAGE_DIR"; fi
  rm -rf "$WORK_DIR"
  exit "$status"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

printf 'Fetching the latest Delivery Pulse release…\n'
METADATA="$WORK_DIR/release.json"
# An existing CLI login can avoid GitHub's anonymous API rate limit. No token
# is extracted, printed, saved, or passed in command-line arguments.
if command -v gh >/dev/null && [[ -x /usr/bin/perl ]] &&
   /usr/bin/perl -e 'alarm 30; exec @ARGV' gh api "repos/$REPOSITORY/releases/latest" >"$METADATA" 2>/dev/null; then
  :
else
  curl --fail --silent --show-error --location --proto '=https' --proto-redir '=https' \
    --connect-timeout 10 --max-time 30 \
    -H 'Accept: application/vnd.github+json' \
    "https://api.github.com/repos/$REPOSITORY/releases/latest" -o "$METADATA" ||
      fail 'Cannot read the release metadata. If GitHub is rate-limiting you, sign in with gh auth login and retry.'
fi

TAG=$(plutil -extract tag_name raw -o - "$METADATA")
[[ "$TAG" =~ ^delivery-pulse-v([0-9]+\.[0-9]+\.[0-9]+)$ ]] || fail 'Unexpected release tag.'
VERSION="${BASH_REMATCH[1]}"
ASSET_NAME="Delivery.Pulse_${VERSION}_universal.dmg"
EXPECTED_URL="https://github.com/$REPOSITORY/releases/download/$TAG/$ASSET_NAME"
URL=''
DIGEST=''
MATCHES=0
for ((index=0; index<1000; index++)); do
  NAME=$(plutil -extract "assets.$index.name" raw -o - "$METADATA" 2>/dev/null) || break
  if [[ "$NAME" == "$ASSET_NAME" ]]; then
    MATCHES=$((MATCHES + 1))
    URL=$(plutil -extract "assets.$index.browser_download_url" raw -o - "$METADATA")
    DIGEST=$(plutil -extract "assets.$index.digest" raw -o - "$METADATA")
  fi
done
[[ "$MATCHES" == 1 && "$URL" == "$EXPECTED_URL" ]] || fail 'Missing or unexpected macOS installer asset.'
[[ "$DIGEST" =~ ^sha256:([a-f0-9]{64})$ ]] || fail 'GitHub did not provide a valid SHA-256 digest; refusing an unverified install.'
EXPECTED_SHA="${BASH_REMATCH[1]}"

printf 'Downloading Delivery Pulse %s…\n' "$VERSION"
curl --fail --location --proto '=https' --proto-redir '=https' \
  --connect-timeout 10 --max-time 180 "$URL" -o "$WORK_DIR/app.dmg"
ACTUAL_SHA=$(shasum -a 256 "$WORK_DIR/app.dmg" | awk '{print $1}')
[[ "$ACTUAL_SHA" == "$EXPECTED_SHA" ]] || fail 'Installer checksum mismatch; nothing was installed.'
printf 'SHA-256 verified.\n'

mkdir "$WORK_DIR/mount"
hdiutil attach "$WORK_DIR/app.dmg" -readonly -nobrowse -mountpoint "$WORK_DIR/mount" -quiet
MOUNTED=1
SOURCE="$WORK_DIR/mount/$APP_NAME"
[[ -d "$SOURCE" && ! -L "$SOURCE" ]] || fail 'The DMG does not contain the expected app.'
codesign --verify --deep --strict "$SOURCE"
APP_VERSION=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$SOURCE/Contents/Info.plist")
APP_ID=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$SOURCE/Contents/Info.plist")
[[ "$APP_VERSION" == "$VERSION" && "$APP_ID" == 'ai.coderabbit.delivery-pulse' ]] || fail 'The app identity or version does not match the release.'
printf 'App identity and code-signature integrity verified.\n'
printf 'This build is ad-hoc signed, not Apple-notarized. Installation removes only this app’s quarantine attribute.\n'
if [[ "$DRY_RUN" == 1 ]]; then
  printf 'Dry run passed. No app, quarantine attributes, or user data were changed.\n'
  exit 0
fi

if pgrep -x delivery-pulse >/dev/null; then fail 'Quit Delivery Pulse (including its menu-bar process) before installing.'; fi
[[ ! -L "$INSTALL_DIR" && ! -L "$TARGET" ]] || fail 'Refusing to install through a symlink.'
if [[ ! -d "$INSTALL_DIR" && "$INSTALL_DIR" == "$HOME/Applications" ]]; then mkdir -p "$INSTALL_DIR"; fi
[[ -d "$INSTALL_DIR" && -w "$INSTALL_DIR" ]] || fail 'Installation directory is not writable. Retry with --user; do not run this script with sudo.'
if [[ -e "$TARGET" ]]; then
  [[ -d "$TARGET" ]] || fail 'The installation target is not an app directory.'
  OLD_ID=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$TARGET/Contents/Info.plist")
  [[ "$OLD_ID" == "$APP_ID" ]] || fail 'An unrelated app occupies the installation target.'
fi
STAGE_DIR=$(mktemp -d "$INSTALL_DIR/.delivery-pulse-install.XXXXXX")
ditto "$SOURCE" "$STAGE_DIR/$APP_NAME"
codesign --verify --deep --strict "$STAGE_DIR/$APP_NAME"
# Do not clear unrelated extended attributes or disable Gatekeeper globally.
xattr -dr com.apple.quarantine "$STAGE_DIR/$APP_NAME"
if [[ -e "$TARGET" ]]; then
  BACKUP="$INSTALL_DIR/Delivery Pulse.backup-$(date +%Y%m%d-%H%M%S)-$$.app"
  [[ ! -e "$BACKUP" ]] || fail 'Backup path already exists.'
  mv "$TARGET" "$BACKUP"
fi
mv "$STAGE_DIR/$APP_NAME" "$TARGET"
printf 'Installed: %s\n' "$TARGET"
if [[ -n "$BACKUP" ]]; then printf 'Previous app retained at: %s\n' "$BACKUP"; fi
printf 'Your Application Support database and settings were not touched.\n'
printf 'Launch with: open "%s"\n' "$TARGET"
