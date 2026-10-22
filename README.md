# Mac Care

Open-source storage cleaner for macOS. Mac Care scans your disk, shows how much space can be reclaimed, cleans the categories you pick and stays in the menu bar so you always see how much space is free.

The app is available in Brazilian Portuguese, English and Spanish. It follows your macOS language by default, and you can pick a different one in **Settings › General › Language** (the change applies after reopening the app).

## Download

Get the latest build from the [Releases page](https://github.com/iLolz/mac-care/releases/latest):

- `MacCare-<version>.dmg`: open it and drag **Mac Care** to **Applications**.
- `MacCare-<version>.zip`: unzip it and move **Mac Care.app** to **Applications**.

Requires macOS 14 (Sonoma) or later. The build is universal (Apple Silicon and Intel).

### Opening the app the first time

Releases are not signed with an Apple Developer ID or notarized yet (that is planned for the distribution step of the roadmap), so Gatekeeper blocks the first launch. Use one of these options once; after that the app opens normally.

**macOS 15 (Sequoia) and later**

1. Open **Mac Care**. macOS says it cannot verify the app; click **Done**.
2. Go to **System Settings › Privacy & Security**, scroll to the **Security** section and click **Open Anyway** next to the Mac Care message.
3. Open the app again and confirm with **Open Anyway** (you may be asked for your password).

**macOS 14 (Sonoma)**

Right-click (or Control-click) **Mac Care** in Applications, choose **Open**, then click **Open** in the dialog.

**Terminal (any version)**

Remove the quarantine flag that the browser added to the download:

```sh
xattr -dr com.apple.quarantine "/Applications/Mac Care.app"
```

If macOS says the app "is damaged and can't be opened", this command fixes it too: the message comes from the quarantine flag on an unnotarized app, not from a broken file.

Each release lists SHA-256 checksums in `SHA256SUMS.txt` if you want to verify the download (`shasum -a 256 MacCare-*.dmg`).

## Status

In development. Roadmap:

1. **Disk analysis**: scan of cleanable categories and the main window *(done)*
2. **Safe cleanup**: preview, confirmation, live progress, items moved to the Trash *(done)*
3. **Monitoring and alerts**: background checks, notifications when free space drops below a limit (in % or GB) and a widget *(in progress)*
4. **Distribution**: Developer ID signing, notarization and signed `.dmg` releases

## What Mac Care cleans

| Category | Location |
|---|---|
| App caches | `~/Library/Caches` |
| Logs | `~/Library/Logs` |
| Trash | `~/.Trash` |
| Old downloads | `~/Downloads` (older than 30 days) |
| Xcode DerivedData | `~/Library/Developer/Xcode/DerivedData` |
| Xcode device support | `~/Library/Developer/Xcode/iOS DeviceSupport`, `watchOS DeviceSupport` |
| Simulator caches | `~/Library/Developer/CoreSimulator/Caches` |
| Developer tool caches | `~/.npm/_cacache`, `~/.gradle/caches` |
| node_modules | project folders such as `~/Developer`, `~/Projects`, `~/Projetos`, `~/Code`, `~/dev`, `~/workspace`, `~/Documents/GitHub` |

Scanning is read-only. Nothing is removed until you review the selection and confirm. Removed items go to the Trash so you can restore them, except items that were already in the Trash, which are deleted permanently. Mac Care only touches files inside the folders above, within your home folder.

## Using the app

### Full Disk Access

To read protected folders (such as the Trash), grant **Full Disk Access** in **System Settings › Privacy & Security › Full Disk Access**. The app shows a banner with a shortcut when access is missing.

Because releases are ad-hoc signed, macOS may treat each new version as a different app. If the banner comes back after an update, remove Mac Care from the Full Disk Access list and add it again.

### Menu bar and launch at login

When you close the window, Mac Care keeps running in the menu bar: the panel shows free space, how much can be reclaimed and shortcuts to scan again or reopen the window. The app also opens at login (turned on at first launch). Both options can be turned off in **Settings › General**; with the menu bar turned off, closing the window quits the app.

## Building from source

Requirements: macOS 14+, Xcode 16+ and [XcodeGen](https://github.com/yonaskolb/XcodeGen). The Xcode project is generated from `project.yml` and is not committed.

```sh
git clone https://github.com/iLolz/mac-care.git
cd mac-care
brew install xcodegen
xcodegen generate
open MacCare.xcodeproj
```

Pick the **MacCare** scheme and press **Run**. To run without a developer account, set **Signing & Capabilities › Team** to *None* and **Signing Certificate** to *Sign to Run Locally*.

To build from the command line without signing:

```sh
xcodebuild -project MacCare.xcodeproj -scheme MacCare -configuration Debug \
  -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO build
```

The scanning and cleanup logic lives in the `CleanerKit` Swift package and can be tested without the app:

```sh
swift test --package-path CleanerKit
```

### Project layout

- `MacCare/App`: app entry point, view models, settings, launch at login
- `MacCare/UI`: SwiftUI views (main window, cleanup sheet, menu bar panel, settings)
- `CleanerKit`: category catalog, disk scanner, cleanup engine and their tests
- `project.yml`: XcodeGen spec for the app target

## Releasing

The [Release workflow](.github/workflows/release.yml) builds a universal, ad-hoc signed `Mac Care.app`, packages it as `.zip` and `.dmg` and publishes a GitHub Release. To publish a new version, push a tag from `main`:

```sh
git tag v0.1.0
git push origin v0.1.0
```

Or open **Actions › Release › Run workflow** on `main` and enter the version (for example `0.1.0`); the workflow creates the `v0.1.0` tag and the release for you. The version shown in the app comes from the tag. The workflow also runs on pull requests that change the build setup and on manual runs without a version, uploading the packages as a workflow artifact without creating a release.

## License

[MIT](LICENSE)
