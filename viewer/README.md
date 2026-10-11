# G1 replay viewer

Live at **https://yusa.app/mihenk/replay/** (project page: https://yusa.app/mihenk/).

`replay.html` replays a G1 run minute by minute in the browser, one story per run. It answers three questions: what really happened, what the detector decided (v5, and v6 for the temperature source), and whether it was right. It shows the temperatures, the BME/ICM agreement (zT) for v5 and v6, verdict lanes (truth vs decisions; green = justified alarm, red = false alarm), a "right now" panel with channel boxes, and, collapsed, z and CUSUM for one channel.

Data comes from `matlab/g1/v6/g1_export_replay.m`, which writes `data/<run>.json` and `data/index.json`. The page reads only these files, so MATLAB is not needed to watch a run (ADR-021).

Opening the file directly (`file://`) blocks `fetch`, so the page asks you to drop the JSON files onto it. To load `index.json` automatically, serve the folder instead:

```
npx serve viewer
```

Controls: space plays and pauses, the left and right arrows step one block (ten with Shift). Click or drag on any scope to seek. Click a channel box to open its details.

## Publishing

`site/index.html` is the project page at https://yusa.app/mihenk/. To publish the page, the viewer and the current `data/` to the server (plain static files under the nginx root, no server config needed), run:

```
sh viewer/deploy.sh
```

The script wraps `replay.html` in a document skeleton as `replay/index.html` and swaps the remote folder in one move. Rerun it after a new export from MATLAB.
