# HerosArmyKnife

Movable toolbar addon for Ascension WoW providing a central, space-efficient place for utility module icons.

## Current Features
- Manifest (`HerosArmyKnife.toc`) declaring saved variables and core files.
- Core loader (`Core.lua`) initializes persistent DB and builds toolbar on login.
- Movable toolbar (`Toolbar.lua`) with drag-to-move and position persistence.
- Options panel (`Options.lua`) explaining usage.
- Slash command (`/hak`) for reload and opening options.
- About icon module (`Modules/About.lua`) opens panel and shows tooltip/help.

## Saved Variables
- `HerosArmyKnifeDB.settings.toolbar` (point, x, y) for toolbar position.

## Adding Modules
1. Create a file in `Modules/YourModule.lua`.
2. In it, call `addon:RegisterToolbarIcon("Key", "Interface\\Icons\\YourIcon", onClickFunc, tooltipFunc)`.
3. Optionally add logic in `onClickFunc` or show multiple lines in the tooltip table.
4. Add the file path to `HerosArmyKnife.toc` after existing module entries.

## Quick Test
1. Install addon in `Interface/AddOns/`.
2. Log in; toolbar appears (center by default).
3. Drag toolbar; position is saved.
4. Click question mark icon for About / options.
5. `/hak reload` to reload UI if needed.

## Next Ideas
- Lock/scale settings for toolbar.
- Additional utility modules (inventory, latency, memory usage, gear sets).
- Per-character saved variables if needed.
- Minimap integration or keybind shortcuts.

Contributions: add modules following the pattern above. Ask if you want scaffolding for settings, localization, or performance profiling.
