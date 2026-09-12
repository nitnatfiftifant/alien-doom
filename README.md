# Alien Doom

Godot 4 + FuncGodot + TrenchBroom jam project. The canonical level source is `maps/ventilation_blockout.map`; `maps/ventilation_blockout.tscn` builds it through FuncGodot.

Полный фактический срез проекта находится в `docs/PROJECT_STATUS_RU.md`. Статус моделей, анимаций, оружия и план ретаргета PSX-персонажей подробно описаны в `docs/ASSET_INTEGRATION_RU.md`.

## Editing levels

1. Run `tools/open_trenchbroom.ps1`, or start TrenchBroom and choose **Alien Doom**.
2. Open `maps/ventilation_blockout.map`.
3. Save in TrenchBroom. Running the scene rebuilds automatically; in the Godot editor select `FuncGodotMap` and press **Build Map** for an editor preview.

Scale is 32 map units per Godot metre. Keep structural geometry in `worldspawn`, reusable non-sealing detail in `func_detail`, and use the provided point entities for gameplay handoff. Use TrenchBroom Layers and Groups: FuncGodot preserves their hierarchy; mark temporary layers as omitted from export when needed.

## FuncGodot layout

- `addons/func_godot/` — untouched upstream plugin.
- `fgd/fgd_main.tres` — master FGD; it includes upstream geometry plus the project point/solid FGD files.
- `fgd/base`, `fgd/point`, `fgd/solid` — reusable properties and individual entity definitions.
- `fgd/files` — grouped FGD files included by the master resource.
- `fgd/game_config.tres` — TrenchBroom v9 export resource.
- `maps/map_settings.tres` — canonical scale, FGD, texture and material lookup configuration.
- `textures/` — editor-visible albedo and special hint textures.
- `materials/` — Godot material overrides mirroring texture-relative paths.
- `maps/autosave/.gdignore` and `models/editor/.gdignore` — prevent generated editor data from being imported by Godot.

Special materials have pipeline meaning: `special/clip` creates collision without a visible face, `special/skip` removes render and collision faces, `special/origin` defines a brush-entity pivot, and `special/trigger` is used to author trigger volumes.

## Validation

Run `tools/validate_integration.ps1`. It builds the `.map` in Godot 4.8.dev5 and asserts render geometry, collision, direct FuncGodot scene entities, node-based human FSM, wall traversal, and perception.

Run the following after a mapping pass when generated geometry should be committed and immediately visible in the Godot editor:

```powershell
& 'D:\BeProgrammer\Godot_Engine_Experimental\Godot_v4.8-dev5_win64.exe' --headless --path . --script res://tools/bake_map_scene.gd
```
