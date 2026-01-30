# Changelog

All notable changes to this project will be documented in this file.


## [0.3.0] – 2026-01-30
### Added
- Private pre-check output while the group is still incomplete.
- Automatic public posting to instance chat once the group becomes full (5/5).
- Support for running `/gc check` while solo, showing a local preview of available utilities.
- Clear warning output when critical utilities are missing (BattleRes, Bloodlust).

### Changed
- GroupCheck now distinguishes between private and public output:
  - Before the group is full, results are shown locally only.
  - Once the group is full, results are posted publicly to the instance chat.
- Instance chat is preferred automatically in dungeon and Mythic+ groups.
- Output lines for BattleRes and Bloodlust are only shown when the utility is actually available.
- Addon branding updated to “M+ GroupCheck”.

### Fixed
- Chat errors caused by invalid escape sequences in warning messages.
- Redundant output of unavailable utilities (e.g. “Available Bloodlust: no”).

## [0.2.0] – 2026-01-27
### Added
- Configurable settings panel using the Retail 12.0+ Settings API.
- Options to enable or disable individual output lines:
  - Battle Resurrection check
  - Bloodlust/Heroism check
  - Class stacking check
  - Header display
- Manual slash command `/gc check` to preview the current group analysis.
- Slash command `/gc config` to open the addon settings directly.
- Support for Paladin Battle Resurrection (Intercession) introduced in The War Within.

### Changed
- Group summary is now posted only when a new player joins the party.
- Automatic chat output is restricted to the group leader.
- Output format updated to a clear, multi-line summary.

### Fixed
- Compatibility issues with Retail 12.0 interface changes.
- Chat errors caused by invalid escape characters.
- Tooltip API incompatibilities in the settings panel.

## [0.1.1] – 2026-01-26
### Added
- Added paladin to the list of combatres

## [0.1.0] – 2026-01-25
### Added
- Initial addon structure for Retail WoW (12.0+).
- Automatic group analysis when a new player joins the party.
- Detection of available Battle Resurrection options based on group classes.
- Detection of available Bloodlust/Heroism effects.
- Class stacking detection with detailed output (e.g. "2 Druids").
- Formatted multi-line party chat output with a clear GroupCheck header.
- Group leader restriction: addon only posts messages if the player is the party leader.
- Slash command `/gc check` for manual testing of the group summary.
- Anti-spam protection to prevent duplicate messages on rapid roster updates.