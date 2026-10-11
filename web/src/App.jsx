import React, { useEffect, useRef } from 'react';
import Lenis from 'lenis';
import { gsap } from 'gsap';
import { ScrollTrigger } from 'gsap/ScrollTrigger';
import Story from './Story.jsx';
import { BULGULAR, REPO, RAPOR, beforeAfter, timeline, acceptance } from './content.js';

const Icon = ({ d }) => (
  <svg className="ico" viewBox="0 0 34 34" fill="none" stroke="var(--ink)" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">{d}</svg>
);

const GitHubMark = ({ size = 18 }) => (
  <svg width={size} height={size} viewBox="0 0 16 16" fill="currentColor" aria-hidden="true">
    <path d="M8 0C3.58 0 0 3.58 0 8c0 3.54 2.29 6.53 5.47 7.59.4.07.55-.17.55-.38 0-.19-.01-.82-.01-1.49-2.01.37-2.53-.49-2.69-.94-.09-.23-.48-.94-.82-1.13-.28-.15-.68-.52-.01-.53.63-.01 1.08.58 1.23.82.72 1.21 1.87.87 2.33.66.07-.52.28-.87.51-1.07-1.78-.2-3.64-.89-3.64-3.95 0-.87.31-1.59.82-2.15-.08-.2-.36-1.02.08-2.12 0 0 .67-.21 2.2.82.64-.18 1.32-.27 2-.27.68 0 1.36.09 2 .27 1.53-1.04 2.2-.82 2.2-.82.44 1.1.16 1.92.08 2.12.51.56.82 1.27.82 2.15 0 3.07-1.87 3.75-3.65 3.95.29.25.54.73.54 1.48 0 1.07-.01 1.93-.01 2.2 0 .21.15.46.55.38A8.013 8.013 0 0016 8c0-4.42-3.58-8-8-8z" />
  </svg>
);

// Healthy channels share one thermal shape; one channel slowly walks away.
function HeroWaves() {
  const refs = [useRef(null), useRef(null), useRef(null)];
  useEffect(() => {
    const n = 140, Wd = 1000;
    const reduce = window.matchMedia('(prefers-reduced-motion: reduce)').matches;
    const draw = (ph) => {
      const lines = [
        { base: 28, amp: 18, drift: 0 },
        { base: 50, amp: 14, drift: 0 },
        { base: 70, amp: 11, drift: 1 },
      ];
      lines.forEach((ln, i) => {
        let d = '';
        for (let k = 0; k <= n; k++) {
          const u = k / n;
          const s = Math.sin(u * Math.PI * 3.2 - ph);
          const away = ln.drift * Math.pow(Math.max(0, u - 0.55) / 0.45, 1.6) * (30 + 8 * Math.sin(ph * 0.5));
          const y = ln.base + s * ln.amp + away;
          d += (k ? 'L' : 'M') + (u * Wd).toFixed(1) + ' ' + y.toFixed(2);
        }
        if (refs[i].current) refs[i].current.setAttribute('d', d);
      });
    };
    if (reduce) { draw(0.6); return undefined; }
    let raf = 0, t0 = performance.now();
    const loop = (now) => { draw(((now - t0) / 1000) * 0.9); raf = requestAnimationFrame(loop); };
    raf = requestAnimationFrame(loop);
    return () => cancelAnimationFrame(raf);
  }, []);
  return (
    <svg className="hero-wave" viewBox="0 0 1000 124" preserveAspectRatio="none" aria-hidden="true">
      <path ref={refs[0]} className="flat" fill="none" strokeWidth="2" vectorEffect="non-scaling-stroke" />
      <path ref={refs[1]} className="flat" fill="none" strokeWidth="2" vectorEffect="non-scaling-stroke" />
      <path ref={refs[2]} className="off" fill="none" strokeWidth="2.6" vectorEffect="non-scaling-stroke" />
    </svg>
  );
}

function Hero() {
  return (
    <section className="hero">
      <div className="wrap">
        <h1>MIHENK</h1>
        <p className="q">Bir sensör, bozulduğunu kendisi anlayabilir mi?</p>
        <p className="lead">
          Küçük, ucuz ve tek başına çalışan sensör düğümleri için referanssız sağlık kestirimi. Yedek sensör, GPS
          ya da kalibrasyon manevrası olmadan, düğümün kendi ölçümlerine ne kadar güvenebileceğini kestirmeye çalışıyoruz.
        </p>
        <div className="hero-links">
          <a className="btn primary" href={REPO}><GitHubMark /> GitHub'da incele</a>
          <a className="btn" href={BULGULAR}>Bulgular günlüğü</a>
          <a className="btn" href={RAPOR}>Tasarım raporu (PDF)</a>
        </div>
        <HeroWaves />
        <a className="cue" href="#fikir">Nasıl çalıştığını görmek için kaydırın ↓</a>
      </div>
    </section>
  );
}

function Problem() {
  const cards = [
    {
      t: 'Yedek sensör yok', p: 'Aynı büyüklüğü ölçen ikinci bir sensör yok. Okumayı bir eşiyle karşılaştırıp "hangisi yanılıyor" diye soramıyoruz.',
      i: <><rect x="6" y="9" width="10" height="16" rx="2" /><rect x="18" y="9" width="10" height="16" rx="2" strokeDasharray="3 3" /></>,
    },
    {
      t: 'Dış referans yok', p: 'GPS yok, sistemin fizik modeli yok, laboratuvar ölçümü yok. Düğüm elindeki ölçümlerle baş başa.',
      i: <><circle cx="17" cy="17" r="10" /><path d="M10 10l14 14" /></>,
    },
    {
      t: 'Kalibrasyon manevrası yok', p: 'Düğüm sahada. Kimse onu çevirip, sallayıp ya da bilinen bir sıcaklığa koyup ayar yapmayacak.',
      i: <><path d="M9 21a9 9 0 0 1 16-8" /><path d="M25 7v6h-6" /><path d="M8 27l18-18" /></>,
    },
  ];
  return (
    <section id="problem">
      <div className="wrap">
        <p className="eyebrow">Problem</p>
        <h2 className="narrow">Bir sensör yavaşça bozulduğunda, bunu kim fark eder?</h2>
        <p className="lead narrow">
          Ucuz sensörler zamanla kayar, takılır, sapar. Çoğu zaman bunu fark eden olmaz; düğüm yanlış veriyi
          güvenle göndermeye devam eder. Elinizde yalnızca düğümün kendisi varsa işiniz daha da zor:
        </p>
        <div className="grid3">
          {cards.map((c) => (
            <div className="card" key={c.t}>
              <Icon d={c.i} />
              <h3>{c.t}</h3>
              <p>{c.p}</p>
            </div>
          ))}
        </div>
        <p className="ask">
          Araştırma sorusu: Böyle bir düğüm, kendi ölçümlerinin güvenilirliğini <b>sürekli</b> ve <b>kalibre</b> bir
          biçimde kestirebilir mi, ve bunun kaynak maliyeti ne olur?
        </p>
      </div>
    </section>
  );
}

function Idea() {
  return (
    <section id="fikir">
      <div className="wrap">
        <p className="eyebrow">Ana fikir</p>
        <h2 className="narrow">Sıcaklık herkese dokunur. Ama bozulma yalnızca birine.</h2>
        <p className="lead narrow">
          Farklı büyüklükleri ölçen sensörler bile ortak bir etkeni paylaşır: sıcaklık. Ortam ısındığında her
          sensör kendi katsayısıyla, ama aynı izi takip ederek kayar. Bir sensör bozulduğunda ise değişim o
          kanala özgü kalır. Bu fark, dışarıdan bir referans gerektirmeden ikisini ayırmamızı sağlar.
        </p>
        <p className="lead narrow">
          Mevcut çalışmalar dünyayı tanımak için sensörleri kullanır. MIHENK, sensörü tanımak için dünyanın fiziksel
          kısıtlarını kullanıyor. Aşağıda tek bir simülasyon koşusunu adım adım izleyebilirsiniz.
        </p>
        <Story />
      </div>
    </section>
  );
}

function Traps() {
  const traps = [
    { t: 'Öz-ısınma', p: 'Bir sensörün kendi ısıtıcısı ya da işlemcinin sıcaklığı, ortam değişimi gibi görünür. Ama yalnızca bir yeri ısıtır.' },
    { t: 'Elektromanyetik girişim', p: 'Yakındaki bir akım, manyetometrenin üç eksenini birden saptırır. Tek bir sensörün üç ekseni "ortam" sayılmamalı.' },
    { t: 'Sıcaklık sensörü bozulursa', p: 'Bu kez bozulan, kararın dayandığı referansın kendisi. Kimi suçlayacağını bilemeyen dedektör "belirsiz" demeli; yanlış suçlamaktan iyidir.' },
    { t: 'Histerezis', p: 'Isınırken ve soğurken aynı sıcaklıkta farklı sapma. Modelin varsaydığı biçim gerçekteki biçimden farklıysa yanlış alarm doğar.' },
    { t: 'Renkli gürültü', p: 'Sensör gürültüsü yalnızca hızlı titreşim değildir; yavaşça gezinen bir bileşeni de vardır ve yavaş bir arızaya çok benzer.' },
  ];
  return (
    <section id="tuzaklar">
      <div className="wrap">
        <p className="eyebrow">Neden zor</p>
        <h2 className="narrow">Kolay görünen ama yanıltan durumlar</h2>
        <p className="lead narrow">
          Fikir basit, ama gerçek bir düğümde ortak mod ile kanala özgü değişimi karıştıran pek çok durum var.
          Her biri simülatörde ayrı bir senaryo olarak sınanıyor.
        </p>
        <div className="grid-traps">
          {traps.map((c) => (
            <div className="card" key={c.t}>
              <h3>{c.t}</h3>
              <p>{c.p}</p>
            </div>
          ))}
        </div>
      </div>
    </section>
  );
}

function Pipeline() {
  const box = [
    ['Fizik', 'ortam sıcaklığı, ısı akışı, gecikme, histerezis'],
    ['Sensör modelleri', 'gürültü, sıcaklık katsayıları, eklenen arızalar'],
    ['Dedektör', 'yalnızca cihazın göreceği veri'],
    ['Değerlendirme', 'gerçek etiketlerle karşılaştırma'],
  ];
  const bw = 210, gap = 40, y = 40, h = 92;
  return (
    <>
      <svg className="pipe" viewBox="0 0 1000 216" role="img" aria-label="Fizik, sensör modelleri, dedektör ve değerlendirme zinciri; gerçek etiketler dedektöre verilmez">
        <defs>
          <marker id="ar" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="7" markerHeight="7" orient="auto"><path d="M0 0L10 5L0 10z" fill="var(--muted)" /></marker>
        </defs>
        {box.map(([t, s], i) => {
          const bx = 10 + i * (bw + gap);
          return (
            <g key={t}>
              <rect x={bx} y={y} width={bw} height={h} rx="12" fill={i === 2 ? 'var(--ink)' : 'var(--wash)'} />
              <text x={bx + 18} y={y + 36} fontSize="19" fontWeight="700" fill={i === 2 ? '#fff' : 'var(--ink)'}>{t}</text>
              <foreignObject x={bx + 18} y={y + 46} width={bw - 30} height={44}>
                <div style={{ fontSize: 14, lineHeight: 1.35, color: i === 2 ? '#c4ced4' : 'var(--muted)' }}>{s}</div>
              </foreignObject>
              {i < 3 && <line x1={bx + bw + 4} x2={bx + bw + gap - 4} y1={y + h / 2} y2={y + h / 2} stroke="var(--muted)" strokeWidth="2" markerEnd="url(#ar)" />}
            </g>
          );
        })}
        {/* ground truth bypasses the detector */}
        <path d={`M${10 + bw / 2 + bw + gap} ${y + h} V ${y + h + 40} H ${10 + 3 * (bw + gap) + bw / 2} V ${y + h + 6}`} fill="none" stroke="var(--accent)" strokeWidth="2" strokeDasharray="6 5" markerEnd="url(#ar)" />
        <line x1={10 + 2 * (bw + gap) + bw / 2} x2={10 + 2 * (bw + gap) + bw / 2} y1={y + h + 28} y2={y + h + 52} stroke="var(--bad)" strokeWidth="3" />
        <text x={10 + 2 * (bw + gap) + bw / 2} y={y + h + 70} textAnchor="middle" fontSize="14" fill="var(--accent)" fontWeight="700">gerçek etiketler dedektörü atlar</text>
      </svg>
      <div className="pipe-list">
        {box.map(([t, s]) => <div className="card" key={t}><h3>{t}</h3><p>{s}</p></div>)}
        <p style={{ color: 'var(--accent)', fontWeight: 700, fontSize: 15 }}>Gerçek etiketler dedektöre hiçbir zaman verilmez.</p>
      </div>
    </>
  );
}

function Method() {
  const flow = [
    ['Geliştir', 'Yeni sürüm, bilinen senaryolar ve tohumlar üzerinde denenir ve iyileştirilir.'],
    ['Önceden ilan et', 'Geçme ölçütleri ve hiç görülmemiş test senaryoları, sonuç görülmeden yazılıp kayda geçirilir.'],
    ['Tek atış', 'Test bir kez koşulur. Sonuca bakıp ayar yapmak yok.'],
    ['Ne çıkarsa yaz', 'Geçmezse bu da bir bulgudur; iddia daraltılır. Kullanılan test kümesi bir daha kullanılmaz.'],
  ];
  return (
    <section id="yontem">
      <div className="wrap">
        <p className="eyebrow">Yöntem</p>
        <h2 className="narrow">Neden simülasyon, ve kendimizi nasıl kandırmıyoruz</h2>
        <p className="lead narrow">
          Sahada bir sensörün tam olarak ne zaman bozulduğunu bilen kimse yoktur. Simülasyonda bilinir. Bu yüzden
          fiziği, sensörleri ve arızaları tek bir zaman tabanında üreten bir ortam kuruyoruz ve dedektörü yalnızca
          gerçek bir cihazın göreceği veriyle besliyoruz.
        </p>
        <Pipeline />
        <div className="split2">
          <div>
            <h3 style={{ fontSize: 22 }}>Önceden ilan, tek atış</h3>
            <p style={{ color: 'var(--muted)', marginTop: 8 }}>
              Aynı senaryolar üzerinde sonsuza kadar ayar yapmak, sonunda yalnızca o senaryoları ezberleyen bir dedektör
              üretir. Bunu önlemek için her sürümü klinik deneylerdekine benzer bir kuralla sınıyoruz.
            </p>
          </div>
          <ol className="flow">
            {flow.map(([t, p]) => <li key={t}><h3>{t}</h3><p>{p}</p></li>)}
          </ol>
        </div>
      </div>
    </section>
  );
}

function BeforeAfter() {
  return (
    <div className="ba">
      {beforeAfter.map((b) => (
        <div className="card" key={b.title}>
          <h3>{b.title}</h3>
          <p>{b.text}</p>
          <div className="ba-bars">
            {b.rows.map((r, i) => {
              const last = i === b.rows.length - 1;
              const good = b.pct ? r.hi >= 90 : r.hi <= b.max * 0.1;
              return (
                <div className="ba-row" key={r.who}>
                  <span className="who">{r.who}</span>
                  <span className="track" style={{ position: 'relative' }}>
                    {r.lo !== r.hi && <span className="fill" style={{ position: 'absolute', left: 0, width: `${(r.lo / b.max) * 100}%`, background: last && good ? 'var(--good)' : 'var(--faint)' }} />}
                    <span className="fill" style={{
                      position: 'absolute', left: r.lo !== r.hi ? `${(r.lo / b.max) * 100}%` : 0,
                      width: `${Math.max(1.5, ((r.lo !== r.hi ? r.hi - r.lo : r.hi) / b.max) * 100)}%`,
                      background: last && good ? 'var(--good)' : r.lo !== r.hi ? 'repeating-linear-gradient(45deg, var(--faint) 0 4px, var(--wash-2) 4px 7px)' : 'var(--faint)',
                    }} />
                  </span>
                  <span className="val">{r.label}</span>
                </div>
              );
            })}
          </div>
          <span className="ref">bulgular {b.ref}</span>
        </div>
      ))}
    </div>
  );
}

function Timeline() {
  return (
    <ol className="timeline">
      {timeline.map((e) => (
        <li key={e.v} className={'tl ' + e.kind}>
          <span className="v">{e.v}</span>
          <span className="dot" aria-hidden="true" />
          <div>
            <h3>{e.title} <span className="ref">· {e.ref}</span></h3>
            <p>{e.text}</p>
            {(e.plus.length > 0 || e.minus.length > 0) && (
              <div className="tags">
                {e.plus.map((t) => <span key={t} className="tag plus">+ {t}</span>)}
                {e.minus.map((t) => <span key={t} className="tag minus">− {t}</span>)}
              </div>
            )}
          </div>
        </li>
      ))}
    </ol>
  );
}

function Acceptance() {
  const all = acceptance.groups.flatMap((g) => g.rows);
  const pass = (j) => all.filter((r) => r[j][0]).length;
  const Mark = ({ r }) => (
    <span className={'mark ' + (r[0] ? 'ok' : 'no')}>
      <span aria-hidden="true">{r[0] ? '✓' : '✕'}</span><span className="sr">{r[0] ? 'geçti' : 'kaldı'}</span> <small>{r[1]}</small>
    </span>
  );
  return (
    <>
      <div className="acc-wrap">
        <table className="acc">
          <thead>
            <tr><th>Ölçüt</th><th>Eşik</th><th style={{ textAlign: 'center' }}>Beyaz gürültü</th><th style={{ textAlign: 'center' }}>Renkli gürültü</th></tr>
          </thead>
          <tbody>
            {acceptance.groups.map((g) => (
              <React.Fragment key={g.name}>
                <tr className="grp"><td colSpan="4">{g.name}</td></tr>
                {g.rows.map((r) => (
                  <tr key={r[0]}>
                    <td>{r[0]}</td>
                    <td style={{ color: 'var(--muted)', whiteSpace: 'nowrap' }}>{r[1]}</td>
                    <td className="r"><Mark r={r[2]} /></td>
                    <td className="r"><Mark r={r[3]} /></td>
                  </tr>
                ))}
              </React.Fragment>
            ))}
          </tbody>
        </table>
      </div>
      <div className="acc-sum">
        <span>Beyaz: <b style={{ color: 'var(--ink)' }}>{pass(2)} / {all.length}</b> geçti</span>
        <span>Renkli: <b style={{ color: 'var(--ink)' }}>{pass(3)} / {all.length}</b> geçti</span>
        <span>Sonuç: <b style={{ color: 'var(--bad)' }}>geçemedi</b> · bulgular {acceptance.ref}</span>
      </div>
    </>
  );
}

function Findings() {
  return (
    <section id="bulgular">
      <div className="wrap">
        <p className="eyebrow">Bulgular</p>
        <h2 className="narrow">Şimdiye kadar neler öğrendik</h2>
        <p className="lead narrow">
          Her sürüm bir şeyi çözdü, çoğu zaman da yeni bir zayıflığı görünür kıldı. Aşağıdaki sayıların hepsi
          simülasyon çıktısıdır ve bulgular günlüğündeki ilgili bölüme bağlıdır.
        </p>
        <BeforeAfter />

        <h3 style={{ fontSize: 24, marginTop: 72 }}>Sürüm sürüm</h3>
        <Timeline />

        <h3 style={{ fontSize: 24, marginTop: 72 }}>Bir başarısızlık, olduğu gibi</h3>
        <p style={{ color: 'var(--muted)', marginTop: 8, maxWidth: 'var(--measure)' }}>
          {acceptance.title}: {acceptance.meta}. {acceptance.note}
        </p>
        <Acceptance />

        <a className="cta" href="replay/">
          <div>
            <h3>G1 Oynatıcı</h3>
            <p>Test koşularını dakika dakika izleyin: gerçekte ne oldu, dedektör ne dedi, haklı mıydı.</p>
          </div>
          <span className="go">Oynatıcıyı aç →</span>
        </a>
      </div>
    </section>
  );
}

function Hardware() {
  const mcus = [
    { n: 'ATmega328P', s: 'Arduino Nano / Uno', kb: 2 },
    { n: 'ATmega2560', s: 'Arduino Mega', kb: 8 },
    { n: 'ESP32-S3', s: 'kablosuz, çift çekirdek', kb: 512 },
  ];
  const lg = (v) => Math.log2(v) / Math.log2(512);
  return (
    <section id="donanim">
      <div className="wrap">
        <p className="eyebrow">Hedef donanım</p>
        <h2 className="narrow">2 KB'tan 512 KB'a</h2>
        <p className="lead narrow">
          Aynı tanı fikri üç farklı mikrodenetleyicide çalıştırılacak. Aralarında 256 kat bellek farkı var. En küçük
          kartta fikrin ne kadarının sığdığı, tanı maliyeti ile tanı gücü arasındaki dengeyi ölçmenin yolu.
        </p>
        <div className="mcu">
          {mcus.map((m) => (
            <div className="mcu-row" key={m.n}>
              <span className="name">{m.n}<small>{m.s}</small></span>
              <span className="track">
                <span className="fill" style={{ width: `${Math.max(3, lg(m.kb) * 100)}%` }} />
                <span className="lbl" style={lg(m.kb) > 0.5 ? { right: 12, color: '#fff' } : { left: `calc(${Math.max(3, lg(m.kb) * 100)}% + 10px)` }}>{m.kb} KB SRAM</span>
              </span>
            </div>
          ))}
        </div>
        <p className="scale-note">Çubuklar logaritmik ölçekte.</p>
      </div>
    </section>
  );
}

function Sources() {
  const items = [
    { href: REPO, t: 'Kaynak kod', d: 'MATLAB referans modeli, G1 dedektörünün bütün sürümleri, test betikleri ve bu sayfanın kendisi.', go: 'GitHub', gh: true },
    { href: BULGULAR, t: 'Bulgular günlüğü', d: 'Her betiğin neyi, nasıl ve neden test ettiği ve ne bulduğu. Bu sayfadaki sayıların kaynağı.', go: 'Oku' },
    { href: RAPOR, t: 'Tasarım raporu', d: 'Mimari, tasarım kararları, kalite kapıları, riskler ve değerlendirme planı.', go: 'PDF' },
  ];
  return (
    <section id="kaynaklar">
      <div className="wrap">
        <p className="eyebrow">Daha fazlası</p>
        <h2 className="narrow">Her şey açık</h2>
        <p className="lead narrow">
          Kod, ham sonuçlar ve her deneyin gerekçesi GitHub'da. Bu sayfada gördüğünüz her sayıyı oradan izleyebilirsiniz.
        </p>
        <div className="sources">
          {items.map((it) => (
            <a key={it.t} className={'source' + (it.gh ? ' gh' : '')} href={it.href}>
              <span className="src-t">{it.gh && <GitHubMark size={22} />}{it.t}</span>
              <span className="src-d">{it.d}</span>
              <span className="src-go">{it.go} →</span>
            </a>
          ))}
        </div>
      </div>
    </section>
  );
}

// Smooth scrolling (Lenis) driving ScrollTrigger; in-page anchors go through Lenis too.
function useSmoothScroll() {
  useEffect(() => {
    if (window.matchMedia('(prefers-reduced-motion: reduce)').matches) return undefined;
    const lenis = new Lenis({ duration: 1.15, easing: (t) => Math.min(1, 1.001 - Math.pow(2, -10 * t)) });
    lenis.on('scroll', ScrollTrigger.update);
    const tick = (time) => lenis.raf(time * 1000);
    gsap.ticker.add(tick);
    gsap.ticker.lagSmoothing(0);
    const onClick = (e) => {
      const a = e.target.closest('a[href^="#"]');
      if (!a) return;
      const id = a.getAttribute('href');
      const el = id === '#top' ? 0 : document.querySelector(id);
      if (el === null) return;
      e.preventDefault();
      lenis.scrollTo(el, { offset: -64 });
      history.replaceState(null, '', id);
    };
    document.addEventListener('click', onClick);
    return () => { document.removeEventListener('click', onClick); gsap.ticker.remove(tick); lenis.destroy(); };
  }, []);
}

export default function App() {
  useSmoothScroll();
  return (
    <>
      <header className="bar">
        <div className="wrap">
          <a className="brand" href="#top">MIHENK</a>
          <nav aria-label="Bölümler">
            <a className="opt" href="#fikir">Fikir</a>
            <a className="opt" href="#yontem">Yöntem</a>
            <a href="#bulgular">Bulgular</a>
            <a href="replay/">Oynatıcı</a>
            <a className="gh-link" href={REPO} aria-label="GitHub deposu"><GitHubMark /> <span>GitHub</span></a>
          </nav>
        </div>
      </header>
      <main id="top">
        <Hero />
        <Problem />
        <Idea />
        <Traps />
        <Method />
        <Findings />
        <Hardware />
        <Sources />
      </main>
      <footer>
        <div className="wrap">
          <div>
            <strong>Yuşa Göverdik · Batuhan Koca</strong><br />
            Danışman: Doç. Dr. Emre Avuçlu<br />
            Aksaray Üniversitesi, Mühendislik Fakültesi, Yazılım Mühendisliği
          </div>
          <div className="links">
            <a href={REPO}>Kaynak kod (GitHub)</a>
            <a href={BULGULAR}>Bulgular günlüğü</a>
            <a href={RAPOR}>Tasarım raporu (PDF)</a>
          </div>
        </div>
      </footer>
    </>
  );
}
