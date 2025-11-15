# Changelog

All notable changes to this project will be documented in this file.

The format is based on Keep a Changelog and uses semantic, human‑readable entries.

## [Unreleased]
### Added
- Comprehensive `README.md` with install, usage, configuration, and troubleshooting.
- `docs/Modules.md` with concise per‑module reference.
- GitHub contribution guidelines (`CONTRIBUTING.md`).

### Changed
- Options panel: improved right‑column layout and explicit scroll child height recalculation to ensure content fits and scrolling works.
- About: Discord link copy button placement under the link; content height calculation hardened.
- Tooltip: Verb and ON/OFF state colorization refinements.

### Fixed
- About window height error during initial layout by switching to robust fontstring height summation.

## [0.1.0] - 2025-11-15
### Added
- Initial addon scaffold: toolbar, themes, options, slash commands, and base modules (About, Settings, Reload, SellTrash, CacheOpener, MythicPlusHelper, RareTracker, DebugTools).
