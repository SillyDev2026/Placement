# Placement Grid — Roblox / Luau

A lightweight 100 × 100 placement occupancy grid backed by a 10,000-byte Luau `buffer`. Public construction, coordinate helpers, and occupancy APIs remain compatible with the previous module.

## Changes proposed in this patch

- Reuse methods on the module metatable instead of allocating a separate set of closures for every grid instance.
- Avoid writing 10,000 zero bytes during construction: `buffer.create` is guaranteed to zero-initialize memory.
- Use `buffer.fill` for a single-operation `Clear()`.
- Prevent out-of-bounds and fractional cell writes, including partial rectangular writes.
- Convert grid/world coordinates through the baseplate's `CFrame`, so rotated baseplates work while unrotated layouts retain their coordinates.
- Add Luau `--!strict` and argument/return annotations.
- Add Roblox Studio regression tests.

The fixed 8-stud cells and 100 × 100 grid are intentionally unchanged. This patch does **not** change inventory, networking, item ownership or authorization in the companion scripts.

## Setup

```text
ReplicatedStorage
└── Placement            (ModuleScript: contents of PlacementModule.lua)

ServerScriptService
└── PlacementServer      (Script)
StarterPlayerScripts
└── PlacementClient      (LocalScript)
```

**Dependency:** `PlacementClient.lua` and `PlacementServer.lua` also require a separate `ReplicatedStorage.Modules.Networking.Jolt` implementation and the expected `workspace.PlayerBases` hierarchy; that dependency is not included here.

```luau
local Placement = require(game.ReplicatedStorage.Placement)
local grid = Placement.new(workspace.Baseplate)
local x, z = grid:WorldToGrid(Vector3.new(0, 0, 0))
if grid:CanPlace(x, z, 2, 1) then
    grid:Occupy(x, z, 2, 1)
    local world = grid:GridToWorld(x, z)
    print("Placed at:", world)
end
grid:Free(x, z, 2, 1)
grid:Clear()
```

## API

| Method | Result |
| --- | --- |
| `Placement.new(basePart)` | Create new empty 100 × 100 grid |
| `WorldToGrid(point)` | Integer x/z cell indices in baseplate's local orientation |
| `GridToWorld(x,z)` | World position at the center of a cell on top of the baseplate |
| `IsCellEmpty(x,z)` | `false` for out-of-range cells, true for available |
| `SetCell(x,z,byte)` | Store byte 0–255, errors for invalid cells/values |
| `CanPlace(x,z,w,h)` | Validates rectangle and tests all covered cells |
| `Occupy(x,z,w,h)` | Fills cells; rejects invalid rectangle before writing |
| `Free(x,z,w,h)` | Clears cells; rejects invalid rectangle before writing |
| `Clear()` | Zeroes the whole buffer |

## Verification and profiling

In Studio, run `tests/PlacementRegression.server.lua` next to the module (adjust the require path if installed under ReplicatedStorage). Test valid/invalid cells, 100 × 100 boundaries, rotated baseplates, and large repeated allocations. Because this patch has not run against a live Roblox engine in this session, performance speedups and a clean Studio typecheck should be verified locally with **Script Analysis** and **Script Profiler**.

Authoritative Luau buffer behavior: https://luau.org/library/#buffer-library
