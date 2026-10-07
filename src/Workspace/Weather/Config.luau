--[=[
    WEATHER — CONFIGURATION

    Every number the weather system uses lives here so the whole thing can be retuned
    from one file.

    The weather is a port of Natural Disaster Survival's disaster set, rebuilt to run on
    THIS game's round map rather than on NDS's island. Nothing in here — or anywhere else
    under `Workspace.Weather` — reads `Workspace.NDS`, so the NDS folder can be moved to
    ReplicatedStorage or deleted outright without breaking the weather.
]=]

local Config = {
    ----------------------------------------------------------------------------
    -- MASTER SWITCHES
    ----------------------------------------------------------------------------

    --- Set to `false` to switch the weather off entirely. Nothing is spawned, no clocks run.
    Enabled = true,

    --[=[
        Print a line for every phase change (picked, building, running, cleared).

        Worth leaving on while you're tuning the event list — an event that silently does
        nothing looks identical to one that was never picked.
    ]=]
    Debug = true,

    ----------------------------------------------------------------------------
    -- WHEN THE WEATHER RUNS
    ----------------------------------------------------------------------------

    --[=[
        Seconds of calm after the round starts before the first event builds up.

        Long enough that the intro plays out and people find each other first — weather
        landing on frame one reads as a bug rather than as an event.
    ]=]
    FirstEventDelay = 25,

    --- Seconds of calm between one event ending and the next one building up.
    ---
    --- Rounds are last-one-standing and have no clock, so the weather CYCLES: as long as
    --- the round is still going, another event is always on its way.
    IntervalBetweenEvents = 35,

    --- Seconds of build-up (clouds, fog, the warning banner) before an event turns lethal.
    BuildupTime = 12,

    --- How long an event stays active once it starts, in seconds.
    ---
    --- Individual events may override this with their own `Duration`.
    DefaultDuration = 75,

    ----------------------------------------------------------------------------
    -- HOW MUCH WEATHER
    ----------------------------------------------------------------------------

    --- How many events run at once at the start of a round, with the machine switched off.
    BaseSimultaneousEvents = 1,

    --[=[
        Hard ceiling on simultaneous events, whatever the machine and the escalation say.

        Set to the full event count on purpose. A round that has gone on long enough to
        stack every event at once has earned it, and that pile-up is the thing that ends
        the round — see `Escalation` below.

        NINE, not eleven: removing the sandstorm and the blizzard took two events out of
        the pool, and leaving the ceiling above the pool size would have meant the last two
        escalation steps silently did nothing while the log still claimed they had.
    ]=]
    MaxSimultaneousEvents = 9,

    --[=[
        Whether weather ACCUMULATES instead of running in discrete batches.

        `true` treats the simultaneous count as a running TOTAL to be kept topped up: the
        round opens on one event, and every time the count earns another the runner adds
        one MORE on top of what is already blowing, rather than waiting for the current
        storm to finish and starting a fresh set. One becomes two becomes three, and the
        arena never gets a clean break in between.

        `false` restores the original behaviour — a batch runs, the arena clears, a calm
        gap passes, then the next (larger) batch starts.
    ]=]
    AccumulateEvents = true,

    ----------------------------------------------------------------------------
    -- ESCALATION — THE THING THAT ENDS A STALLED ROUND
    ----------------------------------------------------------------------------

    --[=[
        The longer a round runs, the worse the weather gets.

        This exists because the round has NO CLOCK. Last one standing means a final two who
        both refuse to engage can stand in opposite corners indefinitely, and there is no
        timer left to call it a draw. Rather than bolt a hidden timer back on, the ARENA
        becomes the pressure: every couple of minutes another event joins the pile, the gaps
        between them close, and the damage climbs. Eventually there is nowhere on the map
        that isn't being hit by something, and the round resolves itself.

        It's a soft deadline made of gameplay instead of a hard one made of a countdown.
        Nobody gets told the round is over — they get told to fight now or drown.
    ]=]
    Escalation = {
        Enabled = true,

        --[=[
            Seconds of round before escalation starts. Below this the weather is as tuned.

            These four numbers are calibrated together so the ramp lands where the table in
            WEATHER.md says it does — every event at once at around ten minutes, with the
            interval and the damage bottoming out well before that. Change one and the
            others stop lining up, so check that table if you retune.
        ]=]
        GracePeriod = 90,

        --- One extra simultaneous event per this many seconds past the grace period.
        SecondsPerExtraEvent = 50,

        --[=[
            The gap between batches shrinks from `IntervalBetweenEvents` towards this.

            This is what turns "weather happens sometimes" into "weather is happening",
            because a new batch starting before the last has finished is how events pile up
            past what `SecondsPerExtraEvent` alone would give you.
        ]=]
        MinInterval = 6,

        --- Seconds of round at which the interval has fully collapsed to `MinInterval`.
        --- Around 6:30 in, which is where storms start overlapping constantly.
        IntervalFloorAt = 390,

        --- Build-up shrinks from `BuildupTime` towards this, so late warnings are shorter.
        MinBuildup = 3,

        --[=[
            Extra damage at full escalation, as a fraction. `1` means double damage.

            Ramps in over `DamageRampAt` seconds. This matters more than the event count
            does for actually finishing a round: five events that each tickle will never
            kill a player who is paying attention.
        ]=]
        MaxDamageBonus = 1.25,
        DamageRampAt = 420,

        --[=[
            Seconds between "the storm is getting worse" banners.

            Escalation that nobody notices reads as the game being buggy — players need to
            know the pressure is deliberate and that it is going to keep going up.
        ]=]
        AnnounceEvery = 150,
    },

    ----------------------------------------------------------------------------
    -- WHERE THE WEATHER HAPPENS
    ----------------------------------------------------------------------------

    --[=[
        The name of the round map in the workspace.

        `MapManager` renames whatever it clones to exactly this, so the weather can find
        the arena without knowing which map was picked. This is the ONLY link between the
        weather and the rest of the game.
    ]=]
    MapName = "Map",

    --- Extra studs added to the arena's measured radius, so weather that comes in from
    --- off the edge (the tsunami, the tornado's approach) starts outside the geometry.
    ArenaPadding = 40,

    --- Fallback arena size used when the map can't be measured (no parts, or it's a single
    --- streamed-in model that hasn't loaded yet).
    FallbackRadius = 220,

    --- Studs above the arena's highest point that falling things spawn at.
    SkyHeight = 320,

    ----------------------------------------------------------------------------
    -- WHAT THE WEATHER IS ALLOWED TO TOUCH
    ----------------------------------------------------------------------------

    --[=[
        Whether the weather may break and fling the map's own parts.

        OFF by default, and that is a deliberate departure from NDS.

        In NDS the map being torn apart IS the game. Here the map is a fighting arena that
        has to stay standing and stay fair for the whole round — a tornado that removes the
        floor doesn't make the fight more interesting, it ends it. With this off the weather
        still hurts, blinds, shoves and sets fire to PLAYERS; it just leaves the geometry
        alone.

        Turn it on if you build maps meant to be destroyed. Anchored parts are never
        touched either way.
    ]=]
    DestroyMapParts = false,

    --- Parts carrying an attribute or child with this name are never moved, broken or
    --- recoloured, even with `DestroyMapParts` on. Same convention NDS used.
    KeepAnchoredMarker = "KeepAnchored",

    --- Upper bound on how many loose map parts a single event will gather in one pass.
    --- Keeps the per-frame cost flat on very large maps.
    MaxLoosePartsPerPass = 250,

    ----------------------------------------------------------------------------
    -- DAMAGE
    ----------------------------------------------------------------------------

    --[=[
        Multiplier applied to every point of weather damage.

        NDS numbers assume a 100 HP guest with no combat going on. Fighters here are
        already trading damage with each other, so the raw values land much harder than
        they did in the original — this scales the whole set at once.
    ]=]
    DamageMultiplier = 0.6,

    --- Weather does no damage during a fighter's spawn protection window.
    RespectSpawnProtection = true,

    ----------------------------------------------------------------------------
    -- THE WEATHER MACHINE
    ----------------------------------------------------------------------------

    Machine = {
        --- Name of the machine model to look for in the workspace. The model is optional —
        --- with no machine in the world the weather still runs at `BaseSimultaneousEvents`.
        ModelName = "WeatherMachine",

        --- Highest power level the machine can be charged to. Each level above zero adds
        --- one simultaneous event, up to `MaxSimultaneousEvents`.
        MaxPower = 9,

        --- Seconds a charge takes at the prompt.
        ChargeTime = 1.5,

        --- Power levels lost each time a round ends. `0` makes charge permanent.
        DrainPerRound = 1,

        --- Whether to add a ProximityPrompt so players can charge the machine by hand.
        AllowManualCharge = true,
    },

    ----------------------------------------------------------------------------
    -- AUDIO
    ----------------------------------------------------------------------------

    --[=[
        PLACEHOLDER SOUND IDS — swap these for your own.

        These are stock Roblox library assets picked to be roughly the right thing, and
        they are the one part of this system I can't verify from outside Studio: an id that
        has been taken down, made private, or was never an audio asset in the first place
        fails SILENTLY in Roblox. The sound object is created, `:Play()` is called, and
        nothing comes out. No error, no warning.

        So if an event looks right and sounds like nothing, this table is the first place
        to look. Every sound the weather plays comes from here — no event hardcodes an id —
        so replacing one is a single edit.
    ]=]
    Sounds = {
        --- Steady wind. Used by most of the storms as a bed.
        Wind = "rbxassetid://9112854440",
        --- Rain on the ground.
        Rain = "rbxassetid://9125402735",
        --- Deep ground rumble. Earthquake and the volcano waking up.
        Rumble = "rbxassetid://9125615803",
        --- Thunder crack.
        Thunder = "rbxassetid://1837122916",
        --- Impact / detonation. Meteors and lava bombs.
        Explosion = "rbxassetid://1836790319",
        --- Something heavy falling through air.
        Whoosh = "rbxassetid://9114365635",
        --- The tornado's roar, played from the funnel itself.
        TornadoRoar = "rbxassetid://5423148666",
        --- Fire burning.
        Fire = "rbxassetid://9119713951",
    },

    ----------------------------------------------------------------------------
    -- THE EVENT POOL
    ----------------------------------------------------------------------------

    --[=[
        Which events can be picked, by module name.

        Comment a line out to take that event out of rotation without deleting anything.
        The order here is irrelevant — picking is random.
    ]=]
    EnabledEvents = {
        --[[
            THE HEADLINERS.

            These four are the set the game is tuned around, and they are deliberately the
            four that look least alike: water rises from below, a funnel chases you across
            the floor, rocks fall from the sky, and the ground itself turns against you.
            Anything else in this list is a supporting act.
        ]]
        "FlashFlood",
        "Tornado",
        "MeteorShower",
        "VolcanicEruption",

        --[[
            THE SUPPORTING SET.

            Cheaper, shorter, and built to layer under the four above rather than carry a
            round on their own.
        ]]
        "ThunderStorm",
        "AcidRain",
        "Firestorm",
        "Earthquake",
        "Tsunami",

        --[[
            REMOVED: "Sandstorm" and "Blizzard".

            Both were blinding-weather events — a full-screen whiteout or dust-out with a
            vignette over the top — and they were the two that made a FIGHTING arena worst
            to fight in. Everything else here you can see coming and move away from; those
            two just took the screen away and left the fight to whoever guessed right.

            Their modules are gone, not commented out, so nothing can pick them by name.
            Flash Flood, Tornado, Meteor Shower and Volcanic Eruption are what replaced
            them, and the vignette they used now belongs to those.
        ]]
    },

    --- Never pick the same event twice in a row while there is more than one to choose from.
    AvoidRepeats = true,
}

return Config
