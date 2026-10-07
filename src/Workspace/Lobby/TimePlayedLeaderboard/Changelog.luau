--[[

Changelog Time Played Leaderboard with Player Thumbnails
By DelzDev (@RenanMSV) - Since 2020

## V1.2.0 - 2026-08-12

[✓] Added changelog
[✓] Added option to try to adjust the 1st place avatar to not be floating in the air.
  You can disable this in the Settings if its not working for you.
[✓] Added Ignored Players list to hide players from the board.
[✓] Added replication to optimize caching, loading times and reduce datastore usage
  when using multiple boards. Some of the settings are now shared between all boards,
  such as update cooldown.
[✓] Improved the logic where it could cause the leaderboard to break.


## V1.1.0 - 2025-03-13

[✓] Now the model has a modern style.
[✓] Supports showing the avatar of the player in 1st place
  (optional, disable it in the Settings file).
[✓] Supports for having multiple boards in the same map.
[✓] Now caching the data so its faster when updating the board.
[✓] Fixed a problem that made the leaderstats not work.
  Will now create the leaderstats, if USE_LEADERSTATS enabled,
  but only if it does not find one in at least 8 seconds after the player joining.
[✓] Fixed an error when test players with ids lower than 0 were in the top 10.
[✓] Improved the script in general.


## V1.0.0 - 2020-07-15

[✓] First release.

]]
