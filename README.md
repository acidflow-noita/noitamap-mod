# NoitaMap mod

> [!IMPORTANT]
> Press `M` key on your keyboard to open [NoitaMap](https://noitamap.com) with the map of your current run at your current location in the world.
> 
> The map knows about your progress (spell unlocks).
>
> Daily run map generation is also supported!

This is a companion mod for the [NoitaMap](https://noitamap.com).

### Featured mod settings

- Custom sound effects, which you can disable in the settings.
- Selection of the noitamap website version (`production`, `development`, `localhost`).

## How to use the mod

Choose one download from the [latest release](https://github.com/acidflow-noita/noitamap-mod/releases/latest):

- **Windows installer:** run the `.exe`. Its filename identifies whether it is signed or unsigned.
- **Linux / Steam Deck installer:** download [`install.sh`](https://github.com/acidflow-noita/noitamap-mod/releases/latest/download/install.sh), then run `sh install.sh`. It contains the matching mod files and works without downloading or unpacking a ZIP. Use `sh install.sh --dir "/path/to/Noita"` if detection fails.
- **Manual installation:** download [`noitamap.zip`](https://github.com/acidflow-noita/noitamap-mod/releases/latest/download/noitamap.zip). It contains only the `noitamap/` folder. Extract it directly into Noita's `mods` folder; the required path is `mods/noitamap/mod.xml`.

GitHub's **Source code** downloads and the ZIP containers under **Actions → Artifacts** are not the installable release ZIP.

1. Locate Noita's mods folder (Steam ➔ right click Noita ➔ Local files), or copy and paste the path into Windows Explorer:

```
C:\Program Files (x86)\Steam\steamapps\common\Noita\mods
```
<img width="1351" height="444" alt="Noita mods folder" src="https://github.com/user-attachments/assets/d9f73753-46ee-424c-a308-a295b7e0f79b" />


2. Launch Noita, click “Mods”, click “Unsafe mods: Disabled”, click “Yes” (this is due to deeper game integration requirements), click on “Noita Map” in the mods list so it shows `[x]`.
   <img width="3840" height="2160" alt="Enable the mod" src="https://github.com/user-attachments/assets/ff635f4c-58a5-4445-979f-15829a9bd1d5" />


3. (_optional_) Turn on "Pause the game when focused" option in the settings.
  <img width="2148" height="1824" alt="pause_setting" src="https://github.com/user-attachments/assets/9304bed0-3169-4445-878f-0e253ebd8c36" />

3. Press `M` mid-run to open the map at your current location.
4. This mod has settings, adjust them to your liking.
   <img width="2148" height="1824" alt="Noitamap mod settings" src="https://github.com/user-attachments/assets/0cc031bb-07a6-40a8-82c2-d78397d0da38" />

Keep the map tab open between launches. With a website version that supports warm tab reuse, pressing `M` updates that tab without reloading it. The mod's **Map Website** and browser settings must match the existing tab, including its browser profile. Different sites and private windows cannot share it. If the browser leaves a tab saying “Updated existing Noitamap tab”, close that duplicate and return to the map.


## Supported game modes and custom mods

Works with:

- Regular game mod, including dynamic map for the daily run
- NG+
- Nightmare
- Apotheosis
- Noitavania
- Alternate Biomes

## When will you publish the mod on the Steam Workshop

I am unable to do so: NoitaMap mod requires elevated mod permissions (this is an "unsafe" mod). Unsafe mods are not allowed on the Workshop.

## Development checks

`luajit tests/runtime.lua` checks URL construction, launch behavior, and unlock encoding with the game/browser APIs stubbed. `python3 -m unittest discover -s tests -p '*_test.py' -v` checks installation in temporary directories. Both run automatically on pushes and pull requests; they do not launch Noita or install into a real game.

`python3 build_release.py` creates `dist/noitamap.zip`, standalone `dist/install.sh` and `dist/SHA256SUMS.txt`. The ZIP has exactly one top-level directory, `noitamap/`, including the license. No installer scripts or extra ZIP layer are inside it.

Commit and push the source changes before tagging that commit. The tag workflow tests and builds both installers, then publishes all release assets together. Without SignPath credentials it publishes a clearly labelled unsigned EXE; when signing is configured, signing must succeed before publication. Manual workflow runs build test artifacts without publishing a release.

## Credits

Huge thanks to [Horscht](https://github.com/TheHorscht) and [Dexter](https://github.com/dextercd) for their help.
