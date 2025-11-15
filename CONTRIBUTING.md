# Contributing to HerosArmyKnife

Thanks for your interest in improving HerosArmyKnife! This guide explains how to propose changes, report issues, and open pull requests.

## Getting Started
- Game/client: Ascension (Wrath 3.3.5, Interface 30300).
- Install: Place the `HerosArmyKnife` folder under `Interface/AddOns/`.
- Load: Log in, enable the addon, and use `/hak options` to open settings.
- Toolbar: Drag to move; right‑click the frame for quick actions.

## Branching & Commits
- Create feature branches from `master`:
  - `feature/<short-topic>` or `fix/<short-topic>`
- Use clear commit messages. Conventional style (optional) helps reviewers:
  - `feat(toolbar): add monitoring indicator border`
  - `fix(options): correct scroll child height calc`
  - `docs(readme): add installation notes`

## Coding Guidelines
- Language: Lua 5.1 (WoW API).
- Keep changes minimal and focused; avoid refactors unrelated to your fix/feature.
- Respect existing style:
  - Preserve tabs/spaces as in surrounding code.
  - Avoid one‑letter variable names.
  - Do not add license headers.
  - Keep inline comments concise; prefer readable code over heavy commentary.
- UI: Favor themed frames via `addon:CreateThemedFrame` and register themed frames as needed.
- Tooltips: Provide plain text lines; the toolbar colors action verbs and ON/OFF tokens automatically.

## Testing Checklist
Before opening a PR, please verify:
- [ ] Addon loads without Lua errors (`/reload`).
- [ ] Main options open via `/hak options`; scrolling still works.
- [ ] Toolbar builds and icons behave as expected.
- [ ] New module options (if any) appear under the correct category and scroll correctly.
- [ ] No global UI font is changed (Morpheus is scoped to addon UI only).

## Documentation
- Update `README.md` if you add user‑visible features.
- Add/adjust `docs/Modules.md` for module behaviors or new options.
- Append changes to `CHANGELOG.md` under the Unreleased section.

## Pull Requests
- Describe the problem and solution with before/after notes or screenshots.
- Reference related issues (`Fixes #123`).
- Keep PRs small; large PRs are harder to review and merge.

## Reporting Issues
Provide:
- Steps to reproduce
- Expected vs. actual behavior
- Screenshots or error messages (Lua stack traces)
- Client details (Ascension build, other relevant addons if any)

Thanks for contributing!