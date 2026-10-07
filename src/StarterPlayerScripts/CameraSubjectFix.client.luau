--[=[
    CAMERA SUBJECT FIX — BOOTSTRAP

    Starts `Miscellaneous/CameraSubjectManager` directly, without waiting for
    `PlayerInitter`.

    `PlayerInitter` requires every module under `PlayerScripts` in one loop and calls
    `Init()` on each, with no `pcall` around any of them. One module erroring or yielding
    forever takes out every module after it in that loop — and a camera that follows your
    body is not something that should be able to be knocked out by an unrelated UI script
    failing to load.

    So the camera gets its own entry point. `CameraSubjectManager:Init()` is idempotent
    (it early-returns on `self.Initialized`), so whichever of the two runs first wins and
    the other is a no-op.
]=]

-- `WaitForChild` rather than a direct index: this runs the instant `PlayerScripts` is
-- populated, and indexing a sibling that hasn't replicated yet throws.
local Miscellaneous = script.Parent:WaitForChild("Miscellaneous")
local Manager = require(Miscellaneous:WaitForChild("CameraSubjectManager"))

Manager:Init()
