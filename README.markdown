# Threat

## Usage

Lazy Warrior

Create a macro to call `Threat()` or `/threat`:

    /threat

    # or

    /script Threat();

## Commands

`Threat` can be enabled or disabled and its operation inspected:

    /threat             Will attempt to do the best threat or dps for warrior.  Only Supports Prot and Fury right now.
    /threat debug       Toggle debug messages on/off
    /threat tank|dps|tankmode|dpsmode    Toggles between Tank/Defensive Stance and Battle/DPS stance.  Tank will use Tank abilities, DPS will use DPS
    /thread slam        Toggle Slams -- Disabled or now, Slam sucks

## Bugtracker

## Credit

Many of the boilerplate functions are taken directly from `Fury.lua` by Bhaerau
(http://www.vanilla-addons.com/dls/fury/).
Added to Base Threat from muellerj


## Notes
    Will stack sunders to 5 on elites, 3 on normals, will stop sundering if mob is low
    Will try to priorities Executes
    Cleave support if more than 1 mob in range, low priority
    Rage Dump Heroic Stike - Lowest Priority
