-- VoidcoreAdvisor: Constants
-- All shared constants for the addon. Loaded first so every subsequent file can reference them.

local addonName, VCA = ...

VCA.ADDON_NAME     = addonName
VCA.VERSION        = "0.1.0"
VCA.SCHEMA_VERSION = 1
VCA.CHAR_DB_NAME   = "VoidcoreAdvisorCharDB"
VCA.GLOBAL_DB_NAME = "VoidcoreAdvisorDB"

-- ── Content types ─────────────────────────────────────────────────────────────
-- RAID:        A single raid boss encounter.  Uses encounterID as sourceID.
-- MYTHIC_PLUS: An entire M+ dungeon.          Uses EJ instanceID as sourceID.
VCA.ContentType = {
    RAID        = "RAID",
    MYTHIC_PLUS = "MYTHIC_PLUS",
}

-- ── Nebulous Voidcore costs ───────────────────────────────────────────────────
VCA.VoidcoreCost = {
    RAID        = 2,  -- raid bosses cost 2 Nebulous Voidcores
    MYTHIC_PLUS = 1,  -- M+ / Bountiful Delves / Prey Hunts cost 1
}

-- ── Encounter Journal difficulty IDs ─────────────────────────────────────────
VCA.Difficulty = {
    RAID_LFR       = 17,  -- not eligible for Voidcores
    RAID_NORMAL    = 14,
    RAID_HEROIC    = 15,
    RAID_MYTHIC    = 16,
    DUNGEON_NORMAL = 1,
    DUNGEON_HEROIC = 2,
    DUNGEON_MYTHIC = 23,  -- covers both Mythic and Mythic+ in the EJ
}

-- Raid difficulties that are eligible for Nebulous Voidcores.
VCA.EligibleRaidDifficulties = {
    [VCA.Difficulty.RAID_NORMAL] = true,
    [VCA.Difficulty.RAID_HEROIC] = true,
    [VCA.Difficulty.RAID_MYTHIC] = true,
}

-- The EJ difficulty used when reading M+ dungeon loot pools.
VCA.MythicPlusEJDifficulty = VCA.Difficulty.DUNGEON_MYTHIC

-- ── M+ tooltip bonus IDs (Myth 1/6 — Voidcore reward tier) ──────────────────
-- These IDs are injected into item links so tooltips render at the correct
-- item level for Nebulous Voidcore rewards from M+ dungeons.
VCA.MythicPlusBonusIDs = { 13440, 6652, 12699 }  -- shared M+ base bonus IDs
VCA.VoidcoreTrackBonusID = 12801                  -- Myth 1/6 track

-- ── M+ Great Vault reward data ────────────────────────────────────────────────
-- Maps each key level to its Great Vault reward upgrade track.
-- Track bonus IDs: Champion 12785-12790, Hero 12793-12798, Myth 12801-12806.
VCA.MythicPlusVaultRewards = {
    [2]  = { track = "Hero 1/6",  bonusID = 12793 },
    [3]  = { track = "Hero 1/6",  bonusID = 12793 },
    [4]  = { track = "Hero 2/6",  bonusID = 12794 },
    [5]  = { track = "Hero 2/6",  bonusID = 12794 },
    [6]  = { track = "Hero 3/6",  bonusID = 12795 },
    [7]  = { track = "Hero 4/6",  bonusID = 12796 },
    [8]  = { track = "Hero 4/6",  bonusID = 12796 },
    [9]  = { track = "Hero 4/6",  bonusID = 12796 },
    [10] = { track = "Myth 1/6",  bonusID = 12801 },
}
-- ── Nebulous Voidcore currency ─────────────────────────────────────────────
VCA.VOIDCORE_CURRENCY_ID = 3418  -- Nebulous Voidcore (Season 1)
-- ── Detection ─────────────────────────────────────────────────────────────────
-- How long (seconds) after a successful encounter the addon watches for loot
-- appearing in bags from a Voidcore bonus prompt.
VCA.DETECTION_WINDOW_SECONDS = 45
