# shupaz ForeverQuestLog

**shupaz ForeverQuestLog** is a World of Warcraft addon that restores the beloved standalone Classic dual-pane Quest Log window while decoupling it from the full-screen World Map. It also enhances the Objective Tracker with collapsible zone grouping and smooth scrolling.

---

## ✨ Features

- **Classic Dual-Pane Quest Log**:
  - Independent, movable, resizable, and standalone window.
  - Leaves your World Map unobstructed and non-intrusive.
  - Left pane displays all quests sorted by zone, campaign, or difficulty level with collapsible headers.
  - Right pane presents detailed quest objectives, descriptions, rewards, experience, and gold.
  - Complete with Abandon, Share, and Track buttons.

- **Enhanced Objective Tracker**:
  - **Zone Grouping**: Quests in your Objective Tracker are organized neatly under distinct Zone Headers.
  - **Collapsible Sections**: Click any zone header to collapse or expand its quests.
  - **Collapse / Expand All**: One-click master button on the Objective Tracker header to toggle all zones at once.
  - **Progress Counters**: Zone headers display completion count and total active quests (e.g. `(3/5)`).
  - **Smart Scrolling**: A sleek, non-intrusive scrollbar appears automatically when tracked quests exceed screen height. Scroll smoothly with your mouse wheel or drag the thumb.

- **Seamless Modern UI Integration**:
  - Full support for Key Down action triggers (`ActionButtonUseKeyDown`).
  - Integrated with the **Micro Menu** (Quest Log icon toggles the window directly).
  - Integrated with the **Addon Compartment** on the Minimap.
  - Default keyboard toggle bound to **L** (configurable in WoW Keybindings).

---

## ⌨️ Slash Commands

| Command | Description |
| :--- | :--- |
| `/fql` or `/questlog` | Toggle the Quest Log window. |
| `/fql opt` or `/fql config` | Open the addon settings panel. |
| `/fql tracker` | Toggle Objective Tracker zone grouping on or off. |
| `/fql reset` | Reset the Quest Log window position and scale to defaults. |
| `/fql scale <number>` | Set window scale directly (e.g. `/fql scale 1.1`). |
| `/fql fixmenu` | Re-register micro menu keydown bindings. |

---

## ⚙️ Configuration & Options

Access the settings panel via:
- Game Menu (`ESC`) > **Options** > **AddOns** > **shupaz ForeverQuestLog**
- Or type `/fql opt` in chat.

### Available Settings:
- **General**:
  - Window Scale slider (50% to 150%).
  - Remember window position & size across sessions.
  - Tooltips toggle.
- **Objective Tracker**:
  - Enable / Disable zone headers in the tracker.
  - Prioritize current zone (moves quests in your current zone to the top of the tracker).
  - Show zone quest count badges.
  - Tracker scale & font options.

---

## 📦 Manual Installation

1. Download the latest release `.zip` from [Releases](https://github.com/shupaz/Forever-Quest-Log/releases) or CurseForge.
2. Extract the `ForeverQuestLog` folder into your World of Warcraft directory:
   ```text
   World of Warcraft\_retail_\Interface\AddOns\
   ```
   *(or `_classic_` / `_classic_era_` / your client folder)*
3. Ensure the folder hierarchy is:
   ```text
   Interface\AddOns\ForeverQuestLog\
       ├── Bindings.xml
       ├── ForeverQuestLog.lua
       └── ForeverQuestLog.toc
   ```
4. Start World of Warcraft and make sure **shupaz ForeverQuestLog** is checked in your AddOn list.

---

## 📄 License

This project is licensed under the [MIT License](LICENSE).
