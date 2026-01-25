# Changelog

All notable changes to this project will be documented in this file.

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