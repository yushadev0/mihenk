import React, { useEffect, useLayoutEffect, useMemo, useRef, useState } from 'react';
import { gsap } from 'gsap';
import { ScrollTrigger } from 'gsap/ScrollTrigger';

gsap.registerPlugin(ScrollTrigger);

// Scene geometry (SVG user units)
const W = 760, L = 58, R = 14;
const TEMP = { top: 14, bot: 146, lo: 21, hi: 44 };
const CH = { top: 178, h: 40, gap: 9, n: 6 };
const LANE = { truth: 476, g1: 498, h: 14 };
const AXIS = 528, H = 548;
const T_END = 8;
const x = (t) => L + (t / T_END) * (W - L - R);
const yT = (v) => TEMP.bot - ((v - TEMP.lo) / (TEMP.hi - TEMP.lo)) * (TEMP.bot - TEMP.top);
const rowTop = (i) => CH.top + i * (CH.h + CH.gap);

// Time keyframes per step: each step scrubs from keys[i] to keys[i + 1]
const KEYS = [0.25, 3.15, 4.4, 8, 8];

const path = (t, v, fx, fy) => {
  let d = '';
  for (let k = 0; k < t.length; k++) d += (k ? 'L' : 'M') + fx(t[k]).toFixed(1) + ' ' + fy(v[k]).toFixed(1);
  return d;
};
const runs = (t, on) => {           // [t0, t1] spans where on[k] is true, block edges
  const out = [], dt = t.length > 1 ? t[1] - t[0] : 1 / 60;
  let s = -1;
  for (let k = 0; k <= t.length; k++) {
    const v = k < t.length && on[k];
    if (v && s < 0) s = k;
    if (!v && s >= 0) { out.push([t[s] - dt / 2, t[k - 1] + dt / 2]); s = -1; }
  }
  return out;
};
const fmtH = (t) => {
  const h = Math.floor(t), m = Math.floor((t - h) * 60);
  return { h, m: String(m).padStart(2, '0') };
};

async function loadStory() {
  const base = import.meta.env.BASE_URL;
  // A missing file can come back as the HTML page (SPA fallback), so parse defensively
  const get = async (f) => {
    try {
      const r = await fetch(base + 'data/' + f);
      return r.ok ? await r.json() : null;
    } catch { return null; }
  };
  const real = await get('story.json');
  if (real) return { data: real, dev: false };
  if (import.meta.env.DEV) {
    const dev = await get('story.dev.json');
    if (dev) return { data: dev, dev: true };
  }
  throw new Error('story.json missing');
}

function useStats(D) {
  return useMemo(() => {
    if (!D) return null;
    const fc = D.meta.faultCh - 1, t0 = D.meta.faultT0, n = D.t.length;
    let first = -1, cov = 0, nf = 0, other = 0, heatSensor = 0, heatSrc = 0, heatN = 0;
    for (let k = 0; k < n; k++) {
      if (!D.valid[k]) continue;
      for (let c = 0; c < 9; c++) if (c !== fc && D.state[c][k] === 1) other++;
      if (D.fault[fc][k]) { nf++; if (D.state[fc][k] === 1) cov++; if (first < 0 && D.state[fc][k] === 1) first = k; }
      if (D.heater[k]) {
        heatN++;
        if (D.blameBme[k] || D.ambig[k]) heatSrc++;
        for (let c = 0; c < 9; c++) if (D.state[c][k] === 1 && !D.fault[c][k]) { heatSensor++; break; }
      }
    }
    return {
      fc, name: D.names[fc],
      delay: first >= 0 ? Math.round((D.t[first] - t0) * 60) : null,
      coverage: nf ? cov / nf : 0, other, heatSensor, heatSrc, heatN,
    };
  }, [D]);
}

function Scene({ D, step, clipRef, cursorRef }) {
  const geo = useMemo(() => {
    const t = D.t, idx = [0, 1, 2, 3, 4, 5];
    const fc = D.meta.faultCh - 1;
    const chans = idx.map((c) => {
      const v = D.Y[c];
      let lo = Infinity, hi = -Infinity;
      for (const a of v) { if (a < lo) lo = a; if (a > hi) hi = a; }
      const top = rowTop(c), span = hi - lo || 1;
      return {
        c, name: D.names[c], fault: c === fc,
        d: path(t, v, x, (a) => top + CH.h - ((a - lo) / span) * CH.h),
        flags: runs(t, D.state[c].map((s, k) => s === 1 && D.valid[k])),
      };
    });
    const heat = runs(t, D.heater);
    const faultSpan = runs(t, D.fault[fc]);
    const src = runs(t, D.blameBme.map((b, k) => b || D.ambig[k]));
    const sensor = runs(t, t.map((_, k) => D.valid[k] && D.state.some((s, c) => c < 9 && s[k] === 1)));
    const offs = [];
    D.state.forEach((s) => s.forEach((v, k) => { if (v === 2) offs.push(t[k]); }));
    return {
      chans, heat, faultSpan, src, sensor, offs, fc,
      amb: path(t, D.T.amb, x, yT), icm: path(t, D.T.icm, x, yT), bme: path(t, D.T.bme, x, yT),
    };
  }, [D]);

  const band = (s, y, h, fill, key) => <rect key={key} fill={fill} x={x(s[0])} y={y} width={Math.max(1, x(s[1]) - x(s[0]))} height={h} />;

  return (
    <svg className="scene" viewBox={`0 0 ${W} ${H}`} data-step={step} role="img"
      aria-label="Sekiz saatlik simülasyon: üstte sıcaklıklar, ortada altı hareket kanalı, altta gerçek ve dedektör kararları">
      <defs>
        <clipPath id="reveal"><rect ref={clipRef} x="0" y="0" width={x(KEYS[0])} height={H} /></clipPath>
      </defs>

      {/* heater window across the whole figure */}

      {/* temperatures */}
      <g className="lay lay-temp">
        <text x={L - 10} y={TEMP.top + 4} textAnchor="end" fontSize="12" fill="var(--muted)" fontWeight="700">°C</text>
        {[25, 30, 35, 40].map((v) => (
          <g key={v}>
            <line x1={L} x2={W - R} y1={yT(v)} y2={yT(v)} stroke="var(--rule)" />
            <text x={L - 10} y={yT(v) + 4} textAnchor="end" fontSize="12" fill="var(--muted)">{v}</text>
          </g>
        ))}
        <g clipPath="url(#reveal)">
          <path d={geo.amb} fill="none" stroke="var(--faint)" strokeWidth="1.6" strokeDasharray="5 4" />
          <path d={geo.icm} fill="none" stroke="var(--icm)" strokeWidth="2.4" />
          <path className="lay lay-bme-hi" d={geo.bme} fill="none" stroke="var(--bme)" strokeWidth="2.4" />
        </g>
      </g>

      {/* channels, each on its own scale */}
      <g className="lay lay-ch">
        {geo.chans.map((ch) => (
          <g key={ch.c} className={'ch' + (ch.fault ? ' ch-fault' : '')}>
            <rect x={L} y={rowTop(ch.c) - 3} width={W - L - R} height={CH.h + 6} fill="var(--wash)" rx="4" />
            {ch.fault && geo.faultSpan.map((s, i) => (
              <rect key={i} x={x(s[0])} y={rowTop(ch.c) - 3} width={x(s[1]) - x(s[0])} height={CH.h + 6} fill="var(--bad-wash)" clipPath="url(#reveal)" />
            ))}
            <text x={L - 10} y={rowTop(ch.c) + CH.h / 2 + 5} textAnchor="end" fontSize="14" fontWeight="700"
              fill={ch.fault ? 'var(--bad)' : 'var(--ink)'}>{ch.name}</text>
            <g clipPath="url(#reveal)">
              <path d={ch.d} fill="none" stroke={ch.fault ? 'var(--bad)' : 'var(--ink)'} strokeWidth="1.5" strokeLinejoin="round" />
              {ch.flags.map((s, i) => (
                <rect key={i} x={x(s[0])} y={rowTop(ch.c) + CH.h + 1} width={Math.max(1.5, x(s[1]) - x(s[0]))} height="3" fill="var(--bad)" />
              ))}
            </g>
          </g>
        ))}
      </g>

      {/* truth vs detector lanes */}
      <g className="lay lay-lanes">
        <text x={L - 10} y={LANE.truth + 11} textAnchor="end" fontSize="12" fontWeight="700" fill="var(--muted)">Gerçek</text>
        <text x={L - 10} y={LANE.g1 + 11} textAnchor="end" fontSize="12" fontWeight="700" fill="var(--ink)">G1</text>
        <rect x={L} y={LANE.truth} width={W - L - R} height={LANE.h} fill="var(--wash)" rx="3" />
        <rect x={L} y={LANE.g1} width={W - L - R} height={LANE.h} fill="var(--wash)" rx="3" />
        <g clipPath="url(#reveal)">
          {geo.heat.map((s, i) => band(s, LANE.truth, LANE.h, 'var(--heat)', 'th' + i))}
          {geo.faultSpan.map((s, i) => <rect key={'tf' + i} x={x(s[0])} y={LANE.truth} width={x(s[1]) - x(s[0])} height={LANE.h} fill="var(--bad)" />)}
          {geo.src.map((s, i) => <rect key={'gs' + i} x={x(s[0])} y={LANE.g1} width={Math.max(1.5, x(s[1]) - x(s[0]))} height={LANE.h} fill="var(--heat)" />)}
          {geo.sensor.map((s, i) => <rect key={'gf' + i} x={x(s[0])} y={LANE.g1} width={Math.max(1.5, x(s[1]) - x(s[0]))} height={LANE.h} fill="var(--bad)" />)}
          {geo.offs.map((t, i) => <path key={'o' + i} d={`M${x(t)} ${LANE.g1 - 3}l5 5 -5 5 -5 -5z`} fill="var(--paper)" stroke="var(--bad)" strokeWidth="1.5" />)}
        </g>
      </g>

      {/* time axis */}
      <g>
        {[0, 1, 2, 3, 4, 5, 6, 7, 8].map((h) => (
          <text key={h} x={x(h)} y={AXIS + 14} textAnchor="middle" fontSize="12" fill="var(--muted)">{h}{h === 8 ? ' sa' : ''}</text>
        ))}
      </g>

      {/* heater window across temperatures and channels, revealed with time */}
      <g clipPath="url(#reveal)" style={{ pointerEvents: 'none' }}>
        {geo.heat.map((s, i) => band(s, TEMP.top - 6, LANE.truth - TEMP.top - 6, 'var(--heat)', 'h' + i))
          .map((r) => <g key={r.key} opacity="0.16">{r}</g>)}
      </g>

      {/* playhead */}
      <g ref={cursorRef} transform={`translate(${x(KEYS[0])} 0)`}>
        <line x1="0" x2="0" y1={TEMP.top - 8} y2={AXIS} stroke="var(--accent)" strokeWidth="1.5" />
        <circle cx="0" cy={TEMP.top - 8} r="4" fill="var(--accent)" />
      </g>
    </svg>
  );
}

export default function Story() {
  const [S, setS] = useState({ D: null, dev: false, err: false });
  const [step, setStep] = useState(0);
  const stats = useStats(S.D);
  const stepsRef = useRef(null), clipRef = useRef(null), cursorRef = useRef(null), clockRef = useRef(null);

  useEffect(() => {
    loadStory().then(({ data, dev }) => setS({ D: data, dev, err: false })).catch(() => setS({ D: null, dev: false, err: true }));
  }, []);

  useLayoutEffect(() => {
    if (!S.D || !stepsRef.current) return undefined;
    const reduce = window.matchMedia('(prefers-reduced-motion: reduce)').matches;
    const setT = (t) => {
      const px = x(t);
      if (clipRef.current) clipRef.current.setAttribute('width', px);
      if (cursorRef.current) cursorRef.current.setAttribute('transform', `translate(${px} 0)`);
      if (clockRef.current) {
        const { h, m } = fmtH(Math.min(t, T_END - 1 / 60));
        clockRef.current.firstChild.nodeValue = `${h}:${m}`;
      }
    };
    setT(reduce ? T_END : KEYS[0]);
    const els = stepsRef.current.querySelectorAll('.step');
    const triggers = Array.from(els).map((el, i) => ScrollTrigger.create({
      trigger: el, start: 'top 65%', end: 'bottom 65%',
      onToggle: (self) => { if (self.isActive) setStep(i); },
      onUpdate: (self) => { if (!reduce) setT(KEYS[i] + (KEYS[i + 1] - KEYS[i]) * self.progress); },
    }));
    ScrollTrigger.refresh();
    return () => triggers.forEach((tr) => tr.kill());
  }, [S.D]);

  if (S.err) {
    return <p className="fig-note">Sahnenin verisi henüz yayınlanmadı.</p>;
  }

  const st = stats;
  const steps = [
    {
      title: 'Ortam ısınıyor',
      body: <>İlk saatten sonra ortam sıcaklığı iki saatte 25 °C'den 40 °C'ye çıkıyor. Altı hareket kanalının hepsi kayıyor. Her biri kendi katsayısıyla, ama hepsi <b>aynı biçimde</b>: sıcaklığın izini taşıyorlar. Birden çok kanalda aynı termal iz, ortak mod demek.</>,
      verdict: ['env', 'Sebep ortam, suçlu yok'],
    },
    {
      title: 'Bir tuzak: ısıtıcı',
      body: <>3,25. saatte gaz sensörü BME688'in kendi ısıtıcısı çalışıyor. BME'nin sıcaklık okuması <b style={{ color: 'var(--bme)' }}>sıçrıyor</b>, ama ICM'nin okuması ve hareket kanalları yerinde duruyor. Sıcaklığı tek bir okumadan alan bir yöntem burada bütün kanalları "sıcaklığa uymuyor" diye suçlardı. G1 tutarsızlığı sıcaklık kaynağına yüklüyor.</>,
      verdict: ['src', 'Sebep sıcaklık kaynağı, sensör değil'],
    },
    {
      title: 'Gerçek arıza: bir kanal ayrışıyor',
      body: <>4,5. saatte jiroskopun z ekseninde (<b style={{ color: 'var(--bad)' }}>gz</b>) yavaş bir kayma başlıyor: saatte 0,03 °/s. Ortam soğurken öbür kanallar sıcaklığı izleyip geri dönüyor; gz dönmüyor. Tek kanala özgü değişim, sebebin sensör olduğu anlamına geliyor.</>,
      verdict: ['sensor', 'Sebep sensör: gz'],
    },
    {
      title: 'Dedektör ne dedi?',
      body: st ? (
        <>Alttaki iki şerit gerçeği ve G1'in kararlarını yan yana gösteriyor. Bu koşuda G1, {st.name}'yi kayma başladıktan <b>{st.delay ?? '–'} dakika</b> sonra suçladı ve arızanın sürdüğü blokların <b>%{Math.round(100 * st.coverage)}</b>'inde suçlu olarak tuttu. Öbür sekiz kanala yanlış suçlama: <b>{st.other} blok</b>. Isıtıcı sırasında sağlam bir sensörü suçlama: <b>{st.heatSensor} blok</b>.</>
      ) : null,
      note: 'Bu tek bir koşu. Yüzlerce koşunun toplu sonuçları aşağıda, Bulgular bölümünde.',
    },
  ];

  return (
    <div className="story">
      <div className="steps" ref={stepsRef}>
        {steps.map((s, i) => (
          <div key={i} className={'step' + (step === i ? ' on' : '')}>
            <div className="step-card">
              <div className="n">{i + 1} / {steps.length}</div>
              <h3>{s.title}</h3>
              <p>{s.body}</p>
              {s.verdict && <span className={'verdict ' + s.verdict[0]}>{s.verdict[1]}</span>}
              {s.note && <p style={{ color: 'var(--muted)', fontSize: 15 }}>{s.note}</p>}
            </div>
          </div>
        ))}
      </div>
      <div className="figure-col">
        <div className="figure-sticky">
          <div className="fig-head">
            <div className="clock" ref={clockRef} aria-live="off">0:15<small>saat</small></div>
            <div className="legend">
              <span><i style={{ background: 'var(--faint)' }} />ortam (gerçek)</span>
              <span><i style={{ background: 'var(--icm)' }} />ICM sıcaklığı</span>
              <span><i style={{ background: 'var(--bme)' }} />BME sıcaklığı</span>
              <span><i style={{ background: 'var(--heat)' }} />ısıtıcı / sıcaklık kaynağı</span>
              <span><i style={{ background: 'var(--bad)' }} />arıza / sensör suçlandı</span>
            </div>
          </div>
          {S.D ? <Scene D={S.D} step={step} clipRef={clipRef} cursorRef={cursorRef} /> : <div style={{ aspectRatio: `${W} / ${H}`, background: 'var(--wash)', borderRadius: 8 }} />}
          <p className="fig-note">
            {S.dev && <span className="devbadge">GELİŞTİRME VERİSİ</span>}
            <span className="txt">Eğriler simülatörün çıktısı: hareketsiz bir düğüm, 8 saat, 60 saniyelik bloklar. Her kanal kendi ölçeğinde çizildi. Kırmızı alt çizgi, G1'in o kanalı suçladığı anlar.</span>
          </p>
        </div>
      </div>
      <p className="story-note">Eğriler simülatörün çıktısı: hareketsiz bir düğüm, 8 saat, 60 saniyelik bloklar. Her kanal kendi ölçeğinde çizildi.</p>
    </div>
  );
}
