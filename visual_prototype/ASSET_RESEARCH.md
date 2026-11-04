# Asset research — visual prototype

This is a shortlist for evaluation, not a record of assets already imported.

## Verified source for PBR materials and general props

- [Poly Haven](https://polyhaven.com/) — public library of PBR materials, HDRIs and 3D models.
- [Poly Haven license](https://polyhaven.com/license) — Poly Haven states that its assets are CC0, can be used commercially, redistributed, and do not require attribution.
- [Poly Haven models](https://polyhaven.com/models)
- [Poly Haven textures](https://polyhaven.com/textures)
- [Poly Haven HDRIs](https://polyhaven.com/hdris)

Useful material categories: concrete, brick, plaster, corrugated metal, rusty metal, asphalt, painted surfaces and wood. For the first Intel Iris Xe test, start with 1K–2K textures rather than maximum resolution. Keep only the maps needed by each material.

Poly Haven has strong materials, lighting and general-purpose props. It is not a ready-made Brazilian favela environment.

## Favela architecture candidates (not yet approved)

- [Street Scene Rio Favela — Finley Searle](https://sketchfab.com/3d-models/street-scene-rio-favela-9631e0bae22343db82c44fe243af7c15) — candidate previously identified as downloadable and CC BY. Its current download availability, license, textures and quality have not been independently verified in this review.
- [Favela brasileira 2 — iagoArt3D](https://sketchfab.com/3d-models/favela-brasileira-2-c87942d7d3ba43648920c7f7cd451afc) — candidate previously identified as CC BY. Visual quality and suitability are not verified.
- [Favela street — Buncic](https://sketchfab.com/3d-models/favela-street-306d29a9905a4c62acad68631975dfde) — previously described as a low-poly set. Not selected.

## Import format and performance

Godot supports glTF 2.0, including .gltf and binary .glb. See [Godot 3D formats](https://docs.godotengine.org/en/4.3/tutorials/assets_pipeline/importing_3d_scenes/available_formats.html).

For imported static environment models:
- Prefer GLB/glTF with PBR materials and textures included or supplied alongside the model.
- Enable mesh LOD generation where useful.
- Use shared materials and repeated mesh instances for repeated props.
- Keep distant background buildings simpler than foreground buildings.
- Avoid excessive transparent materials.
- Evaluate at 1280x720 on the target laptop before increasing texture sizes or lighting complexity.

References:
- [Godot 3D performance optimization](https://docs.godotengine.org/en/latest/tutorials/performance/optimizing_3d_performance.html)
- [Godot 3D import configuration](https://docs.godotengine.org/en/latest/tutorials/assets_pipeline/importing_3d_scenes/import_configuration.html)

## Acceptance checklist for each asset

1. Confirm the exact license on the asset's own page and save author/source information.
2. Do not use CC BY-NC assets in a project that may later be commercial.
3. Inspect the downloaded file, textures, scale, normals, UVs, polygon count and import compatibility.
4. Reject models that look generic at the intended broadcast-camera distance.
5. Record each accepted asset, creator, source URL, license and required attribution.

## Current decision

No third-party model has been imported yet. Architecture is the main visual risk and must be inspected before selecting a final direction. The GitHub file-editing connection can create and update text files, but cannot upload binary model/texture files; those assets must be brought into the Godot project separately.
