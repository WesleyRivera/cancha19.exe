# Cancha 19 — Visual Prototype

This folder is an isolated visual-development track. It must not replace or modify the playable game in the repository root.

## Goal

Build and evaluate one compact, believable Brazilian hillside-favela five-a-side pitch before integrating any visual changes into the main game.

## Visual target

- Dense, irregular hillside housing with varied footprints, heights, rooflines and setbacks.
- Individually readable facades: exposed brick, worn plaster, painted concrete, corrugated roofing, balconies, doors and windows.
- Layered depth behind the pitch, with stairs, retaining walls, cables, laundry, small trees and utility details.
- Artificial turf with convincing fibers/wear, painted markings, metal fencing and goals with nets.
- Dusk/night lighting with warm window interiors, cool ambient sky and controlled floodlights.
- A broadcast-style camera composition that keeps the pitch readable while showing the neighborhood.

## Technical constraints

- Existing game project uses Godot 4.4 and GL Compatibility.
- Target the user's Intel Iris Xe integrated graphics; test at 1280x720 and scale quality down if needed.
- Prefer imported, optimized glTF/GLB assets and reusable materials over generating every visible object from primitive meshes.
- Use texture atlases, shared materials, mesh instancing and sensible LOD/culling where appropriate.
- Do not switch renderers or change the main project settings until a separate test demonstrates a clear benefit and compatibility.

## Acceptance gate

Do not integrate this prototype into the game until:
1. A screenshot from the actual Godot scene has a convincing architectural silhouette and material detail.
2. No major buildings read as plain boxes at the target camera distance.
3. The pitch, goals, fencing and lighting read as one coherent environment.
4. The scene runs acceptably on the target laptop.
5. Imported asset licenses and attribution requirements are recorded.

## Safety of the existing project

The current game remains unchanged on this branch. All experiments belong under this folder until explicitly reviewed.
