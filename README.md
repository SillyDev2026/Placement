# Roblox Placement — safety and grid handling

This is a Roblox Studio demo that uses a shared grid module, a Jolt networking dependency, a client UI, and a server-authoritative object catalog.

## Installation

- Put `PlacementModule.lua` in **ReplicatedStorage** as a ModuleScript named `Placement`.
- Put `PlacementServer.lua` in **ServerScriptService**.
- Put `PlacementClient.lua` in **StarterPlayerScripts**.
- Provide `ReplicatedStorage.Modules.Networking.Jolt` and player bases named `<PlayerName>_Base` with a `BasePlate` BasePart.
- To run the independent grid tests, place a Script named `PlacementGridRegression.server.lua` next to a ModuleScript named `PlacementModule` in ServerScriptService.

## October 2026 changes

- Grid operations reject fractional, non-finite, negative, and out-of-range coordinates, preventing invalid buffer reads/writes.
- New buffers are already zero-initialized, so the 10,000-write constructor loop was removed; `Clear()` uses `buffer.fill`.
- The server validates placement item names, dimensions, rotations, grid bounds, and per-item demo quotas rather than trusting client supplied sizes.
- The server indexes placed objects by server-generated `PartId` for constant-time move/remove lookup, and sends removal IDs to the client.
- Rotated rectangular objects use the effective grid footprint, and centered world positions use that footprint.
- The client uses the same rotation-aware placement preview and sends stable IDs for removal rather than ambiguous duplicate names.
- Placed object grid origin and footprint are stored as attributes to avoid guessing their grid origin from their center position.
- Input batches are capped at 64 operations.

## Important

This is still a **demo**, not a production inventory system. Replace the server catalog's hard-coded counts with ownership/entitlement checks backed by your actual player data. The current demo doesn't persist placed objects across sessions. The Jolt dependency and Roblox Studio runtime are required to execute client/server integration tests.

Existing client/server deployments should update **all three Lua files together**, as the removal acknowledgment now uses IDs and names. The independent `tests/PlacementGridRegression.server.lua` is provided but has not been executed in Studio here.
