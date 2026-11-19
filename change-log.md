# Changelog — shupaz ForeverQuestLog

All notable changes to **shupaz ForeverQuestLog** are documented in this file.

---

## [v1.0.12] - 2026-11-19

### Fixed
- **Objective Tracker Updates**: Reverted the per-frame `_lastHookTime` and `GetQuestZoneLookup()` caches in `src/Tracker.lua` so `ObjectiveTrackerFrame.Update` and `Update` hooks always run after `EndLayout` and quest-log lookups stay fresh mid-frame.
- **Completed Quest Display in Tracker**: Updated `ApplyBlockHeaderColor()` and `GetOverflowQuestObjectives()` in `src/Tracker.lua` so completed quests display `(Complete)` in green (and `(Failed)` in red for failed quests) on the tracker header, hide all objective steps (including `"Ready for turn-in"`), and compact the block height to just the title.

---

## [v1.0.11] - 2026-11-18

### Fixed
- **Objective Tracker & Equipment-Swap / Quest Turn-In Stutter**:
  - **Cached Font Enumeration (`GetTrackerFonts`)**: Cached `GetTrackerFonts()` in `src/Utils.lua` (`self._cachedTrackerFonts`) and added a `"DEFAULT"` fast-path in `GetTrackerFontPath()`, eliminating repeated `LibSharedMedia-3.0`, `_G.GetFonts()`, and `fontProbeFS:SetFont(...)` scans on every tracker layout.
  - **Item Info & Event Filtering**: Handled `GET_ITEM_INFO_RECEIVED` and `GROUP_ROSTER_UPDATE` in `src/Init.lua` to only refresh the Quest Log window when open (instead of rebuilding the Objective Tracker on gear swaps or roster changes), removed redundant `ZONE_CHANGED` subzone tracker refreshes, and split `PLAYER_REGEN_ENABLED` from `PLAYER_ENTERING_WORLD` so combat exit only refreshes deferred combat updates.
  - **Tracker Layout Deduplication**: Added per-frame (`GetTime()`) deduplication across `EndLayout`, `LayoutContents`, `Update`, and `ObjectiveTrackerFrame.Update` hooks in `src/Tracker.lua`, cached `GetQuestZoneLookup()` per frame, removed duplicate `ApplyTrackerStyle()` calls, added a `0.25` float tolerance to `ApplyFontToFontString()`, and guarded `SetHeight()` calls to avoid unnecessary layout re-dirtying.

---

## [v1.0.10] - 2026-11-18

### Fixed
- **Edit Mode / Secret-Aura Taint on Level-Up**: Removed direct `availableHeight = 100000` assignments and `MarkDirty()` / `Update(...)` / `ObjectiveTrackerFrame:UpdateHeight()` calls from `src/Tracker.lua` and deferred tracker refreshes during combat lockdown, preventing `GetAuraDataByIndex(): Auras cannot be accessed when secret while tainted by 'shupaz_ForeverQuestLog'` in `EditModeManager` when leveling up with mouse-anchored tooltip addons.
- **Elite, Group, Dungeon & Raid Quest Tags**: Updated `GetQuestTagDetails()` in `src/Utils.lua` to detect `tagInfo.isElite`, `tagID == 1` (Group/Elite as `+`), `tagID == 81` (Dungeon as `D`), and `tagID == 62/82/83` (Raid as `R`) with fallback tag names.
- **Homologated Blizzard-Style Quest Titles**: Updated `src/QuestLog.lua` and `src/Tracker.lua` so both the Quest Log and Objective Tracker (native and overflow blocks) consistently display `[level+]` / `[levelD]` / `[levelR]` prefixes and `(Elite)` / `(Dungeon)` / `(Raid)` tags matching Blizzard's `_forever_` layout, and fixed the `0` truthiness bug in `Tracker.lua` level resolution.

---

## [v1.0.9] - 2026-11-17

### Fixed
- **Forever Trivial Quest Range (`C_QuestLog.GetTrivialRange`)**: Updated `GetDifficultyColor()` in `src/Utils.lua` to query `C_QuestLog.GetTrivialRange()` first on the `_forever_` client (with fallback to `GetQuestGreenRange()` and the level formula), so green/gray quest difficulty thresholds match Forever's World Map tooltips (e.g. level 32 quests at player level 39).

---

## [v1.0.8] - 2026-11-17

### Added
- **Auto-Track Accepted Quests**: Newly accepted quests are now automatically tracked on `QUEST_ACCEPTED` (supporting both modern and legacy event payloads), with an **Auto-Track Accepted Quests** toggle under **Objective Tracker** settings (`autoTrackQuests = true` by default).
- **Full 40-Quest Tracking Bypass**: Bypassed Blizzard's 25-quest `C_QuestLog.AddQuestWatch` cap by storing all tracked quests in `shupazForeverQuestLogCharDB.trackedQuests` while keeping up to 25 native Blizzard watch slots active and automatically promoting overflow quests when native slots free up.
- **Overflow Objective Tracker Blocks**: Added pooled custom tracker blocks in `src/Tracker.lua` for tracked quests beyond slot 25, matching Blizzard's native font/size/shadow, `[level]` prefix, POI circle buttons (`POIButtonTemplate`), and `MenuUtil.CreateContextMenu` right-click menu (**Focus**, **Open Quest Details**, **Open Quest Map**, **Untrack**, **Abandon**).
- **Party Shared Quest Notation**: Displays a `(N)` count prefix in the Quest Log list and `Party on Quest (N): ...` in row hover tooltips when party members share a quest, with live updates on `UNIT_QUEST_LOG_CHANGED` for `party1`–`party4`.
- **Auto-Scroll Selected Quest into View**: Opening the Quest Log from the Objective Tracker (`OpenToQuest`) now automatically scrolls the quest list so the selected quest is visible.

### Fixed
- **Track All Completeness & Dirty Retry**: Updated `ToggleTrackAllQuests()` to iterate deterministically with a follow-up verification pass and `skipPromote` optimization when untracking all; updated `Tracker.lua` full-height retry/refresh paths to call `MarkDirty()` and `Update(..., 100000, true)`.
- **Multiline Wrapping Overlap**: Set explicit widths on overflow block headers and objective lines before measuring height (and recalculated on 9px scrollbar narrowing) so wrapped multiline quests no longer overlap.
- **Classic Quest Difficulty Colors**: Updated `GetDifficultyColor()` in `src/Utils.lua` to use the Classic/Forever green-range formula directly instead of `16001`'s Retail-scaled `GetQuestGreenRange`/`UnitQuestTrivialLevelRangeScaling`, matching World Map quest colors.

---

## [v1.0.7] - 2026-11-16

### Fixed
- **Quest Completion Status Detection**: Updated `GetLogEntryInfo()` in `src/Utils.lua` to check `info.readyForTurnIn` (with fallback to `C_QuestLog.ReadyForTurnIn` and `C_QuestLog.IsFailed`) when `info.isComplete` is `nil` on the modern 11.x `C_QuestLog.GetInfo()` API. Restores `(Complete)` and `(Failed)` indicators in the Quest Log list, quest detail pane, and Objective Tracker completion grouping/counts without triggering `QuestCache` query loops.

---

## [v1.0.6] - 2026-11-14

### Added
- **Objective Tracker Grouping & Sorting Modes**: Replaced the binary zone-grouping checkbox with a 6-mode **Grouping & Sorting** dropdown (`trackerSortMode`) in AddOn Options and `/fql tracker` cycling:
  - **Automatic**: Default zone grouping with **Current Zone First** priority and native quest order.
  - **Group by Zone**: Collapsible zone headers sorted alphabetically (`A–Z`), with quests ordered by level inside each zone (supports **Current Zone First**).
  - **Group by Completion Status**: Collapsible **Complete**, **In Progress**, and **Failed** headers, with quests ordered by level inside each group and full right-click group context menu support.
  - **List by Level**: Flat list without group headers, ordered by quest level ascending (Low to High).
  - **List by Level (High to Low)**: Flat list without group headers, ordered by quest level descending (High to Low).
  - **List Alphabetically**: Flat list without group headers, ordered `A–Z` by quest title.
- **Native Blizzard Dropdown Tooltip Formatting**: Styled the **Grouping & Sorting** tooltip with Blizzard's native white option labels (`|cffffffffLabel:|r`) and gold descriptions separated by paragraph spacing.

### Changed
- **Quest Log Always Grouped by Zone (A–Z) & Ordered by Level**: Updated `FQL:BuildStructuredLog()` so the standalone Quest Log always groups quests by zone header, sorts zone headers alphabetically (`A–Z`), and orders quests by level inside each zone.
- **Dynamic "Current Zone First" Availability**: Linked **Current Zone First** to **Grouping & Sorting** so it is enabled only when **Automatic** or **Group by Zone** is selected, and automatically greyed out for all other modes.

---

## [v1.0.5] - 2026-11-13

### Fixed
- **Quest Difficulty Color Calculation**: Bypassed Dragonflight retail content-scaling APIs (`GetQuestDifficultyColor` and `C_PlayerInfo`) that were overriding quest colors with uniform yellow/white. Quests in both the Quest Log and Objective Tracker now accurately compute their true Classic 5-tier difficulty colors relative to player level (Red, Orange, Yellow, Green, Grey).
- **Persistent Quest Title Colors on Mouseover**: Applied inline hex color formatting to Quest Log title FontStrings alongside `SetTextColor` so that button hover highlights and font object resets cannot clear difficulty colors back to default gold.
- **Tracker Zone Metadata & Standalone Coloring**: Ensured `level` and `difficultyLevel` are stored in the tracker zone lookup table, and enabled block header difficulty color coding even when **Group Quests by Zone** is disabled.

---

## [v1.0.4] - 2026-11-12

### Added
- **Dynamic Quest Title Wrapping**: Quest titles in the standalone Quest Log now automatically wrap into multi-line rows instead of cutting off with ellipses when long titles exceed row width.
- **Quest Difficulty Color-Coding in Quest Log**: Quest titles in the Quest Log list are now color-coded dynamically based on quest level difficulty relative to the player (Red, Orange, Yellow, Green, Grey), matching the Objective Tracker.
- **Real-Time Level-Up Color Updates**: Leveling up (`PLAYER_LEVEL_UP`) now immediately updates difficulty colors across both the Quest Log and the Objective Tracker without requiring a UI reload or zone change.
- **Independent Font Size Scaling**: Added dedicated Font Size sliders (80%–160%) for both the Quest Log Window and the Objective Tracker in AddOn Options, allowing players to scale text independently from overall window/frame scale.
- **Native Blizzard Settings UI Integration**:
  - Rebuilt the options panel with Blizzard's native `SettingsListTemplate` engine (`Settings.RegisterCanvasLayoutCategory`), embedding authentic Dragonflight / The War Within section headers, hover highlights, diamond slider tracks with steppers, and native dropdowns.
  - Reorganized settings into a clean hierarchy: **Quest Log Window**, **Objective Tracker**, and **World Map**.
  - Added Blizzard's native **Defaults** header button with hover tooltip and instant full-reset capability, and synchronized `/fql reset` to reset all settings and placement.

### Changed
- Reorganized options sections so **World Map** settings appear at the bottom.
- Removed legacy canvas implementation, obsolete zone expand/collapse buttons, and redundant window position reset button in favor of the unified Defaults reset.

---

## [v1.0.3] - 2026-11-10

### Fixed
- **Full 25-Quest Objective Tracker Capacity**: Restored the unlimited height budget pass (`ForceUnlimitedTrackerHeight` / `NeedsFullHeightRetry`) using the zero-taint `TState` table so `QuestObjectiveTracker` builds blocks for all tracked quests (up to 25) instead of truncating after ~14 quests when screen `availableHeight` is reached.

---

## [v1.0.2] - 2026-11-09

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

## [v1.0.1] - 2026-11-08

### Changed
- Refactored the addon into a modular multi-file architecture under `src/` (`Init.lua`, `Utils.lua`, `Hooks.lua`, `QuestLog.lua`, `Tracker.lua`, `Options.lua`).
- Added CurseForge (`1788642`) and Wago (`kGr9Z7Ky`) project metadata to `shupaz_ForeverQuestLog.toc`.
- Updated `README.md` with modular architecture documentation, badges, and absolute image URLs for CurseForge and Wago compatibility.
- Added automated GitHub Actions release packaging workflow.

---

## [v1.0.0] - 2026-11-06

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
