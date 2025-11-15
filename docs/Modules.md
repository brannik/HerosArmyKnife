# HerosArmyKnife Modules

A concise reference for each module: purpose, key actions, and settings.

## About
- Purpose: Overview window with credits and a Discord invite link.
- How: Click the About icon on the toolbar.
- Notes: The window is draggable; the copy button places the invite link into a popup for easy copying.

## Settings
- Purpose: Centralize global configuration for HerosArmyKnife.
- How: `/hak options` or Interface → AddOns → HerosArmyKnife.
- Notes: The panel is scrollable. Right column contains notifications settings and quick test buttons.

## Reload
- Purpose: Single‑click UI reload.
- How: Click the Reload icon or run `/hak reload`.

## Transmog
- Purpose: Placeholder, reserved for future features.

## SellTrash
- Purpose: Vendor all grey‑quality items automatically when talking to a merchant.
- Click: Sells greys immediately (must be at a vendor).
- Auto: Sells on MERCHANT_SHOW when enabled.
- Options: Enable "Debug" for extra messages.

## CacheOpener
- Purpose: Open cache/chest/box items in your bags with throttling and safeguards.
- UI: Click the icon to open a small window with an item slot and a scrollable grid of tracked items.
- Actions:
  - Put a cache item into the slot, then click "Open" to process the stack(s) with a delay per item.
  - Reserved bag slots prevent running if too few free slots remain.
- Options: Configure reserved slots, per‑item tracking, and delay.

## MythicPlusHelper
- Purpose: Keystone awareness, queue watching, and light recruitment tooling.
- Features:
  - Keystone Scan: Shows the keystone icon when carried.
  - Monitoring Indicator: Toggle via right‑click context menu or options.
  - LFM Queue: Watches chat for LFM/recruit patterns and displays a tidy list.
  - Recruitment: Interval broadcasts with role needs and custom text.
  - Party Info: Shares spec & ilvl via addon messages (prefix `HAKMP`).
- Context Menu (Right‑Click on Icon):
  - Toggle Monitoring, set Spec (Tank/Healer/DPS), open Party Info window, open Recruitment window.
- Options: Monitoring toggle, glow color, recruitment channel/interval, role needs, custom message.

## RareTracker
- Purpose: Detect nearby rare or rare‑elite mobs on target/mouseover; optional auto‑mark and popup.
- Actions: When triggered, optionally marks the unit (requires permission), shows a popup and sound.
- Options: Enable/disable monitoring, popup, sound, auto mark, repeat interval, sound choice.

## DebugTools (optional)
- Purpose: Safe, non‑destructive testing harness.
- Actions: Inject LFG samples, show rare popup test, open Mythic+ UIs, run SellTrash dry‑run, etc.
- Options: Toggle periodic sample injection and interval.
- Notes: Meant for development; safe to delete before release.
