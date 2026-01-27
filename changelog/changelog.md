# Changelog

All notable changes to this project will be documented in this file.

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