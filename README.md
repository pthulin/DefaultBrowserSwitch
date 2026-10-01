# Default Browser Switch

**Switch your browser, change your life.**

A small macOS menu bar app that switches the system default browser between Safari and Google Chrome.

The menu bar is the strip across the top of the screen. The app shows **Safari** or **Chrome** there, matching whichever one currently opens web links. Click that label and choose the other browser. macOS asks you to confirm the change. It may ask once for https and once for http.

The app has no Dock icon. Quit it from the same menu.

If some other browser is the default, the menu bar shows that app’s name until you pick Safari or Chrome. Safari and Chrome are the only two it can set.

## Set up on a new computer

Build it on that Mac. A copy of `DefaultBrowserSwitch.app` from another machine is signed only for the Mac that built it, so macOS will usually refuse to open it.

You need:

- macOS 14 or later
- [Google Chrome](https://www.google.com/chrome/) installed in `/Applications`
- Xcode Command Line Tools, which provide `swiftc`

Safari is already part of macOS.

1. Copy this project folder onto the new Mac.
2. Install the command line tools if `swiftc` is not already available:

   ```bash
   xcode-select --install
   ```

3. In the project folder, build and launch:

   ```bash
   chmod +x build.sh
   ./build.sh
   open build/DefaultBrowserSwitch.app
   ```

4. Look at the menu bar for **Safari** or **Chrome**. Click it once to confirm the menu opens.

To keep the app somewhere easy to find, move it after building:

```bash
cp -R build/DefaultBrowserSwitch.app /Applications/
open -a "Default Browser Switch"
```

The name in Finder and in the `open` command is **Default Browser Switch**. The menu bar itself only shows **Safari** or **Chrome**.

### Open it at login

1. Open **System Settings → General → Login Items & Extensions**.
2. Under **Open at Login**, click **+**.
3. Choose **Default Browser Switch** from Applications (or `build/DefaultBrowserSwitch.app` if you left it in the project folder).

### If macOS blocks the app

A local build normally opens right away. If a copied app is blocked:

1. Open **System Settings → Privacy & Security**.
2. Allow **Default Browser Switch** with **Open Anyway**.

Or rebuild with `./build.sh` on that Mac and open the new app.

## Use it

- The menu bar label is the current default for web links.
- Choose **Safari** or **Google Chrome** to switch. Confirm the dialog macOS shows.
- Choose **Quit** to leave the app. The default browser stays as you last set it.

Rebuild after changing the source:

```bash
./build.sh
open build/DefaultBrowserSwitch.app
```

Opening it again replaces the copy that is already running.

## License

Use at your own risk. See [LICENSE](LICENSE).
