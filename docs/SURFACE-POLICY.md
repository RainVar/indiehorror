# Stable surfaces and texture sampling

## Priority rule

Opaque architectural boxes have one shared layer policy in `scripts/surface_builder.gd`:

| Layer | Material role |
| --- | --- |
| 0 | Exterior concrete / foundation |
| 10 | Plaster / mold |
| 20 | Wood surfaces and imported furnishings |
| 30 | Dark wood trim |
| 40 | Tile finish |
| 50 | Woven rugs / cloth |
| 60 | Capiz panels |
| 70–90 | Paper, fixtures, metal and dark details |
| 100 | Salt and emissive details |

For same-facing coplanar architectural surfaces, the higher layer owns the overlap. Equal layers use stable creation order (earlier wins). `add_box` also accepts an explicit layer for future exceptions. Comparisons use a 0.1 mm tolerance, not a camera-dependent offset.

This is enforced by geometry, not just draw order. At house construction, the builder clips the losing rectangle out of each box face, removes buried/interior faces and combines the surviving polygons by material. The depth buffer never sees two competing architectural faces at the same point. Colliders retain the original dimensions; floor height and walkable thresholds do not change. Work happens once at startup, not per frame.

All world materials also receive the corresponding render priority. They remain opaque and depth-tested. A high-priority paper cannot appear through a nearer wall. Render priority alone is not a general cure for opaque z-fighting, so it is supplementary, not the primary fix. See [Godot's material documentation](https://docs.godotengine.org/en/stable/classes/class_material.html) and [depth-buffer limitations](https://docs.godotengine.org/en/stable/tutorials/3d/3d_rendering_limitations.html).

## Intentional overlays and moving geometry

- Floor finishes have an 8 mm base clearance; the main wood/concrete floor footprints do not overlap.
- Paper ink is separated from the sheet instead of sitting only 1 mm above it.
- Window frame rails and stiles now meet edge-to-edge; their front faces no longer overlap.
- Window latches sit clear of the frame through their rotation.
- Clock markings and the two moving hands have separate depth planes.

The box surface builder supports axis-aligned and quarter-turn static architecture. It intentionally does not clip a moving door against a wall or a hidden salt line against the floor: doing that would create holes when the object moves or hides. Moving parts and imported GLB meshes still require correctly authored geometry and adequate separation. No blanket transparent-material or disabled-depth-test workaround is used.

## Texture shimmer

The eight repeating world textures and the portrait now import actual mipmaps. Previously their materials requested mipmapping but the imports disabled generation. Nearest-with-mipmaps filtering retains the close-up pixel-art feel while reducing distant sampling shimmer; see [Godot's texture filtering definitions](https://docs.godotengine.org/en/stable/classes/class_basematerial3d.html#enum-basematerial3d-texturefilter).

World-space triplanar coordinates keep texel scale consistent across merged geometry. Player and title cameras use a 0.12 m near plane and 45 m far plane, instead of an unnecessarily wide depth range. There is no new per-pixel depth shader, transparency pass, or post-processing cost.

The high-quality flashlight uses shadow bias 0.5 (normal bias 2.0), visually compared against 0.1, 1.0 and 2.0. This removes the horizontal self-shadowing bands observed on the exterior facade without disabling shadows. Decorative raindrops no longer cast shadows onto walls. This addresses a separate source of flickering that material priority cannot fix; see [Godot's shadow-bias documentation](https://docs.godotengine.org/en/stable/classes/class_light3d.html#class-light3d-property-shadow-bias).

## Regression checks

- `tests/test_surfaces.gd`: priority ownership, equal-layer tie breaking, creation-order independence across layers, partial clipping, touching edges, internal faces, occlusion and real mipmap data.
- `tests/test_game.gd`: the generated static house must contain no competing coplanar faces, and every world material must preserve depth testing and the common priority policy.
- `npm run test:floor`: walk from spawn across the material seam; screenshot floor views.
- `npm run test:surfaces`: inspect 13 locations at low/high quality with slightly changing viewpoints, collect rendering budgets and exercise moving details. Set `BROWSER=firefox` for Firefox. This test checks structural assertions and captures visual evidence; it is not a mathematical proof of temporal stability for arbitrary imported meshes.

The floor and surface visual tests explicitly forbid browser pointer lock so they do not capture the laptop cursor. Screenshots and reports live in `build/qa/surfaces/`.
