# G1 replay viewer

`replay.html` replays a G1 run block by block in the browser. It shows the node diagram (sensor temperatures, channel status lights, the temperature-source link), scopes that share one time axis (temperatures, temperature-source z for v5 and v6, a channel status raster, an event strip, and z and CUSUM for the selected channel), and a time cursor that veils the part of the run that has not happened yet.

Data comes from `matlab/g1/v6/g1_export_replay.m`, which writes `data/<run>.json` and `data/index.json`. The page reads only these files, so MATLAB is not needed to watch a run (ADR-021).

Opening the file directly (`file://`) blocks `fetch`, so the page asks you to drop the JSON files onto it. To load `index.json` automatically, serve the folder instead:

```
npx serve viewer
```

Controls: space plays and pauses, the left and right arrows step one block (ten with Shift). Click or drag on any scope to seek. Click a channel light or a raster row to choose the channel shown in the bottom two scopes.
