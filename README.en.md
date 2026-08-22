[日本語](README.md) | English

# ExtractPerks

ExtractPerks — a simple, transparent tool to crop perk icons from your Dead by Daylight loadout screenshots.

No game file access, no black-box magic — just a readable PowerShell script that crops icons straight from a screenshot you already took. If you can take a screenshot, you can use this.

## Why this instead of a full extraction tool?

- **Transparent** — it's a plain PowerShell script; open it and read exactly what it does
- **Screenshot-based** — no need to touch game files or install anything extra
- **Simple** — take a screenshot → run the script → get transparent PNGs

If you need every perk icon at full game-asset quality, dedicated binary/asset extraction tools exist for that. This project intentionally stays in its own lane: screenshot-only, no game files touched, aimed at casual streamers who just want their own loadout icons.

## Disclaimer

- This is an unofficial, fan-made personal project. It has no affiliation with Behaviour Interactive or Dead by Daylight.
- Input files (your screenshots) and output files (cropped perk icons) are for **personal use only**. Please do not redistribute, publish, or sell them to third parties.
- The author takes no responsibility for any disadvantages, damages, or legal issues arising from the use of this script or its output. Use at your own risk.
- Before using this tool, please review Behaviour Interactive's [official fan-created content guidelines](https://support.deadbydaylight.com/hc/en-us/articles/4437901307668-General-guidelines-on-fan-created-content) and use it at your own discretion and responsibility.

## Requirements

- Windows + PowerShell 7+ (`pwsh`) recommended
  - The script is saved as UTF-8 with BOM, so it should also run fine on Windows PowerShell 5.1 (`powershell.exe`) without comment mojibake, but testing has been done primarily on `pwsh`.
- No additional installation needed (uses only .NET's `System.Drawing`)

## Quick start

1. Download this project (Code → Download ZIP, then extract) or `git clone`
2. Launch Dead by Daylight via Steam and take a screenshot of the loadout screen with **F12** (see the graphics settings below for the exact setup this was tested with)
3. Copy the `.jpg` screenshot(s) into the `src` folder
4. Open a terminal in the project folder and run:

   ```powershell
   .\ExtractPerks.ps1
   ```

5. If you get a red "running scripts is disabled" error the first time, run this once and try again:

   ```powershell
   Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned
   ```

6. Check the `out` folder — you'll find `0001.png`, `0002.png`, ... with transparent-background perk icons, ready to drop into OBS as image sources or overlay assets

## Folder structure

```
ExtractPerks/
├─ ExtractPerks.ps1   ← the script
├─ README.md / README.en.md
├─ src/                ← input: put your screenshots (*.jpg) here
└─ out/                ← output: cropped perk icons (0001.png, 0002.png, ...)
```

## Supported input specification

This script does not analyze the image content to detect the diamonds — it crops at **fixed, hardcoded pixel coordinates**. Your input images must satisfy the following conditions.

- Resolution: **1920×1080**
- Taken with Steam's built-in screenshot feature (F12)
- Screen: DBD's "Loadout" screen, with the "Inventory/Perks" grid of diamonds (5 columns × 3 rows, up to 15) visible on the left
  - Any other resolution or UI scale will shift the coordinates and is not supported
- File format: `.jpg`
- File names: must sort into capture-date order when sorted alphabetically (e.g. `20260821125444_1.jpg`, the default naming from Steam's screenshot feature)

Mixing in unsupported images (wrong resolution, etc.) will cause the script to crop the wrong areas.

### Verified in-game graphics settings

Tested with screenshots captured under DBD's Settings → Graphics → Video with the following values. Different settings may shift the resolution or UI layout enough that cropping breaks.

| Setting | Value |
|---|---|
| Fullscreen mode | Windowed |
| Screen resolution | 100% |
| Screen size | 1920×1080 |
| 16:9 aspect ratio | Off |
| Auto adjust | Off |

## How it works: coordinates and processing

### 1. Diamond grid coordinates (fixed values)

The inventory grid is laid out with the 1st/3rd rows offset by half a pitch from the 2nd row (a staggered/brick pattern). The center coordinates (x, y) and radius (center-to-vertex distance) of each diamond were measured by scanning real screenshots pixel by pixel, and are hardcoded in the script.

| Row | X coordinates (5 columns) | Y | Note |
|---|---|---|---|
| 1st | 395, 519, 642, 768, 890 | 632 | |
| 2nd | 457, 581, 704, 829, 952 | 726 | offset half a pitch to the right |
| 3rd | 395, 519, 642, 768, 890 | 819 | same X as 1st row |

Radius (`$Radius`) is 58px (center-to-vertex distance).

How the coordinates were derived: along a horizontal/vertical scan line through the center, the transition point from the background color (grayish/warm tones) to the diamond's dark border (a sharp drop in luminance) was detected, and the midpoint of that transition was used as the center. Reproducibility was confirmed across multiple columns and multiple screenshots.

**If the UI resolution or layout changes in the future**, you'll need to re-measure `$Row1X` / `$Row2X` / `$Row3X`, each row's Y, and `$Radius` at the top of `ExtractPerks.ps1` using the same method.

### 2. Detecting empty slots

Out of the 15 slots, pages with fewer owned perks will have some slots empty (outline-only "+"). To avoid mistakenly cropping these, each diamond's interior is densely sampled, and a slot is considered filled if it has 10 or more "purple" pixels (where R and B are clearly higher than G) — see the `Test-SlotFilled` function. As a result, this won't work correctly if the perk background color isn't purple (e.g. yellow or green).

### 3. Transparency outside the diamond

Any pixel where the offset from center `(dx, dy)` satisfies `|dx| + |dy| > radius` is considered outside the diamond and made fully transparent (alpha = 0).

### 4. Background (purple/border) transparency

When `$RemoveBackground = $true` (the default), pixels inside the diamond are further evaluated by luminance, leaving only the white icon linework.

```powershell
$LumaLow = 140
$LumaHigh = 220
```

- Luminance ≤ `$LumaLow` → fully transparent
- Luminance ≥ `$LumaHigh` → fully opaque
- In between → a gradient of partial transparency (to smooth anti-aliased edges)

If purple bleed bothers you, raise `$LumaLow`. If lines look too thin/faint, lower it.

Setting `$RemoveBackground = $false` only makes the area outside the diamond transparent, keeping the purple background, dark border, and icon inside intact.

### 5. Excluding the "claw mark" decoration

Every owned perk has a fixed decoration on the diamond's upper-right shoulder (three white claw-mark-like streaks) that can't be distinguished from the background by luminance alone, so it's excluded via hardcoded relative-offset boxes (`$ClawExclusionBoxes`). These coordinates were also measured empirically by comparing several different icons to find pixels common only to the decoration.

## Output

- Sequentially numbered files: `out/0001.png`, `out/0002.png`, ...
- Size: the diamond's bounding square (116×116px = radius 58 × 2)
- Numbering order: ascending by filename within `src`, then by grid position (row 1 left-to-right, then row 2, then row 3)
- PNG with alpha channel

## Troubleshooting

| Symptom | Cause / fix |
|---|---|
| Garbled/mojibake syntax error when running the script | Run from `pwsh` (PowerShell 7). If it persists, check the file is saved as UTF-8 with BOM |
| Number of output files is more/fewer than expected | Adjust the empty-slot detection threshold (`$hits -ge 10` inside `Test-SlotFilled`) |
| Diamonds are cropped off-center | Check your input resolution/UI layout matches the assumptions above. If different, re-measure the coordinates as described in "How it works" |
| Purple residue remains / lines look too faint | Adjust `$LumaLow` / `$LumaHigh` (see section 4 above) |

## License & author

- Code: [MIT License](LICENSE)
- Author: だぼあ / daboa ([daboa.dev](https://www.daboa.dev))
- Output files (cropped perk icons) are Behaviour Interactive's copyrighted material and are **not** covered by the MIT license above. See "Disclaimer".
