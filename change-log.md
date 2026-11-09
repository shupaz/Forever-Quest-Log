# Changelog — shupaz ForeverQuestLog

All notable changes to **shupaz ForeverQuestLog** are documented in this file.

---

## [v1.0.2] - 2026-04-19

### Added
- **Dedicated Copyable Wowhead URL Bar**: Added a full-width, high-contrast Wowhead URL bar (`Wowhead URL: https://www.wowhead.com/forever/quest=...`) with auto-highlight on hover/click and instant `Ctrl+C` copying.
- **Wowhead URL Bar Placement Setting**: Added a **Top | Bottom | Hidden** selector in AddOn Options (`Options -> AddOns -> shupaz ForeverQuestLog`), defaulting to **Hidden**.
- **Double-Click Quest to Show Map**: Double-clicking any quest in the Quest Log list now opens the World Map to that quest's zone (shortcut for the **Show Map** button).
- **Shift-Click Abandon to Clear All Quests**: Holding `Shift` and clicking the **Abandon** button now prompts to abandon **all** quests in your Quest Log.
- **Native UIPanel Placement & Small World Map Side-by-Side**:
  - Forever Quest Log now dynamically respects Blizzard's `UIPanelWindows` system—positioning at the default top-left slot (`16, -116`), sliding side-by-side next to narrow panels (`CharacterFrame`, `GossipFrame`, `QuestFrame`, `FriendsFrame`, etc.), and auto-closing when full-screen or wide panels open.
  - Clicking **Show Map** opens the World Map in its **small (windowed)** mode side-by-side with Forever Quest Log instead of closing the Quest Log.
  - Added **Lock to Default UIPanel Placement** option (enabled by default).
- **Game Menu & Settings Protection**: Blocked opening the Quest Log while `GameMenuFrame` or `SettingsPanel` is shown, and automatically closes the Quest Log when opening the Game Menu or Settings.

### Fixed
- **Fixed Quest Giver Gossip Dialog & Micro Menu Issues**:
  - Eliminated a 10Hz `QUEST_LOG_UPDATE` / `QuestCache` infinite refresh loop caused by `C_QuestLog.IsComplete()`, unconditional `ExpandQuestHeader(0)`, and unguarded `C_QuestLog.SetSelectedQuest()` calls.
  - Replaced all custom `_fql*` keys on Blizzard Objective Tracker frames, blocks, and FontStrings with weak-keyed private Lua state tables to prevent FrameXML taint.
  - Updated `QuestLogMicroButton` redirection to use standard `"LeftButtonUp", "RightButtonUp"` clicks without touching other Micro Menu buttons.
- **Removed `Bindings.xml`**: Replaced `Bindings.xml` (which triggered `Unrecognized XML: Binding` in `FrameXML.log` on WoW Forever `1.60.1`) with `SetOverrideBindingClick`.

### Changed
- **Dynamic Installed Font Discovery**: Replaced the hardcoded font list with dynamic discovery of fonts actually loaded and available in the user's client (`GetFonts()`, `GameFontNormal`, and `LibSharedMedia-3.0`), verified via `SetFont` probe and paired with mousewheel scrolling in the font dropdown.
- **Codebase Cleanup & Consolidation**:
  - Consolidated all shared constants, defaults, and utility functions (`SafeNum`, `SafeStr`, `IsSecret`, `CanChangeFrame`, Quest API wrappers) into `src/Utils.lua` and updated `.toc` load order so `Utils.lua` loads first.
  - Removed the inline position-toggle button from the Wowhead URL bar and the **Toggle Quest Log** button from AddOn Options.

---

## [v1.0.1] - 2026-04-19

### Changed
- Refactored the addon into a modular multi-file architecture under `src/` (`Init.lua`, `Utils.lua`, `Hooks.lua`, `QuestLog.lua`, `Tracker.lua`, `Options.lua`).
- Added CurseForge (`1788642`) and Wago (`kGr9Z7Ky`) project metadata to `shupaz_ForeverQuestLog.toc`.
- Updated `README.md` with modular architecture documentation, badges, and absolute image URLs for CurseForge and Wago compatibility.
- Added automated GitHub Actions release packaging workflow.

---

## [v1.0.0] - 2026-04-19

### Added
- **Standalone Classic Dual-Pane Quest Log Window**:
  - Left pane with collapsible zone headers, quest counts, difficulty-colored quest levels/tags (`[60D]`, `[60G]`, `[60R]`), real-time search box, and tracking checkmarks.
  - Right pane with Classic parchment styling, quest title, metadata, objectives, full description, rewards (choice, fixed, spells, XP, money), and usable quest item button.
  - Bottom action bar with **Abandon**, **Push Quest**, **Track**, **Track All / Untrack All**, **Show Map**, **Close**, and a drag-to-resize corner grip (`60%`–`160%`).
- **World Map Quest Log Removal**: Suppressed the embedded Quest Log on the retail World Map and redirected `L` (`TOGGLEQUESTLOG`) and the Quest Log Micro Menu button to Forever Quest Log.
- **Objective Tracker Enhancements**:
  - Collapsible zone headers (`[-]` / `[+]`) with active quest counts.
  - Current player zone priority sorting at the top of the tracker.
  - Custom tracker scale slider (`60%`–`160%`), custom font selector (with `LibSharedMedia-3.0` support), and mousewheel scrollbar.
- **AddOn Options Panel & Slash Commands**: Added Settings canvas category (`Options -> AddOns -> shupaz ForeverQuestLog`), Addon Compartment button, and `/fql` / `/questlog` slash commands.
