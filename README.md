# Placement — server-authoritative Roblox building system

A fixed-grid building prototype containing a Roblox **Placement** ModuleScript, server script, and client LocalScript. The companion UI supports Block, Machine, and Conveyor parts; the server owns the authoritative grid, part IDs, inventory counts and placement actions.

## Setup

```text
ReplicatedStorage
  Placement                   ModuleScript from PlacementModule.lua
  Modules
    Networking
      Jolt                    Required external network module (not bundled)

ServerScriptService
  PlacementServer             Script from PlacementServer.lua

StarterPlayer
  StarterPlayerScripts
    PlacementClient           LocalScript from PlacementClient.lua

Workspace
  PlayerBases
    <PlayerName>_Base
      BasePlate               Anchored BasePart
```

Both scripts expect the `Jolt.Server("PlacementEvent")` / `Jolt.Client("PlacementEvent")` API. The Jolt dependency is not in this repository, so installation requires an existing Jolt version with this interface.

## Security fixes

- Server validates action payloads, finite integer grid cells, footprint bounds and rotations.
- Only the preconfigured **Block (10)**, **Machine (5)** and **Conveyor (20)** items can be placed, with sizes verified against server-owned definitions.
- Requests are throttled to one accepted request per player per 0.08 seconds; Move/Remove batches are limited to 32.
- The server tracks owned parts by stable `PartId` instead of trusting client-supplied names or Instances.
- Remove operations transmit exact IDs, so selecting one of two identically named parts deletes the requested part.
- Rotated rectangular parts use rotated grid footprints. Their CFrames are centered over the occupied footprint and computed from the BasePlate's orientation.
- Move operations restore the original occupied cells on collision/failure; the server—not the client—destroys removed Instances.
- Existing `Place`, `Move`, `Remove` action names and `Jolt` event name remain supported. Server still accepts legacy `Remove({names = ...})` requests for older clients, but exact-ID removal is preferred.

### Compatibility and integration

The public `PlacementModule.lua` is **not modified in this PR**. The separate grid-correctness PR should be tested together with this server/client PR before publication. The main module uses a fixed 100 x 100 array and 8-stud cells. Ensure BasePlate dimensions match that grid (typically 800 x 800 studs). Changes to rotation/footprint centering can alter the placement position of pre-existing custom client UIs.

Client-side inventory display is advisory; this patch enforces the server counts, but does not yet synchronize the remaining stock UI back to the client, persist placed parts, or charge an economy. Those features require further authoritative server integration.

## Verification

1. Use a **two-player Studio server test**. Each player's base should allow the owner to place but never move or remove another player's part by guessing a PartId.
2. Place two Blocks, select only one, remove it, and ensure the other remains.
3. Place and rotate a Conveyor (0, 90, 180 and 270 degrees), move it near the edge, and confirm grid occupancy is released/restored correctly.
4. Try malicious RemoteEvent payloads: negative/fractional/NaN/infinite coordinates, unknown item names, thousands of batch entries, and invalid rotations. The server should ignore them without creating parts.
5. Place beyond the configured inventory count; server must deny the extra item. Confirm request rate limiting.
6. Run `tests/PlacementGridSmoke.server.lua` in Studio beside the `Placement` module.

**Luau validation:** The server is deliberately `--!nonstrict` while the external Jolt dependency and dynamic network values have not been fully typed. Run Script Analysis and performance profiling before declaring a strict-typecheck pass or speed improvement. Targeted validation and indexed IDs reduce risk/linear scans but require measurement for throughput claims.
