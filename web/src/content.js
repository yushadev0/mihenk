// Every number on the page comes from bulgular.md; `ref` names the section.
// Update this file when a new G1 version is evaluated.

export const BULGULAR = 'https://github.com/yushadev0/mihenk/blob/main/bulgular.md';
export const REPO = 'https://github.com/yushadev0/mihenk';
export const RAPOR = 'https://github.com/yushadev0/mihenk/blob/main/mihenk_rapor.pdf';

// Before -> after, one per card. `max` sets the bar scale.
export const beforeAfter = [
  {
    title: 'Renkli gürültüde yanlış alarm',
    text: 'Yavaş gezinen sensör gürültüsünü arıza sanmak. Gürültü modeli Allan analizinden türetilince ~10 kat azaldı.',
    max: 195,
    rows: [
      { who: 'v1', lo: 115, hi: 195, label: '115–195 /saat' },
      { who: 'v3', lo: 11.5, hi: 11.5, label: 'ort. 11,5 /saat' },
    ],
    ref: '§8 → §9',
  },
  {
    title: 'Sıcaklık kaynağı kilidi',
    text: 'Isıtıcıdan sonra sıcaklık sensörlerinin uyuşmazlığına takılıp kalan model. Model yapısı düzeltilince kilit kalktı.',
    max: 179,
    rows: [
      { who: 'v5', lo: 179, hi: 179, label: '179 blok' },
      { who: 'v6', lo: 0, hi: 0, label: '0 blok' },
    ],
    ref: '§14 → §15',
  },
  {
    title: 'Basamak arızası kapsaması',
    text: 'Sıcaklık sabitken bir kanala oturan kalıcı sapma. Ofset olayı olarak tanınınca neredeyse tamamı yakalandı.',
    max: 100, pct: true,
    rows: [
      { who: 'v5', lo: 11, hi: 76, label: '%11–76' },
      { who: 'v6', lo: 99, hi: 99, label: '%99' },
    ],
    ref: '§12 → §16',
  },
];

// kind: ok (solved something), fail (exposed or broke something), now (in progress)
export const timeline = [
  {
    v: 'Temel', kind: 'ok', title: 'Gürültü ve sıcaklık modelleri doğrulandı',
    text: "MATLAB'ın hazır sensör modelinde iki sessiz tuzak bulundu: gürültü yoğunluğu √2 küçük çıkıyor ve sıcaklık etkisi bütün sensörlerde kusursuz biçimde aynı. Sensör başına gecikme, gradyan, öz-ısınma ve histerezisli kendi sıcaklık modelimiz kuruldu.",
    plus: ['Allan analiziyle %0,04 hata'], minus: [], ref: '§1–5',
  },
  {
    v: 'v0', kind: 'ok', title: 'İlk prototip',
    text: 'Isıtıcı tuzağı çözüldü: sağlam sensörlere hiç suçlama gitmedi. Histerezis ve sıcaklık gecikmesi zayıf kaldı.',
    plus: ['ısıtıcıda 0 sensör suçlaması'], minus: ['histerezis', 'gecikme'], ref: '§6',
  },
  {
    v: 'v1', kind: 'ok', title: 'Hafızalı model',
    text: 'Tek senaryoda kapsama %98, yanlış alarm 0. Ama tek bir senaryoya ve tek bir tohuma göre ayarlanmıştı.',
    plus: ['kapsama %98'], minus: ['tek senaryoya ayarlı'], ref: '§7',
  },
  {
    v: 'v2', kind: 'fail', title: 'Çok senaryolu sınav',
    text: '9 senaryo × 5 tohumda v1 renkli gürültüde çöktü. Elektromanyetik girişim G1 ile tek başına çözülemiyor.',
    plus: [], minus: ['saatte 115–195 yanlış alarm'], ref: '§8',
  },
  {
    v: 'v3', kind: 'ok', title: "Allan'dan türetilen Kalman modeli",
    text: 'Sensörün gürültü karakteri ölçülüp modele kondu. Renkli gürültüde yanlış alarm ~10 kat azaldı, tespit korundu.',
    plus: ['yanlış alarm ~10× az'], minus: ['EMI sonrası kilitlenme'], ref: '§9',
  },
  {
    v: 'v4', kind: 'ok', title: 'Ortak modun tanımı sıkılaştı',
    text: 'Tek bir sensörün üç ekseni birlikte bozulunca artık "ortam" sayılmıyor; ortak mod en az iki farklı sensör türü istiyor.',
    plus: ['EMI\'de yanlış ortak mod %97 → %0'], minus: ['CUSUM doyması'], ref: '§10',
  },
  {
    v: 'v5', kind: 'fail', title: 'İlk kabul testi: geçemedi',
    text: 'Ölçütler ve ayrılmış senaryolar sonuçtan önce yazılıp kayda geçirildi, test bir kez koşuldu. Çekirdek tespit genellendi; yanlış alarm kuyruğu ve EMI sonrası kaldı.',
    plus: ['tespit %98–100', 'yavaş kayma %100'], minus: ['13 ölçütten 4–5\'i kaldı'], ref: '§11–13',
  },
  {
    v: 'v6', kind: 'ok', title: 'Sıcaklık kaynağı modeli ve çok durumlu çıktı',
    text: 'Sıcaklık kaynağı kilitleri kalktı, olay bitince hızlı bırakma geldi, kalıcı sapma "ofset olayı" olarak ayrı raporlanıyor. Kalan ana sorun: histerezis biçimi uyuşmazlığı.',
    plus: ['kilit 179 → 0', 'EMI sonrası %25 → %0'], minus: ['histerezis uyuşmazlığı'], ref: '§14–16',
  },
  {
    v: 'v7', kind: 'fail', title: 'Denendi, benimsenmedi',
    text: 'Bir düzeltme doğru çıktı ama histerezis sorununu büyüttü; genel olarak v6 daha iyiydi. Seçim kuralına önceki sürümle karşılaştırma eklendi.',
    plus: ['erken bırakma çözüldü'], minus: ['histerezis alarmları arttı'], ref: '§17–18',
  },
  {
    v: 'v8', kind: 'fail', title: 'İkinci histerezis biçimi: kural v6\'da kaldı',
    text: 'Kanal modeli histerezisin ikinci biçimini de tanıyor; bu biçimden gelen yanlış alarmlar neredeyse tamamen gitti. Ama renkli gürültüde kapsama, önceden ilan edilen 1 puanlık toleransı aştı. Tanı kaybın iki kaynağını buldu.',
    plus: ['en kötü yanlış alarm 51,6 → 3,8/saat'], minus: ['renkli kapsama %79,7 → %78,0'], ref: '§19',
  },
  {
    v: 'v9', kind: 'now', title: 'Şu an: iki düzeltme, biri tuttu',
    text: 'İki eşzamanlı arızayı yutan "model güvenilmez" durumu kaldırıldı. Kalıcı sapmayı ofset saymak için "kayma yok"un kanıtını isteyen yeni test rampadaki hatayı çözdü, ama bazı yanlış alarmları bırakamadı. Kural yine v6\'yı seçti. Tanıya göre yeni test, model henüz öğrenilmeden dondurulan kanalları gerçek kaymadan ayıramıyor; bu hâliyle bırakılıyor.',
    plus: ['iki arızada kapsama %55 → %98'], minus: ['en kötü yanlış alarm 53,5/saat'], ref: '§20',
  },
];

// v5 acceptance test, held-out set, one shot (bulgular section 13)
export const acceptance = {
  title: 'v5 kabul testi',
  meta: '10 yeni senaryo × 2 gürültü tipi × 20 tohum = 400 koşu, tek atış',
  groups: [
    {
      name: 'Yanlış alarm',
      rows: [
        ['Tipik koşuda yanlış suçlama', '≤ 0,5 /saat', [true, '0,00'], [true, '0,00']],
        ['En kötü koşuda yanlış suçlama', '≤ 6 /saat', [false, '62,1'], [false, '26,1']],
        ['Yeni başlayan yanlış alarm', '≤ 0,12 /saat', [false, '0,53'], [false, '0,14']],
      ],
    },
    {
      name: 'Tespit',
      rows: [
        ['120 dakika içinde tespit', '≥ %95', [true, '%100'], [true, '%98']],
        ['Gecikme (medyan)', '≤ 15 / 40 dk', [true, '5,5'], [true, '27,0']],
        ['Arıza boyunca suçlu tutma', '≥ %80', [true, '%92,5'], [false, '%66,6']],
        ['Sabit sıcaklıkta yavaş kayma', '≥ %80', [true, '%100'], [true, '%100']],
      ],
    },
    {
      name: 'Tuzaklar',
      rows: [
        ['Isıtıcı sırasında sensör suçlama', '≤ 1 blok', [true, '0,37'], [true, '0,30']],
        ['Olay dışında sıcaklık kaynağı alarmı', '≤ 1 blok', [false, '23,2'], [false, '23,2']],
        ['EMI bittikten sonra manyetometre suçlama', '≤ %10', [false, '%16,0'], [false, '%14,2']],
        ['Sıcaklık sensörü arızasında hareket kanalı suçlama', '≤ %5', [true, '%0,5'], [true, '%2,1']],
        ['Sıcaklık sensörü arızasında ICM suçlama', '≤ %5', [true, '%0,0'], [true, '%0,1']],
        ['Sıcaklık sensörü arızasında "BME" ya da "belirsiz"', '≥ %90', [true, '%100'], [true, '%99,9']],
      ],
    },
  ],
};
