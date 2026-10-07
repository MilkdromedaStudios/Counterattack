# Weather

Natural Disaster Survival's disaster set, rebuilt to run on **your round map** during a
Counterattack round.

Everything lives in **`src/Workspace/Weather`** and syncs to `Workspace.Weather`. It is
self-contained: nothing in it reads `Workspace.NDS`, so that folder can be moved to
ReplicatedStorage or deleted outright and the weather keeps working.

---

## The loop

A round starts → 25 seconds of calm → a batch of events is chosen → a warning banner and a
build-up → the weather runs → it clears → a gap → the next batch.

## Escalation — the weather *is* the round timer

Rounds are last-one-standing with **no clock**. Nothing calls a draw, so a final two who
both refuse to engage would stand in opposite corners of the map forever.

Rather than bolt a hidden countdown back on, the arena is the deadline. Past
`Escalation.GracePeriod` (90s) every part of the loop turns up:

| Time in | Events per batch | Gap | Warning | Damage |
|---|---|---|---|---|
| 0:00 – 1:30 | 1 | 35s | 12s | ×1.00 |
| 2:00 | 2 | 32s | 11s | ×1.09 |
| 4:00 | 5 | 21s | 8s | ×1.45 |
| 6:30 | 8 | 6s | 3s | ×1.89 |
| 8:30 | **9 — everything** | 6s | 3s | ×2.25 |
| 10:00+ | **9 — everything** | 6s | 3s | ×2.25 |

Those are batch figures. Once the gap is shorter than an event's duration the batches
**overlap**, so the number actually running at any moment is higher than the column says.

Four dials move together, all in `Config.Escalation`:

- **Count** — one more event every `SecondsPerExtraEvent` (50s), capped only by
  `MaxSimultaneousEvents`, which is set to the whole list
- **Interval** — collapses from 35s to `MinInterval` (6s) by 6:30; that overlap is what
  pushes the pile past what the count alone would give
- **Build-up** — shortens from 12s to `MinBuildup` (3s), so late warnings are barely warnings
- **Damage** — climbs to `1 + MaxDamageBonus` (2.25×) by 8:30

Left long enough that's eleven simultaneous events at double damage over a map with nowhere
left to stand, and the round resolves itself. **That's the intent, not a failure mode** — a
soft deadline made of gameplay instead of a hard one made of a countdown. Nobody gets told
the round is over; they get a banner reading THE STORM IS GETTING WORSE and told to finish
it.

Set `Escalation.Enabled = false` for flat weather that never ramps.

One event never runs twice at once, however deep the pile gets — the runner tracks what's
live and picks around it, because two copies of the same event would share the module's
state and fight over the client-side fog.

## The nine events

Four of them carry the system. They are deliberately the four that look least alike —
water rises from below, a funnel chases you across the floor, rock falls from the sky, and
the ground itself turns against you — and each one asks you to move somewhere different.

| Headliner | What it does | How you survive it |
|---|---|---|
| **Flash Flood** | The water level rises until only the high ground is dry | Get high and stay there |
| **Tornado** | A funnel wanders the arena, dragging people into orbit | Stay out of its path |
| **Meteor Shower** | Rocks fall and detonate where they land | Get something solid over your head |
| **Volcanic Eruption** | A cone rises at the arena edge and throws lava | Watch for the shadow before it lands |

The rest are shorter and cheaper, and exist to layer *under* the four above rather than to
carry a round on their own.

| Supporting | What it does | How you survive it |
|---|---|---|
| **Thunder Storm** | Lightning strikes the highest thing near it | Stay off rooftops and out of the open |
| **Acid Rain** | Rain that burns anything it lands on | Stay under a roof |
| **Firestorm** | Fires start and spread outward | Don't let them corner you |
| **Earthquake** | Telegraphed fissures open in the floor | Watch what's under your feet |
| **Tsunami** | One wave crosses the whole arena | Climb above the crest |

### Removed: the blizzard and the sandstorm

Both were **blinding** weather — a full-screen whiteout or dust-out with a heavy vignette
over the top — and in a fighting arena that is the worst thing weather can do. Everything
in the tables above you can see coming and move away from. Those two just took the screen
away and handed the fight to whoever guessed right.

The modules are deleted rather than commented out, so nothing can pick them by name. The
blizzard's `WeatherExposure` attribute and its nine-ray exposure check are gone with it,
and so are the `Snow` and `Sand` particle presets on the client.

What they *did* own worth keeping was the screen-edge vignette, and that now belongs to the
four headliners — `Water`, `Dust`, `Ember` and `Ash`, defined in `WeatherHUD.Vignettes`.
Every one of those tops out at **0.5 transparency**: enough to tell you something is
happening at the edges of the world, never enough to stop you seeing, aiming or fighting
through it.

Nothing has to be authored for this — the map's own geometry is the answer, so "find
shelter" works on any arena you build. Your screen ices over as you step into the open and
clears as you find cover, so you can see it working.

---

## The weather machine

`Workspace.Weather.Machine` looks for a Model named **`WeatherMachine`** anywhere in the
Workspace (or anything tagged `WeatherMachine` with CollectionService), and wires up
whatever it finds. Every part of the machine is optional — a screen, `Tube1`/`Tube2`, an
`EngineColor` part, a `Stacks` folder of ParticleEmitters, a `Globe` with
`SpinningRing…` parts, a `PowerUpSound`. Whatever's there lights up; whatever isn't is
ignored.

**Charging it adds one simultaneous event per power level**, up to
`Config.MaxSimultaneousEvents` (4 by default). It drains one level at the end of each
round. Players charge it at a ProximityPrompt the script adds automatically.

With no machine in the world at all, the weather still runs — just one event at a time.

### Why the old one did nothing

The NDS machine shipped with two scripts, and both open with a run of mandatory
`WaitForChild` calls:

```lua
local powerLevelTag = sp:WaitForChild('PowerLevel')
local screenFrame  = sp:WaitForChild('Screen'):WaitForChild('SurfaceGui'):WaitForChild('TextLabelFull')
local emitter1     = sp:WaitForChild('Stacks'):WaitForChild('Union1'):WaitForChild('ParticleEmitter')
```

The machine model in this repo is a stub — a Globe and two scripts — so the first
`WaitForChild` never returns. No error, no warning; the script just parks on that line
forever and never reaches anything that would make the machine do something. On top of
that, the `PowerLevel` it managed was only ever read by NDS's `MainScript`, which isn't
running here, so even a fully-built machine would have had no effect on this game.

The new script disables those two legacy scripts if it finds them, and publishes power as
`workspace:GetAttribute("WeatherPower")` — which the runner actually reads.

**To test without a machine:** set the attribute directly from the command bar.

```lua
workspace:SetAttribute("WeatherPower", 3)   -- four events at once next cycle
```

---

## Where the weather happens

`Workspace.Weather.Arena` measures **`workspace.Map`** — the map `MapManager` puts up for
the round — every time an event starts, and every event positions itself relative to that
centre, radius and floor height.

This is the part that had to change most from NDS. That game hardcoded its world: a 200
stud radius around the origin, an `Island` model, a `Structure` folder, a `WeatherDome`.
Pointed at this game unmodified, every disaster would run at world origin — which for most
maps is empty sky.

Everything the weather spawns goes into a `WeatherEffects` folder **inside the map**, so
the map's teardown at the end of a round cleans up after it automatically. (That folder is
excluded from the measurement, or a tsunami's 2000-stud wall would make the next event
think the arena had grown.)

---

## Configuration

All of it is in **`src/Workspace/Weather/Config.luau`**. The ones you're most likely to
touch:

| Setting | Default | What it does |
|---|---|---|
| `Enabled` | `true` | Master switch |
| `Debug` | `true` | Prints every phase change to the output |
| `FirstEventDelay` | `25` | Seconds of calm at the start of a round |
| `IntervalBetweenEvents` | `35` | Seconds of calm between events, before escalation |
| `BuildupTime` | `12` | Seconds of warning before an event turns lethal, before escalation |
| `DefaultDuration` | `75` | How long an event runs, unless it overrides it |
| `MaxSimultaneousEvents` | `9` | Ceiling on concurrent events — the whole list |
| `Escalation.Enabled` | `true` | The ramp described above. `false` for flat weather |
| `Escalation.GracePeriod` | `90` | Seconds before the ramp starts |
| `Escalation.SecondsPerExtraEvent` | `50` | How fast the pile grows |
| `Escalation.MaxDamageBonus` | `1.25` | Extra damage at full ramp (`1.25` = 2.25×) |
| `DamageMultiplier` | `0.6` | Scales all weather damage at once |
| **`DestroyMapParts`** | **`false`** | Whether weather may break and fling the map itself |
| `EnabledEvents` | all 9 | Comment a line out to take one out of rotation |

### `DestroyMapParts` is off, and that's a deliberate departure from NDS

In NDS the map falling apart *is* the game, and the map is disposable. Here the map is a
fighting arena that has to stay standing and stay fair for the whole round — a tornado that
removes the floor doesn't make the fight more interesting, it ends it.

With it off, the weather still hurts, blinds, shoves and sets fire to **players**; it just
leaves the geometry alone. Turn it on if you build maps meant to be destroyed. Anchored
parts, and anything with a `KeepAnchored` child or attribute, are never touched either way.

---

## Sounds

Every sound the weather plays comes from `Config.Sounds` — no event hardcodes an asset id,
so swapping one is a single edit.

**Treat the ids in there as placeholders.** They're stock library assets picked to be
roughly the right thing, and they are the one part of this system that can't be verified
from outside Studio: an id that has been taken down, made private, or was never audio in
the first place fails **silently** in Roblox. The Sound is created, `:Play()` is called,
and nothing comes out — no error, no warning. If an event looks right and sounds like
nothing, that table is the first place to look.

---

## Adding an event

Drop a ModuleScript in `src/Workspace/Weather/Events` and add its name to
`Config.EnabledEvents`. The shape is:

```lua
return {
    Name = "Hailstorm",
    Warning = "HAILSTORM",
    Hint = "Find a roof.",
    Duration = 60,                       -- optional; falls back to Config.DefaultDuration

    Buildup = function(Context) end,     -- optional: fog, sound, the warning look
    Run = function(Context) end,         -- required: loop on `Context:Wait(dt)`
    Cleanup = function(Context) end,     -- optional: `Context:ClearVisuals(seconds)`
}
```

`Context` is the only thing an event may touch, and it is what makes cleanup total — an
event cannot spawn anything the context doesn't know about, so a `Run` that throws halfway
still leaves the arena clean.

| Call | What it gives you |
|---|---|
| `Context.Region` | `Center`, `Radius`, `GroundY`, `TopY`, `SkyY`, `Map` |
| `Context:Wait(dt)` | `task.wait` that returns `false` once the event must stop |
| `Context:Part(props, lifetime?)` | A part, already parented and already tracked for cleanup |
| `Context:Sound(id, volume?, at?, pitch?)` | A one-shot sound |
| `Context:RandomPoint(scale?)` / `:RandomSkyPoint()` | Somewhere on / above the arena |
| `Context:GroundAt(pos)` | Drops a ray to find the floor |
| `Context:Raycast(from, dir, len, ignore?)` | Raycast that ignores the weather's own parts |
| `Context:Fighters()` | Every alive fighter inside the arena |
| `Context:Damage(char, amount)` | Weather damage, respecting spawn protection |
| `Context:Shove(char, velocity)` | Push somebody |
| `Context:Announce(title, hint?)` | Warning banner on every screen |
| `Context:SetVisuals(state)` / `:ClearVisuals(fade)` | Fog, tint, particles, shake, vignette |
| `Context:LooseParts()` | Map parts you may fling — empty unless `DestroyMapParts` |

Write every loop as `while Context:Wait(dt) do … end`. That is what guarantees an event
can't outlive the round it belongs to.

---

## Client side

`src/StarterPlayerScripts/UI/WeatherHUD.luau` owns the warning banner, the fog and tint,
the rain/dust/embers blowing past the camera, the screen-edge vignette, the screen shake
and the lightning flash. It's built entirely in code — there are no Studio prefabs to copy.

The lighting is applied on the **client**, not the server. `Modules.Lighting` hands each
client its own copy of the map's lighting on spawn and resets it between rounds; a server
writing `FogEnd` on top of that is two owners fighting over one property, and the loser
leaves somebody permanently fogged in. The HUD snapshots lighting before the first event,
blends whatever is running on top, and restores the snapshot when the last one clears.
