# VoidcoreAdvisor

VoidcoreAdvisor is a World of Warcraft addon for Retail (Patch 12.0.0+) that helps you make informed decisions when spending Nebulous Voidcores. It attaches a side panel to the Encounter Journal that displays the full loot pool for each raid boss or Mythic+ dungeon, broken down by specialization, alongside probability rankings that show which loot spec gives you the best odds of receiving the items you are after.

When you open the Encounter Journal and browse a boss or dungeon, VoidcoreAdvisor automatically shows every item available from that source. You can select specific items you are chasing, and the panel recalculates the probability for each of your specializations in real time, telling you the exact percentage chance that a Voidcore roll will land on one of your selected items for each spec. Specs with smaller remaining loot pools rank higher because each individual item has a greater share of the roll.

The addon tracks which items you have already obtained, either through manual checkboxes or through automatic detection after boss kills and Mythic+ completions. Obtained items are excluded from the remaining pool calculations, so your probability numbers stay accurate as you gear up over the course of a season. Item selections and obtained status are saved per character.

When you zone into a current-season Mythic or Mythic+ dungeon, VoidcoreAdvisor checks whether your active loot specialization is the best match for the items you have selected from that dungeon. If a different spec would give you better odds and you have at least one Nebulous Voidcore to spend, a dialog popup appears showing your current spec, the recommended spec with its probability stats, and offers to switch your loot specialization with a single click. The reminder only triggers once per dungeon and can be disabled in the addon settings.

## Key Features

- Side panel anchored to the Encounter Journal with loot and spec ranking columns.
- Per-spec probability calculation based on remaining loot pool size.
- Item selection to compare which spec gives the best odds for specific pieces.
- Automatic detection of items received via Nebulous Voidcores after encounters.
- Loot spec reminder popup when entering a Mythic+ dungeon on a suboptimal spec for your selected items.
- Support for both raid bosses (Normal, Heroic, Mythic) and Mythic+ dungeons.
- Adjustable key level selector for M+ that updates tooltip item levels to match the Voidcore reward track.
- Spec and item filtering with cross-column highlighting.
- Persistent per-character tracking of obtained items and selections.
- Localized in 11 languages: English, German, Spanish (EU/MX), French, Italian, Korean, Portuguese (BR), Russian, and Chinese (Simplified/Traditional).

### Dungeon Overview

When the Encounter Journal is open on the instance list, a separate overview panel appears listing all current-season Mythic+ dungeons sorted by the highest single-item chance across your specializations. Each row shows the best-matching spec icon and name, the number of items remaining for that spec, and the percentage chance per Voidcore roll. A two-row grid of equipment slot buttons (head, neck, shoulders, back, chest, wrists, hands, waist, legs, feet, finger, trinket, weapon, off-hand) lets you narrow the ranking to only the slot types you are targeting.

### Raid Overview

When the Encounter Journal is open on a raid's main page without a specific boss selected, a raid overview panel lists every boss in Encounter Journal order. Each row shows the best spec for that boss, items remaining, and the probability percentage — giving you a quick picture of which bosses are still worth rolling on and which spec to use for each.

### Options

VoidcoreAdvisor registers a settings page under Game Menu → Options → AddOns. From there you can enable or disable the loot spec reminder popup and preview the reminder dialog without having to enter a dungeon.

## Recent Changes (2.1.0)

### Scan Backup and Restore

- Before a Voidcache scan finalizes (both M+ and raid), all existing obtained entries for that content type are snapshotted into `db.obtainedBackup` in `SavedVariables`. The backup survives `/reload` and logout.
- M+ and raid backups are stored independently. Running an M+ scan does not overwrite the raid backup, and vice versa.
- A new `/vca restore` command rolls back `db.obtained` to the pre-scan snapshot and immediately refreshes all open panels. If no backup exists (no scan has ever completed), the command prints a clear message rather than silently doing nothing.
- Aborted scans (combat interrupt, manual cancel, or loot spec change) never modify `db.obtained`, so no backup is needed or taken for those cases — only a scan that runs to completion can overwrite existing data.

---

### Loot Pool Accuracy

- Loot pool reads are now performed exclusively under a verified `WithEJState` filter. Results are only cached when the filter application succeeds, preventing inflated or unfiltered pools from being stored.
- The display item list in the panel is always intersected with the trusted per-spec pool. An empty trusted pool renders "no items" rather than falling back to raw Encounter Journal data.
- When the EJ returns an empty enriched item list but the trusted per-spec pool is non-empty (a transient read gap), display rows are synthesized directly from the trusted item IDs so the panel never shows a false "No items for this spec" state.
- Item spec metadata that is incomplete at read time is no longer cached or persisted, preventing empty or partial results from poisoning the pool for the entire session.
- Added a class-level eligibility fallback for items whose spec-set data has no overlap with the player's class specs, fixing "No items for this spec" on raid bosses for some classes.
- Persisted cache entries from prior sessions are version-gated and automatically discarded when the format changes, so stale or poisoned pools from earlier runs do not carry over.

### Cache Warm

- Cache warmup is now split into two phases: a fast item metadata primer (populates the client item cache so spec info is available promptly) followed by the class/spec filter cache build.
- The warm ticker no longer has a fixed iteration limit, so EJ availability pauses no longer exhaust the budget and cancel the process prematurely.
- Tick interval increased from 0 seconds to 0.25 seconds (capped at roughly 4 items per second), eliminating the multi-second FPS drops that occurred at login.
- Warmup is deferred until the player is outside an instance. If the season filter cannot be built at login (EJ data not yet ready), the process retries automatically.
- The loot pool cache is persisted to `SavedVariables` between sessions so subsequent logins complete warmup much faster.

### Detection

- The Mythic+ key level is now captured at `CHALLENGE_MODE_START` and `CHALLENGE_MODE_COMPLETED` and persisted to `SavedVariables`, so the correct level is retained across `/reload` inside or immediately after a run.
- Dungeon identification now uses locale-independent instance IDs as the primary lookup, with a localized name lookup as fallback. This prevents misidentification for players using non-English clients.
- Detection and panel source state is cleared on zone transitions to prevent stale dungeon data from persisting after leaving an instance.

### UI

- The chance column in both the Dungeon Overview and Raid Overview is wider (64 px) and word-wrap is disabled on all column headers and row labels, fixing a layout shift that caused the header to appear truncated and shifted downward on some characters.
- The Options page now includes a Preview button next to the reminder toggle so you can inspect the popup appearance without entering a dungeon.
