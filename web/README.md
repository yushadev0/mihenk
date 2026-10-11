# web/

Project page for readers who do not use GitHub, live at https://yusa.app/mihenk/ (Turkish). React + Vite + GSAP ScrollTrigger + Lenis (smooth scroll, off under reduced motion), same palette and type as the replay viewer.

- `src/Story.jsx`: the "main idea" scene. A sticky figure plays one simulation run while the reader scrolls through four steps (common mode, heater trap, sensor fault, detector verdict). The numbers in the last step are computed from the data.
- `src/content.js`: findings shown on the page (before/after cards, version timeline, v5 acceptance test). Every number comes from `../bulgular.md`, the section is named next to it. Update it when a new G1 version is evaluated.
- `public/data/story.json`: the run behind the scene, written by `../matlab/g1/site/g1_export_site.m` (no MATLAB needed to view it, ADR-021). Without it the dev server falls back to `story.dev.json`, a rough layout fixture that is gitignored, marked "GELİŞTİRME VERİSİ" on the page and never published.

```
npm install
npm run dev        # http://localhost:5173/mihenk/
sh ../viewer/deploy.sh   # build and publish (requires story.json)
```
