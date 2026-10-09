# Launching Bulong sa Bahay

The game is a Godot project. Node.js serves the exported browser files and runs optional browser tests; it is not the game engine. There is no Vite dev server, and `npm run serve` does not rebuild source changes.

## 1. Play an existing browser build

On this development machine, open PowerShell and run:

```powershell
cd C:\Users\peter\raindev\indie
npm.cmd run serve
```

For another checkout, change into that checkout instead. Wait for:

```text
Bulong sa Bahay: http://127.0.0.1:8060 (...\build\web)
```

Open **http://127.0.0.1:8060** in your browser. Keep the terminal open while playing. Press **Ctrl+C** in that terminal to stop the server. Starting this server does not start Playwright, open a browser or capture the mouse.

The server uses only Node's built-in modules, so an existing export can be served without installing npm dependencies. `build/web/index.html`, `index.js`, `index.wasm`, `index.pck` and the other exported files must remain together. Do not open the HTML with `file://`.

This server binds only to `127.0.0.1`: it is accessible on this computer, not from your phone. That address on a phone means the phone itself. Use a hosted web build for physical-device testing; an actual itch.io embed remains a release test gate.

## 2. Set up a fresh clone and build

Prerequisites: Git, Node.js with npm, Windows PowerShell, and internet access for the first setup. The scripts pin Godot **4.7.2 Standard**, not the .NET edition. Node.js 24.21.0 / npm 12.0.2 are the locally tested tool versions.

```powershell
# Start in the folder where you keep projects.
git clone https://github.com/RainVar/indiehorror.git
cd indiehorror
npm.cmd ci
powershell -ExecutionPolicy Bypass -File tools/bootstrap.ps1
npm.cmd run build
npm.cmd run serve
```

Bootstrap downloads the editor and export templates, verifies official SHA-512 checksums, and prepares a portable editor under `.tools/godot/`. The templates are approximately 1.2 GB; this initial download can take time. The browser game ZIP is approximately 12 MiB.

The build imports assets, bakes the world, runs engine tests, exports both supported targets, and packages:

- `build/web/index.html`: browser export; serve the whole folder.
- `build/windows/BulongSaBahay.exe`: portable Windows x86-64 executable.
- `build/releases/BulongSaBahay-0.2.0-web.zip`: itch.io HTML upload.
- `build/releases/BulongSaBahay-0.2.0-windows.zip`: Windows download.

These outputs and the toolchain are ignored by Git. A fresh clone has source and assets, not a prebuilt game. A build does not start the local server automatically. Playwright/browser downloads are not required for the engine tests or release exports.

## 3. Run from source while developing

Open `project.godot` in Godot 4.7.2 Standard, wait for resource import to finish, then press **F6** to play the current scene or **F5** to run the project. The main scene is `scenes/main.tscn`.

With the bootstrapped portable editor, launch it from the project folder:

```powershell
& .\.tools\godot\Godot_v4.7.2-stable_win64.exe --editor --path .
```

This avoids rebuilding the browser export for every edit. To see source changes in the browser, stop the game, run `npm.cmd run build`, then serve and reload the new export. Rebuild with the server stopped so it cannot serve a mixture of old and new files.

The source can be opened in Godot on other desktop platforms, but the included automated bootstrap/export scripts target Windows. Other platforms need the matching editor and export templates installed separately; they are not validated release targets.

## 4. Launch the portable Windows edition

After building, run:

```powershell
& .\build\windows\BulongSaBahay.exe
```

For a distributed Windows ZIP, extract it to a folder first, then run `BulongSaBahay.exe`. Keep `README.txt`, `CREDITS.txt` and `licenses/` with the executable when distributing it. No web server, Node.js or Godot installation is required for players. The executable is unsigned; only run a build from a source you trust, and do not disable system-wide security protections.

## 5. Troubleshooting

### “This site can't be reached” / `ERR_CONNECTION_REFUSED`

Nothing is accepting connections at that address. Start `npm.cmd run serve` in the project folder and keep that terminal open, then reload **http://127.0.0.1:8060**. Check that the printed port matches the browser address. Localhost does not depend on Wi-Fi.

### “Not found” / HTTP 404

The server is running, but the export is missing or the wrong folder was served. Check `Test-Path build/web/index.html`. On a fresh clone, run bootstrap and `npm.cmd run build` first. An existing downloaded web ZIP can also be extracted to `build/web/` with `index.html` directly inside it.

### Port already in use / `EADDRINUSE`

Stop the server you started with **Ctrl+C**. Do not terminate every Node process; other projects may be using them. Alternatively, choose another port:

```powershell
node tools/serve.mjs build/web 8065
```

Open **http://127.0.0.1:8065**. If you previously set the `PORT` environment variable, clear it first with `Remove-Item Env:PORT -ErrorAction SilentlyContinue`; it overrides the command-line port.

### `npm` is not recognized, or `npm.ps1` is blocked

Install Node.js with npm and reopen the terminal. Use `npm.cmd` / `npx.cmd` on Windows to avoid the PowerShell wrapper policy. The documented `-ExecutionPolicy Bypass` applies only to the explicitly invoked project script process; no permanent execution-policy change is needed.

### “Run tools/bootstrap.ps1 first” / missing export templates

Run `powershell -ExecutionPolicy Bypass -File tools/bootstrap.ps1` from the checkout. The build expects the pinned portable console executable and templates under `.tools/`; a different global Godot install does not satisfy that script's path.

### Mouse stops after fullscreen or switching windows

The game pauses when fullscreen or mouse capture changes. Click **Return to the house** to resume with a fresh browser gesture. Press **Esc** to leave capture and use menus. Browser automation is not part of normal launching.

### Mobile or a slow laptop

Choose **Low** quality and reduce other settings as needed. Touch play requires landscape orientation and WebGL 2 support. Android/iOS hardware testing is still outstanding, and no native Android APK is included. Compatibility or smooth performance on every device is not guaranteed.

## Further documentation

- [README: controls, privacy, build/test workflow and architecture](../README.md)
- [Player instructions](PLAYER-README.txt)
- [Verification results and remaining release gates](QA-REPORT.md)
- [Playtest checklist](PLAYTEST.md)
- [itch.io upload settings and page draft](ITCH-PAGE.md)
- [Asset provenance](asset-manifest.json) and [credits](CREDITS.txt)
