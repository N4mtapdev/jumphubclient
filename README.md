# Jump Hub v4.2 - N4mtapdev
Roblox client-side LocalScript (Lua/Luau). Pure client-side UI + movement/graphics utilities. No remotes, no server dependency, no admin/kick code.

## What this is
A single-file Roblox LocalScript (`JumpHubClient.lua`) with a UI hub (move / player / misc / FPS / find), hotkeys, sliders, save/load, theme + extras (fly, noclip, infinite jump, fullbright, hide players, etc.). Everything runs client-side only.

## Quick start
1. Put `JumpHubClient.lua` in a Roblox LocalScript (StarterPlayerScripts / StarterGui, etc.) in your executor/studio setup.
2. Open the hub with the menu key (RightShift by default) or the floating JH button.
3. Save/Load settings needs an executor that exposes `writefile`/`readfile`/`isfile`/`delfile`; if it doesn't, the script just uses defaults.

## Files
- `JumpHubClient.lua` — main script (installable, single file).
- `JumpHubComments.md` — full feature/comment reference.
- `CHANGELOG.md` — v4.2 changes and notes.
- `JumpHubClient.v4.2.backup.lua` — backup of the v4.2 installable source.

## Notes
- Client-side only. Doesn't talk to any server script.
- Some features depend on executor/game behavior (writefile, sounds, anti-afk, etc.) and are wrapped in pcall.
- Obfuscated distribution is a separate concern; this repo keeps the readable installable source plus backups/comments for reference.

## Rebuild main.lua (bản obfuscate)
`main.lua` là bản build phát hành: Prometheus preset **Minify**, target Luau, biến local đặt tên theo công thức hóa học (NaCl, H2SO4, C6H12O6, ...).

```sh
sh tools/build.sh                # viết ./main.lua — không phụ thuộc /tmp
luau-compile --binary main.lua   # gate Luau chính thức, phải exit 0
```

`tools/build.sh` tự tải Prometheus **v0.2.11.1** (version pinned) vào `~/.cache/jumphub-build`, copy `tools/chemical.lua` vào `src/prometheus/namegenerators/chemical.lua` (đúng đường dẫn Prometheus `require`) và đăng ký generator `Chemical`, rồi chạy `--LuaU --config prometheus.config.lua`. Yêu cầu: `sh`, `curl`, `tar`, `lua5.1`.

## Author
N4mtapdev
