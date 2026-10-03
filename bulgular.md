# MIHENK — Bulgular

Bu dosyada her test/kontrol scripti için şunlar kayıtlıdır: **nerede olduğu, neyi nasıl test ettiği, neden var olduğu ve ne bulduğu.** Her yeni script koşulup yorumlandığında buraya bir girdi eklenir.

**Ortam:** MATLAB R2026a (Windows 11) · Sensor Fusion and Tracking Toolbox + Navigation Toolbox (`imuSensor` ve `allanvar` ortak `shared/positioning` altında).
**Kabul toleransı:** ±%10 (M1 faz çıkış kriteri, [`mihenk.md` §10.4](mihenk.md)).
**Parametre kaynakları:** Her değerin kaynağı script içinde belirtilir: `datasheet` veya `assumed`. İlke için bkz. [`mihenk.md` §S2.5](mihenk.md).
**Klasör düzeni:** [`matlab/README.md`](matlab/README.md). Modeller `matlab/models/`, kontrol scriptleri `matlab/checks/`, G1 prototipleri `matlab/g1/`, figürler [`matlab/figures/`](matlab/figures/) altında. Klasör düzeni §6'dan sonra kuruldu; önceki girdilerdeki commit'ler dosyaları eski yerleriyle (`matlab/reference-model/`, `figures/`) gösterir.

---

## G1 nedir? (kısa açıklama)

Bu bölüm, rapora dönmeden G1'i anlamak için yazıldı. Ayrıntılar [`mihenk.md`](mihenk.md) §1.1, §S1-B, §S6 ve ADR-019/020'de.

**Sorun.** Bir sensörün okuması zamanla değişir. Bu değişim iki farklı şeyden gelebilir. Birincisi **ortamın** kendisinin değişmesi, örneğin havanın ısınması; bu durumda sensör sağlamdır. İkincisi **sensörün** bozulması, örneğin bias'ın kayması. Sahada bu ikisini ayırmak için genelde bir dış referans gerekir: yedek bir sensör, GNSS, aracın modeli ya da cihazı belirli pozisyonlara çevirmek. MIHENK'in hedef senaryosunda bunların hiçbiri yok.

**Gözlem.** Aynı düğümde farklı fiziksel büyüklükleri ölçen sensörler var: gyro (dönme), ivmeölçer (ivme), manyetometre (manyetik alan), gaz sensörü. Ölçtükleri şeyler farklı, ama hepsi **sıcaklıktan** etkileniyor. Sıcaklık hepsinin ortak **konfounderi**, yani ölçümü etkileyen ama arıza olmayan ortak bir dış etken.

**G1'in fikri: termal ortak mod ayrıştırması.** Her kanaldaki değişim iki parçaya ayrılır:
- **Ortak mod:** Sıcaklıkla açıklanabilen ve diğer kanallarda da aynı termal imzayla görülen kısım. → **Sebep ortam.**
- **Kanala özgü mod:** Sıcaklıkla açıklanamayan ve yalnızca o kanalda görülen kısım. → **Sebep o sensör.**

Bu ayrıştırma hiçbir dış referans, yedek sensör, araç modeli veya kullanıcı manevrası gerektirmez. Referans, sensörlerin birbiri olur.

**Neden özgün?**
- Yedekli sensör yöntemleri **aynı türden** birden fazla sensör ister.
- Çok-modlu sağlık izleme yöntemleri sensörleri **makineyi** teşhis etmek için kullanır.
- Farklı türden sensörlerin, paylaştıkları bir konfounder üzerinden **birbirinin** sağlığını teşhis etmesi literatürde boş bir alan.
- Özet: *"Literatür sensörü dünyayı teşhis etmek için kullanır; MIHENK dünyanın fiziksel kısıtlarını sensörü teşhis etmek için kullanır."*

**Neden zor? (G1'i kolay gösterecek tuzaklar)** Ortak mod gerçekte kusursuz değil:
- Her sensörün sıcaklık katsayısı farklı ve bilinmiyor; veri sayfası yalnızca ± bir sınır veriyor (Bulgu 4A).
- Sensörler farklı sıcaklıklarda ve farklı hızlarda ısınıyor: gradyan ve gecikme (Bulgu 5).
- Öz-ısınma kanala özgü bir termal etki yaratıyor. Örneğin gaz ısıtıcısı yalnızca bir sensörü ısıtıyor (Bulgu 5D).
- Histerezis nedeniyle ısınma ve soğuma yollarında bias farklı.
- Her çevresel etki ortak mod değil. Örneğin bir motorun manyetik gürültüsü (EMI) yalnızca manyetometreyi bozar.
- İki sensör aynı anda ama bağımsız olarak bozulursa bu, ortak mod gibi görünebilir.
- Sıcaklığı ölçen sensörün kendisi hatalı olabilir; ofseti ±5 °C'ye kadar çıkabiliyor (Bulgu 4E).

Rapor bu tuzakları "müfredat sınıf 8" olarak topluyor. G1'in değeri kolay senaryolarda değil, bu tuzaklarda ölçülecek.

**Nasıl kanıtlanacak?** G1'in katkısı ancak **ablasyonla** gösterilebilir. Aynı teşhis sistemi G1 dahil ve G1 hariç koşulur, aradaki fark ölçülür (raporda B4 temel çizgisi). Bu fark ölçülmeden katkı iddia edilemez. Ayrıca iddia hep niteleyicileriyle kurulur. Çıplak bir "referanssız IMU arıza tespiti" iddiası yasaktır, çünkü o alan literatürde zaten dolu (ADR-019).

**MIHENK'teki yeri.** G1, tanı çekirdeğinin (Katman 1) ilk ve en öncelikli testi. Sonunda ATmega328P'de, 2 KB SRAM içinde, fixed-point aritmetikle çalışması gerekiyor. Çıktısı ikili bir "bozuk / sağlam" bayrağı değil, kalibre edilmiş sürekli bir güven skoru olmalı (ADR-010).

---

## Özet

| # | Script | Test edilen | Sonuç |
|---|---|---|---|
| 1 | [`first_allan_check.m`](matlab/checks/first_allan_check.m) | Beyaz gürültü yoğunluğu (N) | ✅ −%0,04 (düzeltme sonrası) |
| 2 | [`allan_noise_terms_check.m`](matlab/checks/allan_noise_terms_check.m) | Rate random walk (K), bias instability (B) | ✅ K, ✅ B (1/f filtresiyle) · ❌ B (varsayılan filtre) |
| 3 | [`thermal_model_check.m`](matlab/checks/thermal_model_check.m) | Sıcaklık bias'ı ve ölçek faktörü, sıcaklık değişimi altında gürültü sürekliliği | ✅ Formül tam (hata 0) · ✅ N, K |
| 4 | — (veri sayfası teyidi) | ICM-42688-P parametreleri, DS-000347 Rev 1.6 | Termal katsayılar ve gyro N teyit edildi · B ve K veri sayfasında yok · sıcaklık sensörü ofseti ±5 °C |
| 5 | [`thermal_node_check.m`](matlab/checks/thermal_node_check.m) | Sensör başına sıcaklık: gecikme, gradyan, öz-ısınma, histerezis | ✅ C1–C4 makine hassasiyetinde · ortak mod artık kusurlu |
| 6 | [`g1_prototype_v0.m`](matlab/g1/v0/g1_prototype_v0.m) | G1 ilk prototip: ortak mod / kanala özgü ayrıştırma | ✅ ısıtıcı tuzağı çözüldü · ⚠️ histerezis, gecikme ve pencere uyumu zayıflıkları |
| 7 | [`g1_prototype_v1.m`](matlab/g1/v1/g1_prototype_v1.m) | G1 v1: hafızalı model, CUSUM, histerezis ve gecikme seçimi | ✅ kapsama %98, yanlış alarm 0 · ⚠️ tek senaryoya ayarlı, histerezis modeli simülatörle aynı |
| 8 | [`g1_prototype_v2.m`](matlab/g1/v2/g1_prototype_v2.m) | v0 ve v1'in 9 senaryo × 5 tohumla sınavı | ✅ v1 beyaz gürültüde tohumdan bağımsız · ❌ v1 renkli gürültüde çöküyor (saatte 115–195 yanlış alarm) · ❌ EMI çözülemiyor |
| 9 | [`g1_prototype_v3.m`](matlab/g1/v3/g1_prototype_v3.m) | G1 v3: Allan'dan türetilmiş Kalman sıfır modeli, faktöriyel değerlendirme (8 senaryo × 2 gürültü × 5 tohum) | ✅ renkli gürültüde yanlış alarm ~10× azaldı, kapsama korundu · ❌ EMI sonrası kilitlenme, BME suçu ICM'ye gidiyor, model uyuşmazlığında beyaz gürültüde kilitlenme |
| 10 | [`g1_prototype_v4.m`](matlab/g1/v4/g1_prototype_v4.m) | G1 v4: çok elemanlı ortak mod, belirsiz kaynak durumu, model hatası tabanı (10 tohum) | ✅ 9E ve 9F mekanizmaları doğrulandı · ✅ hyst-relax kilitlenmesi çözüldü · ❌ model hatası tabanı gecikmeyi ~45 dk artırıyor · ❌ CUSUM doyması, baştan kilitli kanal (tanı 10F: ilişkili artık + donmuş z sıfıra dönmüyor; model tanımlanmadan dondurma) |
| 11 | [`g1_acceptance_test.m`](matlab/g1/test/g1_acceptance_test.m) | G1 simülasyon aşamasının kabul ölçütleri ve ayrılmış test kümesi (önceden ilan) | Ölçütler, senaryolar ve test v5 sonuçlarından önce commit'lendi |
| 12 | [`g1_prototype_v5.m`](matlab/g1/v5/g1_prototype_v5.m) | G1 v5 geliştirme koşusu: CUSUM üst sınırı, dondurulmuş kanalda taban, serbest bırakma testi, model değişiminde sıfırlama | ✅ aday v5 · ✅ baştan kilitlenme gitti · ❌ geliştirmede K1b, K3a, K3c, K3d kalıyor · ⚠️ basamak arızası serbest bırakılıyor |
| 13 | [`g1_acceptance_test.m`](matlab/g1/test/g1_acceptance_test.m) | Kabul testi, ayrılmış küme (10 senaryo × 2 gürültü × 20 tohum), tek atış | ❌ **FAIL** (K1b, K1c, K2c renkli, K3b, K3c) · ✅ tespit, gecikme, manyetometre arızası, BME basamağı genelleniyor |
| 14 | [`g1_diag_tsrc_lock.m`](matlab/g1/v6/g1_diag_tsrc_lock.m) | Tanı: sıcaklık kaynağı modelinin kilitlenmesi (13D), kapılı / kapısız / ısıtıcısız | ✅ kopya 200/200 birebir · T2/T5: ısıtıcı tetikliyor, yanlış eğim ve payı olmayan sT kilitliyor · T8: model yapısı uyuşmazlığı · ❌ kapıyı kaldırmak çözüm değil |

**Kritik kurallar** (MATLAB referans modelinde her zaman uygulanacak):

1. `NoiseType` her zaman `'single-sided'` olarak verilir. Varsayılan `'double-sided'` N'yi √2 küçük, K'yı √2 büyük üretir ve bunu sessizce yapar. → Bulgu 1, 2A
2. Bias instability için `BiasInstabilityCoefficients` her zaman `fractalcoef(K, 1)` olarak verilir. Varsayılan filtre 1/f gürültüsü üretmez. → Bulgu 2B
3. `imuSensor`'ın termal modeli G1 için tek başına **yetersizdir**. Gradyan, histerezis ve öz-ısınma modelin dışında kurulmalıdır. → Bulgu 3

---

## 1. Beyaz gürültü yoğunluğu (N)

**Script:** [`matlab/checks/first_allan_check.m`](matlab/checks/first_allan_check.m)
**Commit:** `3851487`

**Amaç:** İ7 ilkesi, yani "sensör modeli kendi kendini doğrular" ([`mihenk.md` §2](mihenk.md)). CI kapısı #3'ün (Allan tutarlılığı) ve [ADR-014](mihenk.md)'ün MATLAB tarafındaki ilk örneği. Modele verilen gürültü parametresi üretilen veriden geri çıkarılamıyorsa, bu modelle üretilen hiçbir sonuca güvenilemez.

**Ne test ediyor:** `imuSensor`'a verilen gyro gürültü yoğunluğunun (N), üretilen sinyalin Allan sapmasından geri okunabilmesi.

**Nasıl:**
- ICM-42688-P veri sayfası değerleri kullanılıyor (`datasheet`): gyro 2,8 mdps/√Hz. İvmeölçer ilk koşuda üç eksende 70 µg/√Hz idi; veri sayfası teyidinden sonra X/Y 65, Z 70 µg/√Hz olarak düzeltildi (Bulgu 4). Test yalnızca gyroyu ölçtüğü için sonuç etkilenmiyor.
- Sensör 100 Hz'de 2 saat boyunca sanal olarak durağan tutuluyor.
- Gyro X'in Allan sapması hesaplanıyor. Saf beyaz gürültüde `σ(τ) = N/√τ` olduğundan, `σ(τ)·√τ` değerinin τ ≤ T/10 aralığındaki medyanı N'nin kestirimi olarak alınıyor.

**Sonuç:**

| Koşu | Verilen N | Bulunan N | Hata | Durum |
|---|---|---|---|---|
| İlk (varsayılan ayar) | 4,8869e-05 | 3,4539e-05 | −%29,32 | ❌ |
| `NoiseType = 'single-sided'` | 4,8869e-05 | 4,8849e-05 | −%0,04 | ✅ |

**Bulgu: MATLAB'ın `NoiseType` konvansiyonu.**
- İlk koşudaki oran 0,7068 ≈ 1/√2 çıktı; bu kadar temiz bir sayı bir konvansiyon farkına işaret ediyordu.
- Kaynak kod bunu doğruladı (`IMUSensorSimulator.m`, `setupBandwidth`). Varsayılan `"double-sided"` ayarında beyaz gürültünün standart sapması `N·√(Fs/2)` olarak kuruluyor.
- Veri sayfası değeri ve IEEE Allan N'si ise tek taraflı PSD'ye göre tanımlı; doğru standart sapma `N·√Fs`.
- Aynı veri sayfası değeri, iki farklı uygulamada √2 farklı gürültü üretiyor ve hiçbir uyarı çıkmıyor.

**Sonuçları:**
- MATLAB ↔ MIHENK çapraz doğrulamasında ([ADR-012](mihenk.md)) bu fark "model hatası" gibi görünürdü.
- Ortak JSON parametre dosyasına PSD konvansiyonu açıkça yazılmalı.
- Bu hata, İ6/İ7'nin neden zorunlu olduğunun somut bir örneği.

**Not:** Bu script sabit bir tohum kullanmıyor, bu yüzden sonuç koşudan koşuya çok az değişir. Sonraki scriptler `'mt19937ar with seed'` kullanıyor (İ2).

---

## 2. Rate random walk (K) ve bias instability (B)

**Script:** [`matlab/checks/allan_noise_terms_check.m`](matlab/checks/allan_noise_terms_check.m)
**Commit:** `d0169a2`

**Amaç:** Beyaz gürültü dışındaki iki stokastik terimin IEEE Std 952 [R2] tanımlarına uyup uymadığını görmek. Bu, olmazsa olmaz #4 ile ilgili ("Allan-tutarlı gürültü sentezi, 1/f dahil"). Bu doğrulama yapılmazsa [§11](mihenk.md)'deki "sentetik gürültünün kolaylığı" riski gerçekleşir: yöntem beyaz gürültüde çalışır, gerçek 1/f gürültüsünde çöker.

**Ne test ediyor:** Her terim **tek başına** simüle ediliyor ve Allan eğrisinin hem büyüklüğü hem eğimi kontrol ediliyor.

| Terim | IEEE beklentisi | Beklenen eğim |
|---|---|---|
| Rate random walk K | `σ(τ) = K·√(τ/3)` | +½ |
| Bias instability B | Düz taban, `0,664·B` (`√(2 ln2/π)·B`) | 0 |

**Nasıl:**
- Değerler yer tutucu (`assumed`): K = 20 °/h/√h, B = 5 °/h. Her terim tek başına koşulduğu için yalnızca ölçülen/beklenen oranı önemli.
- A durumu: 100 Hz, 2 saat, `single-sided` ve `double-sided` ayarları yan yana. K, `σ·√(3/τ)` değerinin medyanından kestiriliyor.
- B durumu: varsayılan `BiasInstabilityCoefficients` ile. Taban değeri τ ∈ [1 s, T/10] aralığındaki medyan Allan değeri.
- C durumu: `fractalcoef(2000, 1)` ile (Kasdin 1/f filtresi [R3], 2000 kutup). Maliyeti düşük tutmak için 10 Hz ve 4 saat. Taban değeri τ ∈ [1, 100] s aralığından.
- Eğim, log-log düzlemde doğrusal fit ile hesaplanıyor.
- Sabit tohumlar kullanılıyor.

**Sonuç:**

| Durum | Beklenen | Ölçülen | Hata | Eğim | Durum |
|---|---|---|---|---|---|
| A RRW, single-sided | 1,6160e-06 | 1,6191e-06 | +%0,19 | +0,49 | ✅ |
| A RRW, double-sided | 1,6160e-06 | 2,2898e-06 | +%41,69 | +0,49 | ❌ |
| B BI, varsayılan filtre | 1,6103e-05 | 8,5636e-07 | −%94,68 | **−0,50** | ❌ |
| C BI, 1/f filtre (2000 kutup) | 1,6103e-05 | 1,6156e-05 | +%0,33 | +0,01 | ✅ |

**Bulgu 2A: Random walk'ta da `NoiseType` etkili, bu sefer ters yönde.** Adım başına standart sapma `K/√bandwidth`. `double-sided` ayarında K √2 büyük çıkıyor (1,4169). Kural 1 burada da geçerli.

**Bulgu 2B: MATLAB'ın varsayılan "BiasInstability" ayarı gerçek bir bias instability değil.**
- Varsayılan `fractalcoef(1,1)` filtresi `1/(1 − 0,5·z⁻¹)`. Bu filtrenin hafızası 2 örneklik; yani bir Gauss-Markov süreci.
- Allan eğimi −0,50 çıktı, beyaz gürültüyle aynı. Beklenen düz taban hiç oluşmuyor.
- Veri sayfasındaki "bias instability" değerini bu parametreye doğrudan yazmak, istenen 1/f gürültüsünü üretmiyor. Bu da hata vermeden oluyor.

**Bulgu 2C: `fractalcoef(K, 1)` ile ölçekleme IEEE tanımıyla birebir örtüşüyor.**
- Taban tam 0,664·B, eğim ≈ 0.
- Sınırı: filtre yalnızca τ ≈ K/Fs saniyeye kadar geçerli ve her örnekte O(K) işlem yapıyor.
- 1 kHz'de uzun τ'lara çıkmak ~10⁵ kutup gerektirir; bu çok pahalı.
- **MIHENK Python modeli için çıkarım:** verimli bir 1/f üreteci gerekecek. Adaylar: FFT tabanlı Kasdin yöntemi veya Gauss-Markov süreçlerinin toplamı.

---

## 3. Termal model

**Script:** [`matlab/checks/thermal_model_check.m`](matlab/checks/thermal_model_check.m)
**Commit:** `41128f7`

**Amaç:** Sıcaklık, merkezi katkının (G1) fiziksel dayanağı ([`mihenk.md` §S1-B](mihenk.md), [ADR-020](mihenk.md)). Referans modelin sıcaklık etkisini nasıl ve ne kadar doğru uyguladığını bilmek gerekiyor. Ayrıca MIHENK senaryolarında sıcaklık sürekli değişeceği için, sıcaklık güncellemelerinin gürültü üretimini bozmadığından emin olmak gerekiyor.

**Kaynak koddan okunan model** (`IMUSensorSimulator.m`):

```
çıktı = (1 + ΔT · TemperatureScaleFactor/100) · (ideal + gürültü + ΔT · TemperatureBias)
ΔT    = Temperature − 25 °C
```

**Ne test ediyor:**
- **T1:** Deterministik formülün birebir uygulanması. Ölçek faktörü hatasının termal bias'ı da çarpması bu testin kapsamında.
- **T2:** `Temperature` her güncellendiğinde gürültü durumlarının (filtre ve random walk birikimi) korunması.

**Nasıl:**
- Sıcaklık profili 4 saat sürüyor: 25 → 45 °C rampa (1 saat), 45 °C'de bekleme (1 saat), 45 → 25 °C rampa (1 saat), 25 °C'de bekleme (1 saat).
- `Temperature` her saniye güncelleniyor; `imuSensor` 1 saniyelik parçalar hâlinde adımlanıyor.
- Termal katsayılar 0,005 dps/°C ve 0,005 %/°C. İlk koşuda `assumed` olarak girildiler; veri sayfasından aynı değerler teyit edildi ve kaynak `datasheet` oldu (Bulgu 4). Veri sayfası bunları ± sınır olarak veriyor; script üst sınırı kullanıyor.
- T1: sensör 100 dps'lik bir döner tablada, gürültü yok. Çıktı formülle karşılaştırılıyor; ölçüt maksimum göreli hata < 1e-9.
- T2: gyroya N (veri sayfası) + K (1e-5, `assumed`) + termal bias veriliyor. Bilinen termal terim çıkarılıyor. Artığın Allan varyansına `σ² = N²/τ + K²τ/3` modeli göreli-hata ağırlıklı en küçük karelerle fit ediliyor.

**Sonuç:**

| Test | Beklenen | Ölçülen | Hata | Durum |
|---|---|---|---|---|
| T1 deterministik formül | — | — | 0,00e+00 | ✅ |
| T2 N | 4,8869e-05 | 4,8952e-05 | +%0,17 | ✅ |
| T2 K | 1,0000e-05 | 1,0153e-05 | +%1,53 | ✅ |

**Bulgu 3A:** Formül kaynak kodda okunduğu gibi, makine hassasiyetinde uygulanıyor.

**Bulgu 3B:** `Temperature` çalışma sırasında değiştirildiğinde gürültü durumları sıfırlanmıyor. Parça parça adımlama güvenli.

**Bulgu 3C: Ham Allan eğrisi termal kaymayla bozuluyor** *(önce hesapla öngörüldü, sonra figürle teyit edildi)*.
- Öngörü: Rampa sırasındaki kayma hızı R = 0,005 dps/°C × 20 °C/h ≈ 4,8e-7 rad/s². Bu kayma Allan eğrisine `R·τ/√2` terimini ekliyor. τ ≈ 1000 s civarında bu terim (~3,4e-4), K teriminden (~1,8e-4) büyük.
- Figür ([`matlab/figures/thermal_model_2.png`](matlab/figures/thermal_model_2.png)): τ ≈ 40 s'ye kadar iki eğri üst üste. Sonra ham eğri yukarı ayrılıyor; τ ≈ 1000 s'de aradaki fark yaklaşık 2 kat. Öngörüyle uyumlu.
- Ek gözlem: Termal terimi çıkarılmış eğri de τ ≳ 1300 s'de beklenen çizginin biraz üstüne çıkıyor. Bu aralık, fit aralığının (τ ≤ T/10 = 1440 s) dışında. 4 saatlik veride o τ değerlerinde yalnızca birkaç bağımsız küme kaldığı için bu istatistiksel belirsizlik.

Sonuç olarak, termal terim çıkarılmadan hesaplanan eğri uzun τ'larda yükselir ve gerçek K'yı maskeler. Bu, gerçek logların Allan analizinde sıcaklığın da kaydedilmesi ve etkisinin ayrıştırılması gerektiğini gösteriyor ([`mihenk.md` §14.2/2](mihenk.md)).

**Bulgu 3D: `imuSensor`'ın termal modeli G1 için yapısal olarak yetersiz.** Bu bir test sonucu değil, kaynak kod okumasından çıkan bir tespit:

| Eksik | Neden önemli |
|---|---|
| Tek bir `Temperature` değeri ivmeölçer, gyro ve manyetometrenin **hepsine** uygulanıyor | Kanallar arasında gradyan yok, ortak mod **kusursuz**. Bu, [§11](mihenk.md)'deki ★ "kusursuz ortak mod" riskinin ta kendisi; G1'i yapay biçimde kolay gösterir. |
| Sıcaklık etkisi yalnızca doğrusal, referans 25 °C'de sabit | Doğrusal olmayan termal katsayılar modellenemiyor |
| Termal histerezis yok | Isıtma ve soğutma yolları aynı |
| Öz-ısınma yok | Kanala özgü termal etki üretilemiyor; müfredat sınıf 8'deki "öz-ısınma yanılgısı" tuzağı kurulamıyor |
| Termal gecikme (zaman sabiti) yok | Sensör, ortam sıcaklığını anında izliyor |

**Sonuçları:** MATLAB referans modelinde her sensör **ayrı bir `imuSensor` nesnesiyle** kurulmalı ve her birine kendi sıcaklığı verilmeli. Bu sıcaklıklar, gradyan, histerezis, öz-ısınma ve gecikmeyi modelleyen ayrı bir termal modelden gelmeli. `imuSensor` yalnızca "sıcaklık → bias/ölçek" dönüşümünü yapmalı.

---

## 4. ICM-42688-P veri sayfası teyidi

**Script:** yok. Bu girdi, veri sayfasından yapılan parametre teyidinin kaydıdır.
**Kaynak:** TDK InvenSense, *ICM-42688-P Datasheet*, DS-000347, **Rev 1.6 (06/20/2021)** [R1]. Dosya repoda: [`docs/ds-000347-icm-42688-p-v1.6.pdf`](docs/ds-000347-icm-42688-p-v1.6.pdf). Değerler Tablo 1 (gyro, s. 11), Tablo 2 (ivmeölçer, s. 12), Tablo 4 (sıcaklık sensörü, s. 14) ve §4.13'ten alındı.

**Sürüm karşılaştırması:**
- Teyit önce Rev 1.5 (05/05/2021) üzerinde yapıldı, sonra Rev 1.6 ile karşılaştırıldı.
- İki sürümün metinleri çıkarılıp boşluklar yok sayılarak karşılaştırıldı. **Tablo 1, 2 ve 4 birebir aynı.**
- Rev 1.6'daki değişiklikler SPI zamanlaması, saat kaynağı ve APEX gibi, modelimizi etkilemeyen konularda.

**Amaç:** Scriptlerdeki `assumed` değerleri `datasheet` kaynağına taşımak ([`mihenk.md` §S2.5](mihenk.md), [ADR-015](mihenk.md)). Ayrıca veri sayfasının **neyi vermediğini** belgelemek.

**Teyit edilen değerler** (tablolarda "TA = 25 °C, VDD = 1,8 V" koşulunda):

| Parametre | Gyro | İvmeölçer | Koşul | Veri sayfası notu |
|---|---|---|---|---|
| Gürültü yoğunluğu | 0,0028 °/s/√Hz | X/Y 65, **Z 70** µg/√Hz | @ 10 Hz | — |
| Toplam RMS gürültü | 0,028 °/s-rms | X/Y 0,65, Z 0,70 mg-rms | BW = 100 Hz | Gürültü yoğunluğundan hesaplanmış |
| Hassasiyet başlangıç toleransı | ±%0,5 | ±%0,5 | 25 °C, bileşen ve kart seviyesi | — |
| **Hassasiyetin sıcaklıkla değişimi** | **±0,005 %/°C** | **±0,005 %/°C** | gyro 0…70 °C; ivme −40…+85 °C | Karakterizasyondan türetilmiş, üretimde test edilmiyor |
| Doğrusalsızlık | ±%0,1 | ±%0,1 | En iyi doğru uydurma | — |
| Eksenler arası duyarlılık | ±%1,25 | ±%1 | Kart seviyesi | — |
| Başlangıç ofseti (ZRO / zero-g) | ±0,5 °/s | ±20 mg | Kart seviyesi | — |
| **Ofsetin sıcaklıkla değişimi** | **±0,005 °/s/°C** | **±0,15 mg/°C** | gyro 0…70 °C; ivme −40…+85 °C | Karakterizasyondan türetilmiş, üretimde test edilmiyor |
**Sıcaklık sensörü** (Tablo 4 ve §4.13):

| Parametre | Değer | Koşul |
|---|---|---|
| Çalışma aralığı | −40 … +85 °C | Ortam |
| ADC çözünürlüğü | 16 bit | — |
| Hassasiyet | 132,48 LSB/°C (≈ 0,0075 °C/LSB) | **Trimlenmemiş (untrimmed)** |
| FIFO verisi hassasiyeti | 2,07 LSB/°C (≈ 0,48 °C/LSB) | 8 bit FIFO alanı |
| **Oda sıcaklığı ofseti** | **−5 … +5 °C** | 25 °C |
| Dönüşüm | `TEMP_DATA/132,48 + 25` °C · `FIFO_TEMP_DATA/2,07 + 25` °C | §4.13 |

`pdftotext` tablo sütunlarını karıştırdığı için değer–satır eşleştirmesi okuma sırasından yapıldı. Gyro ofset katsayısı (±0,005 °/s/°C) ayrıca bağımsız bir kaynakla doğrulandı. PDF açılıp tablolar bir kez gözle kontrol edilirse bu çekince kalkar.

**Bulgu 4A: Termal katsayılar tek bir değer değil, parçalar arası ± sınır.**
- Veri sayfası belirli bir sensörün katsayısını vermiyor. Verdiği şey, "üretilen parçaların katsayısı bu aralıkta" bilgisi. İşareti de belli değil.
- Değerler karakterizasyondan türetilmiş, üretimde test edilmiyor.
- **G1'e etkisi:** Her fiziksel sensörün kendi katsayısı var ve bunu önceden bilmiyoruz. Simülasyonda katsayıyı sabit vermek yerine her sanal birim için ±sınır içinden örneklemek daha gerçekçi. Bu, kanalların sıcaklığa **farklı** tepki vermesini doğal olarak sağlar; G1'in ayrıştırması tam da bu farka dayanıyor ([`mihenk.md` §S1-B](mihenk.md)).
- Gerçek katsayılar ancak termal salınım logundan ölçülebilir ([§14.2/2](mihenk.md), Ek C.3).

**Bulgu 4B: Veri sayfası bias instability ve rate random walk vermiyor.** Allan terimlerinden yalnızca beyaz gürültü (N) veri sayfasında. B ve K hiçbir zaman `datasheet` kaynaklı olamaz. Tek kaynak kendi statik logumuz (`allan_fit`) veya literatür. Bu, gece boyu statik kaydın önceliğini artırıyor.

**Bulgu 4C: Veri sayfası termal modelin yalnızca doğrusal kısmını veriyor.** Histerezis, termal gecikme ve öz-ısınma için bir değer yok; katsayılar doğrusal °C başına değişim olarak verilmiş. Bulgu 3D'de sayılan eksikler, veri sayfasından da doldurulamıyor; ölçüm gerekiyor.

**Bulgu 4D: İvmeölçer gürültüsü eksene bağlı.** Z ekseni X/Y'den gürültülü (70'e karşı 65 µg/√Hz). Raporda (Ek C.1) tek değer olarak 70 µg/√Hz geçiyor. `first_allan_check.m` eksen bazlı değerlerle güncellendi.

**Bulgu 4E: Çip üstü sıcaklık sensörü ince çözünürlüklü ama mutlak değeri güvenilmez.**
- **Çözünürlük okuma yoluna bağlı.** Register'dan 16 bit okunduğunda ~0,0075 °C/LSB, FIFO'daki 8 bit alanda ~0,48 °C/LSB. G1 için termal imzanın 0,5 °C'lik adımlarla okunması çok kaba; firmware sıcaklığı register'dan (`TEMP_DATA`) okumalı. FIFO'nun yüksek çözünürlüklü (20 bit) paket biçiminin sıcaklık alanı henüz incelenmedi.
- **Mutlak doğruluk zayıf.** 25 °C'de ofset ±5 °C'ye kadar çıkabiliyor ve hassasiyet trimlenmemiş, yani kazanç hatası da belirsiz. Ölçülen şey ortam değil, kalıp (die) sıcaklığı; öz-ısınmayı da içeriyor.
- *Düzeltme:* Bu maddenin ilk hâlinde "doğruluk spesifikasyonu yok" yazıyordu. Bu yanlıştı. Arama aracı metin dosyasını ikili sandığı için Tablo 4'ü kaçırmıştı; Rev 1.6 karşılaştırması sırasında bulundu. Tablo Rev 1.5'te de aynı.

**Sonuçları:**
- G1 **mutlak** sıcaklığa değil, sıcaklık **değişimine** dayanmalı. Değişim ince çözünürlükle ölçülebiliyor; mutlak değer ±5 °C belirsiz.
- ICM çip üstü sensörü ile BME688 karşılaştırılırken aralarında 5 °C'ye varan sabit bir ofset ve bir kazanç farkı olacağı baştan varsayılmalı. Aksi hâlde bu fark "arıza" gibi görünür. Müfredat sınıf 7 ("konfounder sensörünün kendisi arızalı") ancak bu ofset modellenince anlamlı olur.
- Simülasyondaki sıcaklık sensörü modeline her sanal birim için ±5 °C içinden örneklenmiş bir ofset ve belirsiz bir kazanç eklenmeli.

---

## 5. Sensör başına sıcaklık modeli

**Model:** [`matlab/models/thermal_node.m`](matlab/models/thermal_node.m) (fonksiyon; tek başına çalıştırılmaz)
**Script:** [`matlab/checks/thermal_node_check.m`](matlab/checks/thermal_node_check.m)
**Figürler:** [`matlab/figures/thermal_node_1.png`](matlab/figures/thermal_node_1.png), [`matlab/figures/thermal_node_2.png`](matlab/figures/thermal_node_2.png). Script figürleri kendisi kaydediyor.

**Amaç:** Bulgu 3D'de tespit edilen eksikleri kapatmak. `imuSensor` tüm sensörlere tek bir sıcaklık uyguluyor ve bu da kusursuz bir ortak mod yaratıyor ([`mihenk.md` §11](mihenk.md) ★ riski). G1'in gerçekten sınanabilmesi için ortak modun **kusurlu** olması gerekiyor: her sensörün kendi sıcaklığı olmalı ([`mihenk.md` §S1-B](mihenk.md): "gradyan, histerezis ve öz-ısınma zorunlu").

**Model:** Her sensör birinci mertebe bir ısıl kütle olarak ele alınıyor:

```
τ · dT/dt = T_ortam + gradyan + R_th · P − T        (sıfırıncı mertebe tutma ile tam çözüm)
T_eff     = play(T, genişlik)                       (histerezis, backlash operatörü)
```

- `T` (kalıp sıcaklığı) sensörün **sıcaklık okumasına** gidiyor. `T_eff` ise **termal bias'a** gidiyor ve `imuSensor.Temperature`'a veriliyor. İkisinin farkı histerezisin kendisi.
- ICM ivmeölçeri ve gyrosu aynı kalıpta olduğu için aynı sıcaklığı paylaşıyor. Manyetometre ve BME688 ayrı çipler, dolayısıyla ayrı sıcaklıkları var.
- Birim bazında örnekleme yapılıyor: gyro termal katsayısı her eksen için ±0,005 dps/°C içinden (Bulgu 4A), sıcaklık okuma ofseti ±5 °C içinden (Bulgu 4E) seçiliyor. Tohum sabit.

**Parametreler:**

| Sensör | τ [s] | Gradyan [°C] | R_th [°C/W] | P [mW] | Histerezis [°C] |
|---|---|---|---|---|---|
| ICM-42688-P | 120 | 0 | 150 | 1,58 (`datasheet`: 0,88 mA × 1,8 V, Tablo 3) | 1,0 |
| Manyetometre | 90 | +0,5 | 150 | 1 | 0 |
| BME688 | 200 | −0,3 | 150 | 1, 2,0–2,25 saat arasında +10 (gaz ısıtıcısı) | 0 |

ICM gücü dışındaki tüm değerler `assumed` yer tutucular. Gerçek değerler termal salınım kaydından çıkacak ([§14.2/2](mihenk.md), Ek C.3).

**Ne test ediyor ve nasıl:**
- **C1:** Parametreleri aynı olan üç sensör, 10 °C genlikli sinüs ortamında aynı sıcaklığı vermeli.
- **C2:** Ortam 25 → 35 °C basamak yaptığında her sensör t = τ anında basamağın %63,2'sine ulaşmalı.
- **C3:** 10 mW'lık güç basamağından sonra kalıcı sıcaklık artışı R_th·P olmalı.
- **C4:** Gyro bias'ı `imuSensor` üzerinden üretiliyor. Profil 5 saat: 25 → 45 → 25 °C, rampalar 1'er saat. Aynı kalıp sıcaklığında (35 °C) soğuma ve ısınma yollarındaki bias farkı `k_b · genişlik` olmalı.

**Sonuç:**

| Test | Ölçüt | Sonuç | Durum |
|---|---|---|---|
| C1 aynı sensörler | maks. \|ΔT\| < 1e-12 °C | 0 | ✅ |
| C2 termal gecikme | maks. hata < 1e-9 °C | 1,07e-14 °C | ✅ |
| C3 öz-ısınma | göreli hata < 1e-9 | 2,37e-13 | ✅ |
| C4 histerezis farkı | göreli hata < 1e-6 | 9,16e-16 (beklenen = ölçülen = −7,3948e-05 rad/s; örneklenen k_b,x = −0,0042 dps/°C) | ✅ |

**Ortak modun kusurluluğu** (5 saatlik profilde, bilgi amaçlı):

| Sensör | maks. \|T_kalıp − T_ortam\| |
|---|---|
| ICM-42688-P | 0,91 °C |
| Manyetometre | 1,15 °C |
| BME688 | 1,33 °C |

ICM sıcaklık okuması ile BME688 kalıp sıcaklığı arasındaki fark: ortalama +2,55 °C, değişim aralığı 1,93 °C. Birime atanan ofset +2,23 °C.

**Bulgu 5A: Model tasarlandığı gibi çalışıyor.** C1–C4 makine hassasiyetinde geçti. Figürdeki sayılar elle yapılan hesaplarla da tutuyor:
- Kalıcı durumda ICM ortamın +0,24 °C üstünde (150 °C/W × 1,58 mW). Manyetometre +0,65 °C (gradyan 0,5 + öz-ısınma 0,15), BME688 −0,15 °C.
- BME688 en yavaş sensör (τ = 200 s), rampalarda en çok o geride kalıyor.
- Isıtıcı patlaması BME688'i ~1,5 °C ısıtıyor, diğer sensörler etkilenmiyor.

**Bulgu 5B: Birim ofseti, gerçek fiziksel farklardan büyük.** Sensörler arasındaki gerçek sıcaklık farkları 0,9–1,3 °C mertebesinde. ICM sıcaklık okumasının ofseti ise tek başına +2,23 °C ve ±5 °C'ye kadar çıkabiliyor. Mutlak sıcaklıkları kaynaklar arasında karşılaştırmak, fiziği değil ofseti ölçer. Bu, Bulgu 4E'deki sonucu sayısal olarak doğruluyor: G1 sıcaklık **değişimlerine** dayanmalı.
- ICM okuması ile BME688 arasındaki farkın 1,93 °C'lik değişim aralığının neredeyse tamamı iki kaynaktan geliyor. ~1,5 °C'si ısıtıcıdan (kanala özgü öz-ısınma). ~0,44 °C'si iki sensörün gecikme farkından: 80 s × 20 °C/saat.

**Bulgu 5C: Gecikme, ortamdan bakan bir gözlemciye histerezis gibi görünüyor.** ([`matlab/figures/thermal_node_2.png`](matlab/figures/thermal_node_2.png))
- **Sol panel:** Bias kalıp sıcaklığına göre çizildiğinde döngü yalnızca histerezisten geliyor. Genişliği 1 °C, bias'ta ~0,004 dps.
- **Sağ panel:** Aynı bias ortam sıcaklığına göre çizildiğinde döngü ~2,3 kat genişliyor. ICM'nin 120 s'lik gecikmesi, 20 °C/saat rampada her yönde ~0,67 °C'lik ek açıklık ekliyor: 1 + 2 × 0,67 ≈ 2,3 °C, bias'ta ~0,01 dps.
- **G1 için sonucu:** Yalnızca ortam sıcaklığını (BME688) gören bir teşhis yöntemi, gerçek histerezisi gecikmeden ayıramaz. Termal ayrıştırmada her sensörün **kendi** sıcaklığı ya da gecikmeyi hesaba katan bir model kullanılmalı. Bu, ICM'nin çip üstü sıcaklık sensörünün neden kritik olduğunu da gösteriyor (Ek C.1).

**Bulgu 5D: Isıtıcı patlaması, müfredat sınıf 8'deki "öz-ısınma yanılgısı" tuzağının çalışan ilk örneği.** BME688'in sıcaklığı 15 dakika boyunca +1,5 °C sapıyor, diğer kanallar etkilenmiyor. Ortam değişmediği hâlde kanala özgü bir termal olay var. Bir ortak mod dedektörü bunu "BME688 arızalı" diye yanlış yorumlayabilir. Bu senaryo artık üretilebiliyor.

---

## 6. G1 prototipi v0

**Script:** [`matlab/g1/v0/g1_prototype_v0.m`](matlab/g1/v0/g1_prototype_v0.m)
**Figürler:** [`matlab/figures/g1_v0_1.png`](matlab/figures/g1_v0_1.png), [`matlab/figures/g1_v0_2.png`](matlab/figures/g1_v0_2.png)

**Amaç:** G1'in (bkz. "G1 nedir?") ilk çalışan prototipi. İki soruya yanıt arıyor: en basit ortak mod ayrıştırması bir sensör arızasını ortam değişiminden ve kanala özgü bir termal tuzaktan ayırabiliyor mu? Ve G1'i zorlayan şeyler ilk nerede ortaya çıkıyor? Bu, raporun M1-M izindeki "Katman 1 prototipi" adımı.

**Senaryo:** Durağan bir düğüm, süre 8 saat. Sensör başına sıcaklıklar `thermal_node.m`'den geliyor. Firmware yalnızca 9 hareket kanalını (gyro, ivmeölçer, manyetometre × 3 eksen) ve 2 sıcaklık okumasını (ICM, BME688) görüyor. Gerçek değerler (ground truth) yalnızca değerlendirmede kullanılıyor.

| Olay | Zaman | Gerçekte | Doğru cevap |
|---|---|---|---|
| Ortam 25 → 40 → 25 °C | Rampalar 1–3 saat ve 4–6 saat | Ortam değişiyor | Kimse suçlanmamalı |
| BME688 ısıtıcısı (+10 mW) | 3,25–3,5 saat | Tuzak: kanala özgü ısınma, arıza yok | Sensör suçlanmamalı; tutarsızlık BME688 sıcaklığına yüklenmeli |
| Gyro z bias kayması (0,03 dps/saat) | 4,5 saatten itibaren | Gerçek arıza, soğuma rampasıyla üst üste | Gyro z suçlanmalı |

**Yöntem v0:**
- Kanallar 60 saniyelik ortalamalara indiriliyor.
- Her kanal c ve her sıcaklık kaynağı r için, test edilen dakikadan 10 dakika önce biten 90 dakikalık bir pencerede `y = a + b·T_r` doğrusu uyduruluyor. `b` için küçük bir ridge cezası var: sıcaklık değişmiyorsa b ≈ 0 kalıyor.
- Tahmin hatası, pencere içindeki artıkların standart sapmasına bölünüp **z skoru** elde ediliyor. Eşik |z| > 5.
- **Sensör suçlama:** Kanal, **iki** sıcaklık kaynağıyla da açıklanamıyorsa.
- **Sıcaklık kaynağı suçlama:** İki kaynak birbirini tutmuyorsa. Hangi kaynağa göre daha çok kanal bozuluyorsa o suçlanıyor.
- **Temel çizgi (mini ablasyon):** Aynı test, termal model olmadan (b = 0).

Birim katsayıları Bulgu 4A/4E'deki gibi sınırlar içinden örneklendi. Manyetometre gürültüsü ve katsayısı, BME688 ofseti `assumed`.

**v0'ın bilinçli sınırları:** Yalnızca beyaz gürültü var (bias instability ve random walk yok). Uydurulan doğruda histerezis terimi yok. Çıktı sürekli bir skor değil, ikili bayrak (ADR-010 hedefi sonraya kaldı).

**Sonuç (tablo):**

| Ölçüt | G1 v0 | Temel çizgi |
|---|---|---|
| Gyro z arızasını yakalama gecikmesi | 2 dk | 0 dk (*aşağıya bakın: güvenilmez*) |
| Yanlış sensör alarmı, gx / gy / ax / ay [60 s blok] | 7 / 9 / 9 / 11 | 15 / 16 / 17 / 15 |
| Yanlış sensör alarmı, gz / az / mx / my / mz | 0 / 0 / 0 / 0 / 0 | 1 / 1 / 0 / 2 / 0 |
| Isıtıcı sırasında sensör suçlama | **0 blok** | — |
| Isıtıcı sırasında "sıcaklık kaynakları tutarsız" | 16 / 25 blok; 15'i BME688'e, 1'i ICM'ye yüklendi | — |
| Isıtıcı dışında "sıcaklık kaynakları tutarsız" | **47 blok** | — |

Karar verilen blok sayısı: 380. İlk 1,68 saat pencerenin dolması için bekleniyor.

**Bulgu 6A: Isıtıcı tuzağı doğru çözüldü.** Isıtıcı patlaması sırasında hiçbir sensör arızalı sayılmadı. Tutarsızlık 16 bloğun 15'inde doğru kaynağa, BME688 sıcaklığına yüklendi. "Her kanalı iki bağımsız sıcaklık kaynağına karşı test et; biri tutmuyorsa suçluyu kanal sayısıyla bul" fikri, müfredat sınıf 7/8'in çekirdeği için çalışan bir mekanizma. İki bağımsız sıcaklık kaynağının (Ek C.1) değerini sayısal olarak gösteriyor.

**Bulgu 6B: Termal model yanlış alarmları kabaca yarıya indiriyor, ama sıfırlamıyor.**
- ICM kanallarında G1 7–11, temel çizgi 15–17 yanlış alarm verdi.
- Temel çizginin "0 dk" yakalama gecikmesi **güvenilmez.** Figür 2'de temel çizgi 4,5–4,75 saat arasında neredeyse **tüm** ICM kanallarını aynı anda suçluyor. Gyro z'yi "yakalaması" soğumanın başlamasıyla oluşan genel alarmın içinde bir tesadüf; hangi sensörün bozulduğunu söyleyemiyor.
- G1'in 2 dakikalık tespiti de kısmen karışık. Aynı dakikalarda gx, gy, ax ve ay da yanlış suçlanıyor (Bulgu 6C). Yine de gz'nin z skoru ~20'ye çıkıyor ve bu dört kanaldan daha uzun süre işaretli kalıyor; tespitin büyük kısmı gerçek.

**Bulgu 6C: Histerezis, sıcaklığın yön değiştirdiği yerlerde yanlış alarm üretiyor** (önceden öngörülmüştü).
- G1'in yanlış alarmları neredeyse yalnızca 4,5–4,7 saat arasında gx, gy, ax, ay'da toplanıyor. Bu, 40 °C'deki dönüşün (4,0 saat) 90 dakikalık pencereye girdiği an.
- Pencere hem ısınma hem soğuma yolunu içerince, histerezisi bilmeyen tek doğru ikisini birden açıklayamıyor.
- Kanıt: histerezisi olmayan manyetometre kanallarında hiç yanlış alarm yok. Ayrıca az'da da yok; örneklenen katsayısı küçük olduğundan histerezis açıklığı da küçük (açıklık katsayıyla orantılı).
- Düzeltme yönü: yön terimi eklemek (ısınma / soğuma için ayrı ofset) veya histerezis modelini uydurmak.

**Bulgu 6D: Gecikme farkı, sıcaklık kaynaklarını yön dönüşlerinde "tutarsız" gösteriyor.**
- Isıtıcı dışındaki 47 "sıcaklık kaynağı" alarmı ~3,0 ve ~6,0 saatteki rampa sonlarında (ve pencere başlangıcında) toplanıyor.
- Sebep: BME688 (τ = 200 s) ICM'den (τ = 120 s) daha yavaş. Rampa boyunca ~80 s geride kalıyor, rampa bitince açığı kapatıyor. Bu, iki kaynak arasındaki doğrusal ilişkiyi geçici olarak bozuyor.
- Bu, Bulgu 5C'nin (gecikme histerezis gibi görünür) sıcaklık kaynakları arasındaki karşılığı.
- Düzeltme yönü: kaynakları karşılaştırmadan önce gecikmeleri hizalamak (birinci mertebe filtre) veya değer yerine değişim hızını karşılaştırmak.

**Bulgu 6E: Kayan pencere arızaya uyum sağlıyor. Yavaş bir arıza "yeni normal" oluyor.** Bu v0'ın en önemli zayıflığı. Figür 1'in alt paneli:
- **4,55–5,0 saat:** Arıza tespit ediliyor.
- **5,0–6,0 saat, maskeleme:** Soğuma rampası sürerken kayma zamanla artıyor, sıcaklık zamanla azalıyor. İkisi pencere içinde neredeyse mükemmel ilişkili. Doğru uydurma kaymayı sahte bir "sıcaklık katsayısı" olarak öğreniyor ve z skoru eşiğin altına düşüyor. Bu, müfredat sınıf 5'in ("konfounder-maskeli arıza") kendiliğinden ortaya çıkmış hâli.
- **6,1–6,6 saat:** Rampa bitiyor ama kayma sürüyor. Öğrenilen sahte katsayı artık tutmuyor ve arıza yeniden tespit ediliyor.
- **6,6 saatten sonra:** Pencere tamamen sabit sıcaklıkta ve kayma doğrusal. Standart sapma kaymanın kendisini de içerdiği için z yaklaşık 2'de sabitleniyor. Arıza sürdüğü ve büyüdüğü hâlde (0,1 dps'e kadar) bir daha hiç işaretlenmiyor.
- Sonuç: v0 bir **değişimi** yakalıyor, ama bir **durumu** takip edemiyor. Oysa MIHENK'in çıktısı sürekli bir sağlık kestirimi olmalı (ADR-010). Arızanın varlığını hatırlayan bir yapı gerekiyor: sağlıklı dönemde öğrenilip dondurulan (veya çok yavaş güncellenen) bir termal model, artık üzerinde CUSUM benzeri birikimli bir test, ya da modele açık bir kayma terimi.

**Bulgu 6F: Tek yönlü bir rampada yavaş kayma ile sıcaklık katsayısı ayırt edilemez.** Bu v0'ın değil, problemin kendi sınırı.
- Monoton bir rampada sıcaklık zamanla doğrusal değişiyor, kayma da öyle. İki etki matematiksel olarak eş doğrusal (collinear).
- Bu senaryoda sahte katsayı değişimi: 0,03 dps/saat ÷ 7,5 °C/saat = 0,004 dps/°C. Bu değer veri sayfasının ±0,005 dps/°C sınırının **içinde**. Yani veri sayfası sınırı da maskelemeyi açığa çıkaramıyor.
- İki etki ancak sıcaklık **yön değiştirdiğinde** veya **sabit kaldığında** ayrılabiliyor. 6,1 saatteki yeniden tespit tam da bu.
- G1'in iddia kapsamı için sonucu: "Referanssız ayrıştırma, yavaş kaymayı termal etkiden ancak yeterli **termal uyarım** (yön değişimi veya sabit bölge) varken ayırabilir." Bu cümle, teşhis kestiricisinin formel tanımına ([§14.2/4](mihenk.md)) ve geçerlilik zarfına girmeli.

**v1 için yapılacaklar:** Histerezis veya yön terimi (6C); kaynaklar arasında gecikme hizalama (6D); dondurulan referans model + birikimli test (6E); tanımlanabilirlik koşulunu açıkça ölçen bir "termal uyarım" göstergesi (6F); ardından bias instability ve random walk ekleyip aynı ölçütleri yeniden almak.

---

## 7. G1 prototipi v1

**Script:** [`matlab/g1/v1/g1_prototype_v1.m`](matlab/g1/v1/g1_prototype_v1.m). v1, v0 ve temel çizgiyi aynı veri üzerinde karşılaştırıyor.
**Dedektör:** [`matlab/g1/v1/g1_detect_v1.m`](matlab/g1/v1/g1_detect_v1.m) · **Senaryo:** [`matlab/models/simulate_node.m`](matlab/models/simulate_node.m) · **Değerlendirme:** [`matlab/g1/g1_evaluate.m`](matlab/g1/g1_evaluate.m)
**Figürler:** [`matlab/figures/g1_v1_1.png`](matlab/figures/g1_v1_1.png), [`matlab/figures/g1_v1_2.png`](matlab/figures/g1_v1_2.png)

**Amaç:** Bulgu 6C–6F'deki zayıflıkları gidermek. Bunu v0 ile **aynı senaryo, aynı veri ve aynı ölçütler** üzerinde göstermek.

**Yeniden düzenleme ve doğrulaması:**
- v0'ın senaryosu `simulate_node.m`'e, yöntemi `g1_detect_v0.m`'e, ölçütleri `g1_evaluate.m`'e taşındı. Rastgele sayı çekiliş sırası korundu.
- v1 scriptindeki v0 sütunu, §6'daki koşuyla **birebir aynı** çıktı: yanlış alarmlar 7/9/9/11, temel çizgi 15/16/17/15, ısıtıcı 16 (15/1), ısıtıcı dışı 47. Taşıma sonucu değiştirmedi.
- Tek fark yazdırmada: gecikmeler artık yuvarlanmıyor (2 → 2,5 dk, 0 → 0,5 dk).

**v1'de ne değişti:**

| Bulgu | v0'daki sorun | v1'deki çözüm |
|---|---|---|
| 6E | Kayan pencere, yavaş arızayı "yeni normal" kabul ediyor | **Hafızalı model:** Her kanal ve her sıcaklık kaynağı için özyinelemeli bir Bayes doğrusal modeli var (RLS, ~24 saatlik unutma). Model yalnızca artık küçükse güncelleniyor. Tek başına bozulan kanalın modeli donuyor. Kanıtlar CUSUM ile birikiyor. |
| 6F | Model henüz öğrenmemişken de kesin konuşuyor | Sıcaklık katsayısının başlangıç bilgisi veri sayfası sınırı. Tahmin varyansına parametre belirsizliği de ekleniyor. Öğrenilmemiş bir model geniş, dürüst bir tahmin veriyor; tahmin/gürültü oranı > 1,5 ise karar **düşük güven** olarak işaretleniyor. |
| 6C | Histerezis yön dönüşlerinde yanlış alarm veriyor | Modele yön terimi eklendi: `y = a + b·T + c·d(w)`, `d = (T − play(T, w))/(w/2)`. Histerezis genişliği w bilinmiyor; 0,2–2 °C adayları arasından seçiliyor. |
| 6D | Sıcaklık kaynakları arasındaki gecikme yanlış alarm veriyor | BME688 sıcaklığı, gecikmeli ICM sıcaklığıyla tahmin ediliyor. Gecikme 0–300 s adayları arasından seçiliyor. |
| — | — | **Ortak mod olayı:** Sıcaklık hareket ederken ≥ 3 kanal birlikte saparsa bu ortam sayılıyor. Modeller güncelleniyor ve CUSUM birikmiyor. |

Aday seçimleri (gecikme, histerezis genişliği) çalışma sırasında, **yalnızca tutarlı bloklardan** ve blok başına katkısı sınırlanarak öğreniliyor. Bu kuralın neden gerekli olduğu aşağıdaki Bulgu 7B'de.

**Sonuç** (her iki yöntemin karar verdiği 380 ortak blok üzerinde; 3. koşu):

| Ölçüt | Temel çizgi | G1 v0 | G1 v1 |
|---|---|---|---|
| gz arızası: tespit gecikmesi | 0,5 dk* | 2,5 dk | 4,5 dk |
| gz arızası: **kapsama** (arızalı blokların işaretli kalma oranı) | %13,8 | %28,1 | **%98,1** |
| Yanlış sensör alarmı (toplam) | 67 | 36 | **0** |
| Isıtıcı: yanlış sensör suçlama | — | 0 | 0 |
| Isıtıcı: "sıcaklık kaynakları tutarsız" (BME688 / ICM'ye yüklenen) | — | 16 (15 / 1) | 24 (24 / 0) |
| Isıtıcı dışında "sıcaklık kaynakları tutarsız" | — | 47 | **0** |

\* Temel çizginin gecikmesi güvenilmez; tüm ICM kanallarını birlikte suçluyor (Bulgu 6B).

Tam karar aralığında (0,51 saatten itibaren, 450 blok): yanlış sensör alarmı 0; ortak mod olayı 0; gz için düşük güven payı %2; düşük güven altında verilen gz arıza kararı 206'nın 0'ı. Seçilen gecikme **80 s** (gerçek: 200 − 120 = 80 s). Seçilen histerezis genişliği ICM'ye göre **1,0 °C** (gerçek: 1,0 °C), BME688'e göre 0,5 °C.

**Bulgu 7A: 6C–6F bu senaryoda giderildi.**
- **6E:** Kapsama %28'den %98'e çıktı. Figür 1'in alt panelinde v1'in skoru arıza boyunca kesintisiz yükseliyor; v0'ın skoru iki kez eşiğin altına düşüyordu.
- **6C, 6D:** Yanlış alarmlar sıfırlandı. Gecikme ve histerezis genişliği, simülasyonun gerçek değerleri olarak **kendiliğinden** bulundu.
- **Bedeli:** Tespit gecikmesi 2 dakika uzadı. Birikimli test karar vermeden önce kanıt topluyor.

**Bulgu 7B: Aday seçimi, aykırı dönemlerden öğrenirse bozuluyor** (1. koşudaki hata).
- 1. koşuda ısıtıcı dışındaki "T src" alarmları 47'den **88'e çıktı**. Alarm ısıtıcıyla başlayıp ~5,15 saate kadar sürdü.
- Sebep: gecikme adaylarının birikmiş hatası ısıtıcı sırasında da toplanıyordu. Isıtıcının dev hatası (z ≈ 75), adaylar arasındaki küçük farkları büyüterek seçimi kısa bir gecikmeye kaydırdı. Soğuma rampası başlayınca bu yanlış gecikme tutarsızlık üretti.
- Düzeltme: biriken hata yalnızca tutarlı bloklarda toplanıyor, blok başına katkı zU² ile sınırlı.
- **Genel ders:** "Aykırı dönemde öğrenme" koruması, modelin **her** öğrenen parçasına uygulanmalı; yalnızca kanal modellerine değil, hiperparametre seçimlerine de.

**Bulgu 7C: Dondurma mekanizması, eksik model yapısıyla birleşince kendini kilitleyen yanlış alarm üretiyor** (2. koşudaki hata). v1'in ana tasarım gerilimi bu.
- 2. koşuda (histerezis genişliği 0,2 °C'de sabitken) `ay`'de 47 yanlış alarm çıktı (4,25–5,05 saat) ve gz'nin tespiti 10,5 dakikaya uzadı.
- Sebep: 0,2 °C'lik yön dedektörü, gerçek 1 °C'lik histerezisin geçişini 5 kat hızlı varsayıyordu. Her dönüşte ~4σ'lık bir uyumsuzluk oluşuyordu.
- 1. koşuda bu uyumsuzluk "ortak mod" olarak öğrenilmişti, çünkü BME referansı (hata yüzünden) devre dışıydı ve 4 ICM kanalı birlikte sapıyordu. 6D düzelince yalnızca `ay` eşiği aştı. Model onu "tek başına bozulan kanal" sayıp dondurdu ve dondurulan model geçişi hiç öğrenemedi.
- Aynı olay gz'yi de etkiledi: `ay` + gz birlikte saptığı için ortak mod sayıldı ve gz'nin CUSUM'u sıfırlandı.
- **Gerilim:** Arızayı unutmamak için donmak gerekiyor. Ama model yapısı eksikse, dondurma gerçek ama yeni bir davranışın öğrenilmesini de engelliyor. Tek başına bozulan bir kanalın "arızalı" mı, yoksa "modelin bilmediği bir yeni rejimde" mi olduğu yerel olarak ayırt edilemiyor.
- Çıkan dersler:
  - (a) Termal model yapısı (histerezis tipi, gecikme) gerçeğe yeterince yakın olmalı. Bu da termal salınım kaydının önemini artırıyor.
  - (b) "Ortak mod olayı" kaçış kapısı kırılgan: 2. koşuda yanlış yerde açıldı, 3. koşuda hiç kullanılmadı.
  - (c) Bu kilitlenme türü, müfredat sınıf 8'e "model yapısı uyumsuzluğu" olarak eklenmeli.

**Bulgu 7D: Bu sonuçlar henüz genellenemez.** v1'i olduğundan iyi gösteren koşullar:
- **Aynı senaryoya ayarlandı.** v1 üç iterasyonda, **aynı** senaryo ve tohumla, sonuçlara bakılarak düzeltildi (ortak mod eşiği 2 → 3, aday ızgaraları). Bu bir aşırı uyum (overfitting) riski. v1, görmediği senaryolar ve tohumlarla test edilmeli.
- **Dairesellik (İ6).** Dedektörün histerezis modeli (play operatörü), simülatörün histerezis modeliyle **aynı yapıda**. Doğru genişlik bulununca model tanım gereği tam oluyor. Gerçek sensörün histerezisi başka biçimde olabilir. Bu, raporun "model-uyuşmazlığı testi zorunlu" kuralının (ADR-012) tam uygulanacağı yer.
- **Kolay gürültü.** Yalnızca beyaz gürültü var; bias instability ve random walk eklenmedi.
- **Tek tip arıza.** Yalnızca tek bir arıza türü (tek kanalda doğrusal kayma) ve tek bir tuzak (ısıtıcı) denendi. EMI, eşzamanlı bağımsız arızalar ve sıcaklık sensörünün kendi arızası yok.
- **Kısa süre.** 7,5 saatte 0 yanlış alarm, yanlış alarm oranı hakkında bir şey kanıtlamaz.
- **Kalibre olmayan skor.** CUSUM sınırsız büyüyor (10⁴'e kadar). Bu, ADR-010'un istediği kalibre edilmiş güven skoru değil.

**v2 için yapılacaklar:** Birden çok tohum ve birden çok senaryoyla (farklı profiller; müfredat sınıf 5–8 tuzakları) istatistiksel değerlendirme. Simülatörde farklı bir histerezis biçimiyle model-uyuşmazlığı testi. Bias instability ve random walk. Skoru olasılığa çevirip kalibrasyonunu ölçmek (ECE, reliability diagram).

---

## 8. G1 v2: çok senaryolu, çok tohumlu değerlendirme

**Script:** [`matlab/g1/v2/g1_prototype_v2.m`](matlab/g1/v2/g1_prototype_v2.m) · **Senaryolar:** [`matlab/g1/v2/g1_scenarios_v2.m`](matlab/g1/v2/g1_scenarios_v2.m)
**Ham sonuçlar:** [`matlab/g1/v2/g1_v2_results.csv`](matlab/g1/v2/g1_v2_results.csv) (90 satır: 9 senaryo × 5 tohum × 2 dedektör)
**Figürler:** [`matlab/figures/g1_v2_1.png`](matlab/figures/g1_v2_1.png) (özet), [`matlab/figures/g1_v2_2.png`](matlab/figures/g1_v2_2.png) (her senaryoda v1'in suçlama grafiği, tohum 0)

**Amaç:** Bulgu 7D'nin çağrısını yerine getirmek. v0 ve v1, **hiç ayar yapılmamış** senaryolarda ve tohumlarla sınandı. Yeni bir dedektör yok; bu bir sınav.

**Model genişletmeleri** (varsayılan yol bit düzeyinde değişmedi):
- `simulate_node.m`'e şunlar eklendi:
  - Renkli gürültü: 1 Hz'de üretilen bias instability (`fractalcoef(2000)`) ve rate random walk. Değerler `assumed`: gyro B = 5 °/h, K = 5 °/h/√h; ivmeölçer B = 0,04 mg, K = 0,02 mg/√h; manyetometre B = 0,01 µT.
  - Herhangi bir kanalda kayma veya basamak arızası; birden çok arıza.
  - Manyetometre EMI'si.
  - BME688 sıcaklık sensörü arızası.
- `thermal_node.m`'e ikinci bir histerezis biçimi eklendi: gevşeme (relaxation). Bu biçim dedektörün varsaydığı play operatöründen farklı; model-uyuşmazlığı testi bunu kullanıyor.

**Senaryolar:** Tohum değişince gürültü ve birimin sıcaklık katsayıları değişiyor. BME688 ısıtıcı patlaması tüm senaryolarda var.

| Senaryo | Neyi sınıyor | Doğru davranış |
|---|---|---|
| white | v1 koşulları, yalnızca tohum değişiyor | gz suçlanmalı |
| colored | Renkli gürültü | gz suçlanmalı |
| hold-fault | Sabit sıcaklıkta yavaş kayma (0,01 dps/saat) | gz suçlanmalı |
| accel-step | Rampa sırasında ay'de 0,3 mg basamak | ay suçlanmalı |
| two-faults | gz ve ax'te aynı anda bağımsız kayma (sınıf 8) | İkisi de suçlanmalı |
| emi | 20 dakikalık manyetik girişim (sınıf 8) | Sensör suçlanmamalı |
| bme-fault | BME688 sıcaklığı 0,5 °C/saat kayıyor (sınıf 7) | BME688 suçlanmalı, hareket kanalı suçlanmamalı |
| hyst-relax | Model uyuşmazlığı: gevşeme histerezisi | gz suçlanmalı |
| day-cycle | 25 ± 8 °C sinüs, 4 saat periyot | gz suçlanmalı |

`white` dışındaki tüm senaryolarda renkli gürültü var.

**Sonuç — arızalar** (5 tohum; tespit oranı ve kapsama tohum ortalaması, gecikme tohum medyanı):

| Senaryo | Tespit v0 / v1 | Gecikme [dk] v0 / v1 | Kapsama v0 / v1 | Yanlış alarm/saat v0 / v1 |
|---|---|---|---|---|
| white | %100 / %100 | 2,5 / 5,5 | %28 / %98 | 4,0 / **0,0** |
| colored | %100 / %100 | 17,5 / 0,5 | %7 / %92 | 0,7 / **138,8** |
| hold-fault | %40 / %100 | 38,5 / 0,5 | %0 / %88 | 0,7 / **155,9** |
| accel-step | %40 / %100 | 2,0 / 2,5 | %2 / %96 | 0,7 / **151,7** |
| two-faults | %60 / %100 | 51,5 / 25,5 | %4 / %81 | 0,6 / **115,6** |
| emi | — | — | — | 6,9 / 193,8 |
| bme-fault | — | — | — | 0,8 / 179,5 |
| hyst-relax | %100 / %100 | 17,5 / 0,5 | %6 / %89 | 0,7 / **138,2** |
| day-cycle | %100 / %100 | 22,5 / 0,5 | %15 / %96 | 0,8 / **128,6** |

**Sonuç — tuzaklar:**

| Ölçüt | v0 | v1 |
|---|---|---|
| Isıtıcı sırasında sensör suçlama (koşu başına blok) | 0,1 | 22,2 |
| Olaylar dışında "T src" alarmı (koşu başına blok) | 37,8 | **0,7** |
| EMI bloklarında manyetometrenin suçlanma oranı | %53 | %57 |
| BME arızası sırasında BME688'in suçlanma oranı | %0 | %31 |
| BME arızası sırasında bir hareket kanalının suçlanma oranı | %0 | %100 |

**Bulgu 8A: Genişletme doğru; v1 beyaz gürültüde tohuma aşırı uyum yapmamış.**
- CSV'deki "white / tohum 0" satırı v1 koşusuyla birebir aynı: gecikme 4,5 dk, kapsama 0,981, yanlış alarm 0; v0 için 2,5 dk, 0,281, "T src" 47.
- Beş tohumun hepsinde v1: yanlış alarm 0, kapsama %97,6–98,1. Birim katsayıları ve gürültü değişse de beyaz gürültüde sonuç korunuyor.
- Bulgu 6D'nin düzeltmesi (gecikme hizalama) tüm senaryolara genelleniyor: olaylar dışındaki "T src" alarmı v0'da 37,8, v1'de 0,7.

**Bulgu 8B: v1 renkli gürültü altında çöküyor.** Günün en önemli bulgusu bu.
- Renkli gürültünün olduğu her senaryoda v1 saatte 115–195 yanlış alarm veriyor. Figür 2'de ax, mz, my gibi sağlam kanallar 2–4. saatte suçlanıyor ve gün sonuna kadar suçlu kalıyor.
- Bu yüzden v1'in "%100 tespit, 0,5 dk gecikme" değerleri **anlamsız**. Temel çizgide olduğu gibi (Bulgu 6B), hemen her şeyi suçlayan bir yöntem arızayı da "yakalıyor".
- **Neden?** v1 iki varsayıma dayanıyor:
  - (1) Gürültü düzeyi ısınma dönemindeki blok farklarından ölçülüyor. Bu yalnızca beyaz kısmı görüyor; bias instability ve random walk'un yavaş gezinmesini görmüyor. z skorları şişiyor.
  - (2) "Sıcaklıkla açıklanamayan yavaş kayma = arıza." Oysa random walk, **sağlam** bir sensörün de yavaşça kaymasıdır. v1'in arıza tanımına göre sağlam bir gyro, 1–2 saat içinde "arızalı" sayılıyor.
- Model de dondurulduğu için (Bulgu 7C) bu yanlış karar bir daha düzelmiyor.
- **Kavramsal sonuç:** "Arıza" ancak sensörün **kendi stokastik bütçesinin dışına çıkan** sapmadır. Bu bütçe, Allan parametreleriyle (N, B, K) belirlenir. G1, gürültü modelinden ayrı tasarlanamaz: Allan (Katman 1'deki ④) G1'in "sıfır hipotezini" tanımlıyor. Bu, B ve K'nın gerçek statik kayıttan ölçülmesini (Bulgu 4B) zorunlu hâle getiriyor.

**Bulgu 8C: v0 yanlış alarmda sağlam ama arızayı unutuyor. İki tasarımın zayıflıkları birbirinin tersi.**
- v0, renkli gürültüde saatte yalnızca 0,5–0,8 yanlış alarm veriyor, çünkü kayan penceresinin standart sapması gezinmeye uyum sağlıyor.
- Aynı uyum yüzünden arızayı da kaçırıyor: kapsama %0–15; hold-fault ve accel-step'te tespit oranı %40.
- Uyum sağlayan pencere sağlam ama unutkan; hafızalı model ısrarcı ama kırılgan. İkisi de kabul edilemez. v3, hafızayı dürüst bir gürültü modeliyle birleştirmeli.

**Bulgu 8D: EMI tuzağı beklendiği gibi G1'in sınırında.**
- İki dedektör de EMI bloklarının yarısından fazlasında manyetometreyi suçluyor: v0 %53, v1 %57. Yalnızca termal ayrıştırmaya bakan bir yöntem için "ortak mod olmayan çevresel etki" ile "sensör arızası" aynı görünüyor.
- v1'de ek bir sorun var: EMI 5,33 saatte bittiği hâlde manyetometre kanalları gün sonuna kadar suçlu kalıyor. Bu, 7C'deki kilitlenme.
- **İddia kapsamı için sonucu:** G1 bu durumu tek başına çözemez. Manyetik alanın büyüklüğünün sabitliği (`‖m‖ ≈ sabit`) ve üç yönlü yönelim oylaması (Katman 1 ②) gibi başka kaldıraçlar gerekiyor. Rapordaki "EMI, G1'in en zorlu karşı-örneği" öngörüsü doğrulandı.

**Bulgu 8E: Konfounder sensörünün arızasını yalnızca hafızalı tasarım görüyor.**
- BME688 sıcaklığı kaydığında v0 onu hiç suçlamıyor (%0); penceresi kaymaya uyum sağlıyor.
- v1 BME688 sıcaklığını suçluyor: tohum ortalaması %31, tohum 0'da ~5,2 saatten itibaren kesintisiz (Figür 2).
- Ama v1 aynı anda renkli gürültü yüzünden hareket kanallarını da suçladığı için (%100) sonuç temiz değil. Doğru mekanizma var, gürültü modeli onu gölgeliyor.

**Bulgu 8F: Deney tasarımında bir hata yaptım.** Renkli gürültüyü `white` dışındaki **tüm** senaryolara koydum. Bu yüzden histerezis uyuşmazlığının, iki arızanın ve günlük döngünün etkisi gürültünün etkisinden ayrılamıyor: v1'in yanlış alarm oranı her yerde 115–195 arasında. Doğrusu, her tuzağı hem beyaz hem renkli gürültüyle koşmak (faktöriyel tasarım); v3 değerlendirmesi bu şekilde kurulmalı.

**v3 için yön:**
- **Gürültüyü bilen bir sıfır modeli.** RLS yerine bir Kalman filtresi kullanmak. Bias'ı random walk'a uyan bir durum olarak modellemek. Süreç gürültüsü, Allan parametrelerinden (K, B) gelmeli. Böylece sağlam bir sensörün beklenen gezinmesi tahmin belirsizliğine girer, arıza da ancak bu belirsizliği aşan sapma olur.
- **Kilitlenmeye karşı bir çıkış yolu:** Suçlanan bir kanalın modeli dondurulur, ama kanalın durumu açıkça "arızalı" ve "yeni rejim" arasında sınanır. Örneğin bir olay bittikten sonra artıklar gürültü bütçesine geri dönerse kanal serbest bırakılır.
- **Faktöriyel değerlendirme:** Her tuzak için beyaz ve renkli gürültü (8F).

---

## 9. G1 v3: Allan'dan türetilmiş Kalman sıfır modeli, faktöriyel değerlendirme

**Script:** [`matlab/g1/v3/g1_prototype_v3.m`](matlab/g1/v3/g1_prototype_v3.m) · **Dedektör:** [`g1_detect_v3.m`](matlab/g1/v3/g1_detect_v3.m) · **Allan uydurma:** [`g1_allan_fit.m`](matlab/g1/v3/g1_allan_fit.m) · **Senaryolar:** [`g1_scenarios_v3.m`](matlab/g1/v3/g1_scenarios_v3.m)
**Ham sonuçlar:** [`g1_v3_results.csv`](matlab/g1/v3/g1_v3_results.csv) (320 satır: 8 senaryo × 2 gürültü × 5 tohum × 4 dedektör) · **Konsol çıktısı:** [`g1_v3_output.txt`](matlab/g1/v3/g1_v3_output.txt)
**Figürler:** [`g1_v3_1.png`](matlab/figures/g1_v3_1.png) (kapsama ve yanlış alarm), [`g1_v3_2.png`](matlab/figures/g1_v3_2.png) (v3 suçlama grafiği, renkli gürültü, tohum 0), [`g1_v3_3.png`](matlab/figures/g1_v3_3.png) (Allan uydurması)

**Amaç:** Bulgu 8B'nin çözümünü denemek. Sağlam bir sensörün beklenen gezinmesi, Allan parametrelerinden türetilen bir "stokastik bütçe" olarak modele girecek. Arıza da ancak bu bütçeyi aşan sapma sayılacak. Değerlendirme Bulgu 8F'deki hatayı düzeltecek şekilde faktöriyel kuruldu.

**Ne yapıldı:**
- **Gürültü modeli ayrı bir kayıttan.** Her gürültü tipi için 12 saatlik statik bir kayıt simüle edildi (tohumlar 9007–9013, senaryo tohumlarından ayrı). Bu kaydın Allan varyansına N, K ve bir Gauss-Markov terimi ağırlıklı NNLS ile uyduruldu, sonra blok düzeyindeki Kalman parametrelerine çevrildi.
- **Dedektör.** Her kanal × referans × histerezis genişliği için durumu `[a (random walk), g (Gauss-Markov), b (tempco), c (histerezis)]` olan bir Kalman filtresi kullanıldı.
  - Zaman güncellemesi her blokta çalışıyor, ölçüm güncellemesi ise v1'deki gibi kapılı.
  - Böylece dondurulmuş bir kanalın tahmin varyansı büyüyor. Amaç, yanlış bir kilitlenmenin kendiliğinden çözülmesi (Bulgu 7C'nin çıkış yolu).
  - Kapılama, ortak mod olayı, genişlik ve gecikme ızgaraları gibi geri kalan her şey v1 ile aynı, eşikleri de değişmedi.
- **CUSUM.** İşaretli Page CUSUM kullanıldı (k = 0,5, h = 10). Bu değerler bir senaryoya ayarlanmadı; ARL0'dan (kontrol altındaki ortalama koşu uzunluğu) seçildi. v1'in |z| CUSUM'ı "v3a" adıyla ablasyon olarak koşuldu.
- **Faktöriyel tasarım.** v2'deki 8 senaryonun her biri hem beyaz hem renkli gürültüyle, 5 tohumla koşuldu.

**Önceden kayda geçmesi gereken bir şey:** İşaretli CUSUM'a geçişi **bir sonuç gördükten sonra** yaptım. İlk duman testinde (base, tohum 0) v3, v1'in |z| CUSUM'ıyla 123,5 dk gecikme verdi. Random walk durumu kaymayı kısmen takip ediyor, artıklar da ~1,8σ düzeyinde ama hep aynı işaretli kalıyor. Bu yüzden |z| − 1,5 neredeyse hiç birikmiyor. Değişikliğin gerekçesi kuramsal olsa da (k ve h ARL0'dan geliyor) karar duman testinden sonra verildi. Bu nedenle v3a ablasyonu sonuçlarda bilerek tutuldu.

**Regresyon:** v0 ve v1'in v2 satırlarıyla 90 satır karşılaştırıldı; en büyük göreli fark 3,7e-15. Genişletmeler eski yolu bozmadı.

**Sonuç — arızalar** (tespit oranı ve kapsama tohum ortalaması, gecikme tohum medyanı; v1 / v3a / v3):

| Senaryo / gürültü | Gecikme [dk] | Kapsama | Yanlış alarm/saat |
|---|---|---|---|
| base / beyaz | 5,5 / 5,5 / 4,5 | %98 / %98 / %98 | 0 / 0 / 0 |
| base / renkli | 0,5 / 95,5 / 16,5 | %92 / %58 / %92 | 138,8 / 0,0 / **11,5** |
| hold-fault / beyaz | 11,5 / 10,5 / 7,5 | %90 / %91 / %93 | 0 / 0 / 0 |
| hold-fault / renkli | 0,5 / — / **60,5** | %88 / %0 / **%39** | 155,9 / 0,0 / 11,5 |
| accel-step / renkli | 2,5 / 1,5 / 1,5 | %96 / %99 / %99 | 151,7 / 0,0 / 11,5 |
| two-faults / renkli | 25,5 / 171,5 / 31,5 | %81 / %40 / %88 | 115,6 / 0,0 / 11,5 |
| emi / beyaz | — | — | 53,4 / 53,4 / 53,4 |
| emi / renkli | — | — | 193,8 / 52,3 / **74,5** |
| bme-fault / beyaz | — | — | 0 / 0 / **12,6** |
| hyst-relax / beyaz | 4,5 / 4,5 / 3,5 | %98 / %98 / %98 | 69,6 / 72,9 / **124,8** |
| hyst-relax / renkli | 0,5 / 95,5 / 16,5 | %89 / %59 / %92 | 138,2 / 0,0 / 10,7 |
| day-cycle / renkli | 0,5 / 43,5 / 20,5 | %96 / %74 / %88 | 128,6 / 0,7 / 15,2 |

Gösterilmeyen beyaz satırlarda (accel-step, two-faults, day-cycle) üç dedektör de yanlış alarm 0, kapsama %97–100. Tam tablo konsol çıktısında.

**Sonuç — tuzaklar** (tohum ortalaması; v1 / v3a / v3):

| Ölçüt | Beyaz | Renkli |
|---|---|---|
| Isıtıcı sırasında sensör suçlama (koşu başına blok) | 2,3 / 2,3 / 2,4 | 25,0 / 0,4 / **13,0** |
| Olaylar dışında "T src" alarmı (koşu başına blok) | 0,7 / 0,7 / 0,7 | 0,7 / 0,7 / 0,7 |
| EMI bloklarında manyetometrenin suçlanma oranı | %0 / %0 / %0 | %57 / %0 / %0 |
| BME arızasında BME688'in suçlanma oranı | %73 / %80 / %81 | %31 / %1 / **%1** |
| BME arızasında bir hareket kanalının suçlanma oranı | %0 / %0 / **%18** | %100 / %0 / **%23** |

**Bulgu 9A: Gürültüyü bilen sıfır modeli Bulgu 8B'yi büyük ölçüde çözüyor.**
- Renkli gürültüde yanlış alarm, v1'de saatte 115–195 iken v3'te ortalama 11,5'e iniyor. Medyan ise ~4,3.
- Kapsama korunuyor: base %92, accel-step %99, two-faults %88 (v1'de %81).
- Beyaz gürültüde v3, base / accel-step / two-faults / day-cycle senaryolarında v1 ile aynı: 0 yanlış alarm, kapsama %97–100. Bütçe beyaz gürültüde gereksiz bir körlük yaratmıyor.
- Renkli gürültüdeki gecikmeler (16–31 dk) v1'in 0,5 dk'sından kötü görünüyor. Ama v1'in değeri anlamsızdı (Bulgu 8B); v0'ın 17,5–51,5 dk'sıyla aynı düzeyde ya da daha iyi.
- Hafıza ve dürüst gürültü modeli birlikte, 8C'deki "sağlam ama unutkan" ile "ısrarcı ama kırılgan" ikilemini renkli gürültüde ilk kez aşıyor.

**Bulgu 9B: Renkli gürültüdeki yanlış alarm oranı arızadan bağımsız, gürültü gerçekleşmesine bağlı. Ortalamayı tek bir tohum çekiyor.**
- base, hold-fault, accel-step ve two-faults senaryolarında v3'ün tohum bazında yanlış alarmı birebir aynı: 4,3 / 5,8 / 2,7 / **44,2** / 0,3. Aynı tohum aynı gürültü demek; alarmlar arızadan değil, o gürültü dizisinden ve ısıtıcıdan doğuyor.
- Figür 2'de (tohum 0) bunlar her senaryoda aynı iki olay olarak görünüyor:
  - Isıtıcı sırasında my'nin suçlanması (3,3–3,6 saat). Renkli gürültüde ısıtıcı başına 13 blok; beyazda 2,4. Bunun nedenini henüz bilmiyorum. Isıtıcı sırasında BME referansı dışlanıyor, ama renkli gürültüde neden daha çok suçlama çıktığı açık değil. Ayrıca incelenmeli.
  - az'nin ~4,8–4,95 saatte kısa süre suçlanıp **serbest bırakılması**. Serbest bırakma kuralı burada çalışıyor.
- Tohum 3'ün 44/saat'i ortalamanın büyük kısmını oluşturuyor. 5 tohum, kuyruk davranışını ölçmek için az. Yanlış alarm oranı bundan sonra ortalama yerine medyan ve en kötü tohumla birlikte raporlanmalı.

**Bulgu 9C: İşaretli CUSUM gerekli; v3a ablasyonu bunu gösteriyor.**
- v3a, renkli gürültüde neredeyse hiç yanlış alarm vermiyor (0–0,7/saat), ama arızayı da göremiyor. Gecikme base'de 95,5 dk, two-faults'ta 171,5 dk; hold-fault'ta tespit oranı %0.
- Sebep 9. bölümün başında anlatılan mekanizma. Kalman filtresinin random walk durumu yavaş bir kaymanın bir kısmını "sağlam gezinme" olarak yutuyor. Geriye kalan iz büyük değil, ama hep aynı işaretli. Bu izi yalnız işaretli bir istatistik biriktirebiliyor.
- **Genel sonuç:** Bütçesi doğru bir sıfır modeli, artığı büyüklükten çok **sürekliliğe** taşıyor. Karar istatistiği de buna göre seçilmeli.

**Bulgu 9D: Sabit sıcaklıkta yavaş kayma, gürültü bütçesine yakın; bu bir algılanabilirlik sınırı.**
- hold-fault / renkli'de v3: gecikme 60,5 dk, kapsama %39. Beyaz gürültüde aynı arıza 7,5 dk'da, %93 kapsamayla yakalanıyor.
- 0,01 °/s/saat'lik kayma ile gyro random walk'u (K ≈ 0,0014–0,0027 °/s/√saat) birkaç saatlik ölçekte aynı büyüklükte. Bir saat sonunda kayma 0,01, random walk'un 1σ'sı 0,002–0,003 °/s. Kayma zamanla doğrusal büyüyor, random walk √t ile; ama aradaki fark ancak bir saat mertebesinde belirginleşiyor.
- Allan uydurması gyro K değerini 1,4–1,9× büyük tahmin ediyor (Bulgu 9G). Bu, bütçeyi genişletip gecikmeyi uzatıyor.
- **İddia kapsamı için sonucu:** "En küçük algılanabilir kayma hızı", sensörün K değerine ve izin verilen gecikmeye bağlı bir sayı olarak ifade edilmeli. Bu, teşhis kestiricisinin formel tanımına girmeli ([§14.2/4](mihenk.md)). Termal uyarım yetersizliği (6F) gibi, burada da kör nokta bir hata değil, problemin yapısı.

**Bulgu 9E: EMI ölçütü yanlış pencereye bakıyor; v3'ün "%0" sonucu yanıltıcı.**
- Tuzak tablosuna göre v3, EMI bloklarında manyetometreyi hiç suçlamıyor (%0). Ama aynı senaryoda saatte 53–75 yanlış alarm var.
- Figür 2 (emi, renkli, tohum 0) nedenini gösteriyor. EMI 5,0–5,33 saat arasında; mx, my ve mz bu aralıkta **suçlanmıyor**, ama ~5,6 saatten itibaren gün sonuna kadar suçlanıyor. Yani EMI bittikten sonra kilitleniyorlar.
- Beyaz gürültüde v1, v3a ve v3'ün yanlış alarmı aynı (53,4). Bu, sorunun v3'e özgü olmadığını, v1'den beri var olduğunu gösteriyor. v2'de bunu göremedik, çünkü orada EMI yalnızca renkli gürültüyle koşuldu (8F).
- **Muhtemel mekanizma** (kod okumasına dayanıyor, blok düzeyinde henüz doğrulanmadı):
  1. EMI aşağı rampa sırasında (4–6 saat) geliyor. Sıcaklık hareket hâlinde ve üç manyetometre ekseni birlikte bozuluyor.
  2. Bu, "≥3 kanal birlikte bozuldu ve sıcaklık hareket ediyor" koşulunu (`nCommon = 3`) karşılıyor. Olay **ortak mod** sayılıyor ve ölçüm güncellemesi kapı dışı da olsa kabul ediliyor. Model EMI ofsetini öğreniyor.
  3. EMI bittiğinde model yanlış bir ofset taşıyor. Manyetometrenin K değeri neredeyse sıfır olduğundan tahmin varyansı büyümüyor; serbest bırakma kuralı işleyemiyor.
- **Tasarım hatası:** Ortak mod kuralı, **tek bir fiziksel sensörün üç ekseniyle** karşılanabiliyor. Termal ortak mod tanımı gereği farklı sensörleri kapsamalı. Kural "en az iki farklı fiziksel sensörden kanal" şeklinde yeniden yazılmalı.
- **Ölçüt hatası:** EMI ölçütü yalnızca olay penceresine (+5 dk) bakıyor. Olaydan sonraki kilitlenme ölçütün dışında kalıyor. Tuzak ölçütleri olaydan sonrasını da kapsamalı. Bu benim değerlendirme tasarımımdaki ikinci hata (ilki 8F).

**Bulgu 9F: BME arızasında suçlama, beraberlik durumunda varsayılan olarak ICM'ye gidiyor.**
- Renkli gürültüde v3, BME688 arızasında BME'yi yalnızca %1 oranında suçluyor (v1'de %31). Figür 2'de (bme-fault) "T src" alarmı ~5,2 saatten sonra doğru biçimde sürekli açık; yani kaynaklar arası tutarsızlık görülüyor, ama suç yanlış kaynağa gidiyor.
- **Kod okumasıyla mekanizma:**
  - Sıcaklık kaynağı tutarsızsa suç, hangi referansa karşı daha çok kanal bozuluyorsa ona veriliyor: `bB = tf && nbad(2) > nbad(1)`, aksi hâlde `bI = tf && ~bB`.
  - Renkli gürültüde tahmin varyansı daha büyük. Bu yüzden iki referansa karşı da hiçbir kanal |z| > 3 olmuyor ve `nbad` 0 = 0 berabere kalıyor. Beraberlikte suç **ICM'ye** gidiyor.
  - ICM referansı dışlanınca kanallar yalnızca kayan BME'ye karşı değerlendiriliyor. Bu da hareket kanallarının yanlışlıkla suçlanmasına (%23) yol açıyor.
- Beyaz gürültüde BME %81 oranında doğru suçlanıyor, ama tohum 2'de kanal suçlama %75 ve yanlış alarm 56/saat. Aynı mekanizmanın daha zayıf bir hâli olabilir.
- **Düzeltme yönü:** Beraberlikte kimse suçlanmamalı; "kaynaklar tutarsız, hangisi bilinmiyor" diye ayrı bir belirsiz durum olmalı. Bu da ADR-010'daki sürekli güven skoruna doğal olarak uyuyor. Mekanizmanın doğrulanması için `blameIcm` oranı da kaydedilmeli.

**Bulgu 9G: Allan uydurması gürültüyü fazla tahmin ediyor, ama sistematik ve güvenli tarafta.**
- Figür 3'te uydurma eğrisi noktaların genel biçimini izliyor. Ama ay'deki 2000–5000 s'lik tümsek gibi ayrıntıları kaçırıyor; tek bir Gauss-Markov terimi 1/f gürültüsünü temsil edemiyor.
- Sonuç olarak terimler birbirinin yerine geçiyor:
  - N, gyrolarda 2,1–2,4×, ivmeölçerlerde 2,2–3,2× büyük. Blok süresi 60 s olduğundan en kısa τ 60 s; bu ölçekte beyaz gürültü 1/f'den ayrılamıyor ve N terimi 1/f'nin bir kısmını yutuyor.
  - K, 1,4–2,1× büyük.
  - Gauss-Markov σ'sı ise B değerine yakın (gyro 0,0012–0,0016 vs B 0,0014). Bu terim beklenen işi yapıyor.
  - Manyetometrede N doğru (%5–14), ama simülatörde K = 0 olduğu hâlde küçük bir K uyduruluyor.
- Bütçe şişince dedektör muhafazakâr oluyor: daha az yanlış alarm, daha geç tespit. Bulgu 9D'deki gecikmenin bir kısmı buradan geliyor.
- Beyaz gürültülü kayıtta uydurma K = 0 veriyor (doğru). Ama bunun önemli bir yan etkisi var (9H).

**Bulgu 9H: Beyaz gürültüde serbest bırakma kuralı çalışamaz; model uyuşmazlığı burada kalıcı kilitlenmeye dönüşüyor.**
- hyst-relax / beyaz ilk kez faktöriyel tasarımla görüldü. v1 saatte 69,6, v3 saatte 124,8 yanlış alarm veriyor; 5 tohumun 4'ünde 130–160/saat.
- Bu, gevşeme histerezisinin play operatörüyle temsil edilemediğini gösteriyor (Bulgu 7D'nin öngördüğü uyuşmazlık). Model yapısı yanlış olduğunda sağlam kanallar sistematik artık üretiyor.
- v3'te durum daha kötü, iki nedenle:
  1. İşaretli CUSUM, sistematik ve aynı işaretli artığı v1'den daha hızlı biriktiriyor. 9C'de arızayı yakalayan özellik burada model hatasını yakalıyor.
  2. Beyaz gürültüde K = 0 ve Gauss-Markov terimi ihmal edilebilir. Süreç gürültüsü sıfıra yakın olduğundan dondurulmuş kanalın varyansı büyümüyor; v3'ün serbest bırakma mekanizması bu durumda **devre dışı**.
- Renkli gürültüde ise aynı senaryo base ile neredeyse aynı (tohum bazında 4,4 / 1,7 / 2,7 / 44,1 / 0,5). Geniş bütçe model hatasını yutuyor. Bu iki yönlü bir sonuç: renkli gürültüde model uyuşmazlığı **görünmez** hâle geliyor, yani ölçülemiyor da.
- **Kavramsal sonuç:** Serbest bırakmayı gürültü bütçesine bağlamak yetmez. Model yapısının yanlış olabileceğini de kapsayan bir terim gerekiyor; örneğin sıfır modelinde model hatası için açık bir süreç gürültüsü tabanı, ya da dondurulmuş bir kanalın sistematik artığını "arıza" ve "yapı uyuşmazlığı" arasında ayıran bir test. Bulgu 7C'deki "model yapısı uyumsuzluğu" koşulu formel tanıma girmeli; bu sonuç onu destekliyor.

**Bulgu 9I: Serbest bırakma, sıcaklık değiştikçe büyüyen hatayı da çözemiyor.**
- day-cycle / renkli, tohum 0: az ~4,8 saatte suçlanıyor ve gün sonuna kadar suçlu kalıyor (32/saat; tohum 3'te 38/saat). base senaryosunda aynı tohumda aynı az olayı kısa sürede serbest bırakılıyordu (9B).
- **Muhtemel mekanizma** (doğrulanmadı): Dondurulmuş kanalın sıcaklık katsayısı tahmini de donuyor. day-cycle'da sıcaklık ±8 °C salınıyor; katsayıdaki küçük bir hata, sıcaklıkla orantılı bir artık üretiyor. Bu hata √t ile değil sıcaklıkla büyüyor, bu yüzden varyans artışı onu yakalayamıyor.
- Serbest bırakma kuralı yalnızca random walk türü, zamanla yavaşça kapanan sapmalar için tasarlandı. Sıcaklığa bağlı model hatasında yetersiz.

**Genel değerlendirme:**
- v3 ana hedefine ulaştı: renkli gürültüde yanlış alarm ~10× azaldı, kapsama korundu. Allan'ı G1'in sıfır hipotezi olarak kullanma fikri (8B'nin kavramsal sonucu) deneyle destekleniyor.
- Ama dört yeni sorun çıktı ve hepsi aynı kökten geliyor: **dedektör, gürültü bütçesiyle açıklanamayan her şeyi hâlâ "arıza" sayıyor.** EMI (9E), kaynak belirsizliği (9F), model yapısı uyuşmazlığı (9H) ve sıcaklığa bağlı model hatası (9I) arıza değil, ama ayrı birer durum olarak modellenmedikleri için arızaya ya da kilitlenmeye dönüşüyorlar.
- Bu, ADR-010'daki çıktı biçimine işaret ediyor: ikili bayrak yerine "arıza", "belirsiz kaynak", "model güvenilmez" gibi ayrı durumlar ve kalibre edilmiş bir güven.
- **Genellenebilirlik uyarısı (7D gibi):** Bütün sonuçlar simülasyon, tek düğüm geometrisi ve 5 tohum. Gürültü parametreleri `assumed`. Allan kaydı aynı simülatörden geliyor; gerçek bir sensörde 1/f ve sıcaklığa bağlı gürültü farklı olabilir.

**v4 için yön (öncelik sırasıyla):**
1. Ortak mod kuralı: en az iki farklı fiziksel sensörden kanal (9E).
2. Sıcaklık kaynağı suçlamasında beraberlik → belirsiz durum, kimse suçlanmaz (9F).
3. Model hatası için süreç gürültüsü tabanı, böylece beyaz gürültüde de serbest bırakma işlesin (9H).
4. Değerlendirme: tuzak ölçütleri olay sonrası penceresini de kapsasın; yanlış alarm medyan ve en kötü tohumla raporlansın; tohum sayısı artırılsın (9B, 9E).
5. Isıtıcı sırasında renkli gürültüde my'nin suçlanmasını incelemek (9B).

---

## 10. G1 v4: §9'un üç düzeltmesi, 10 tohum

**Script:** [`matlab/g1/v4/g1_prototype_v4.m`](matlab/g1/v4/g1_prototype_v4.m) · **Dedektör:** [`g1_detect_v4.m`](matlab/g1/v4/g1_detect_v4.m) · **Değerlendirme:** [`g1_evaluate.m`](matlab/g1/g1_evaluate.m) (yeni alanlar eklendi, eskiler değişmedi)
**Ham sonuçlar:** [`g1_v4_results.csv`](matlab/g1/v4/g1_v4_results.csv) (640 satır: 8 senaryo × 2 gürültü × 10 tohum × 4 dedektör) · **Konsol çıktısı:** [`g1_v4_output.txt`](matlab/g1/v4/g1_v4_output.txt)
**Figürler:** [`g1_v4_1.png`](matlab/figures/g1_v4_1.png) (kapsama; yanlış alarm medyanı ve en kötü tohum), [`g1_v4_2.png`](matlab/figures/g1_v4_2.png) (v4 suçlama grafiği, renkli, tohum 0), [`g1_v4_3.png`](matlab/figures/g1_v4_3.png) (aynısı, beyaz)

**Amaç:** §9'un sonundaki v4 yönünün ilk üç maddesini uygulamak ve 9E/9F mekanizmalarını blok düzeyinde ölçmek.

**Ne yapıldı:** v3'e üç düzeltme eklendi. Her biri bir seçenek, böylece ayrı ayrı kapatılabiliyor:
1. **Ortak mod (9E):** ≥3 kanalın bozulması artık yetmiyor; kanallar en az **iki farklı algılama elemanından** (gyro, ivmeölçer, manyetometre) gelmeli.
2. **Belirsiz durum (9F):** Sıcaklık kaynağı suçlamasında beraberlik olursa kimse suçlanmıyor. Durum `tempAmbig` olarak kaydediliyor, iki referans da kullanılmaya devam ediyor.
3. **Model hatası tabanı (9H, 9I):** Sıcaklık katsayısı b ve histerezis c de random walk kabul edildi: 24 saatte veri sayfası sınırı (sb) kadar değişebiliyorlar. 24 saat, v1'den beri kullanılan unutma ufku; yeni bir ayar değil.

Dedektörler: v1, v3, **v4nf** (v4'ün 3. düzeltme olmadan hâli, ablasyon) ve v4. Tohum sayısı 10'a çıkarıldı (9B). Puanlama penceresi v3 ile aynı.

**Kontroller:**
- **Eşdeğerlik:** v4, v3'ün seçenekleriyle çalıştırıldığında v3'le aynı sonucu veriyor; fark 0.
- **Regresyon:** v1 ve v3'ün 0–4 tohumları v3 CSV'siyle karşılaştırıldı (160 satır); en büyük göreli fark 3,7e-15.

**Sonuç — arızalar** (tespit ve kapsama tohum ortalaması, gecikme tohum medyanı; v3 / v4nf / v4):

| Senaryo / gürültü | Gecikme [dk] | Kapsama |
|---|---|---|
| base / beyaz | 4,5 / 4,5 / **49,5** | %98 / %98 / **%77** |
| base / renkli | 15,0 / 15,0 / **57,0** | %92 / %92 / **%73** |
| hold-fault / beyaz | 7,5 / 7,5 / 15,5 | %92 / %92 / %85 |
| hold-fault / renkli | 56,5 / 56,5 / 62,5 (tespit %90 / %90 / %70) | %42 / %42 / %30 |
| accel-step / renkli | 1,5 / 1,5 / 2,0 | %99 / %99 / %99 |
| two-faults / beyaz | 5,5 / 5,5 / **65,0** | %98 / %98 / **%73** |
| two-faults / renkli | 31,5 / 31,5 / **76,0** | %88 / %88 / **%69** |
| day-cycle / renkli | 17,0 / 16,5 / 45,0 | %90 / %90 / %75 |

**Sonuç — yanlış alarm/saat** (medyan [en kötü tohum]; v3 / v4nf / v4):

| Senaryo / gürültü | v3 | v4nf | v4 |
|---|---|---|---|
| base / renkli | 3,9 [67,4] | 0,9 [60,2] | **0,0** [60,0] |
| emi / beyaz | 53,5 [110,5] | 85,3 [120,3] | 85,3 [145,3] |
| emi / renkli | 67,9 [128,7] | 86,2 [145,3] | 85,3 [145,3] |
| bme-fault / renkli | 7,4 [87,9] | 0,4 [60,0] | **0,0** [60,0] |
| hyst-relax / beyaz | 150,6 [204,3] | 152,3 [198,2] | **0,0 [0,0]** |
| day-cycle / renkli | 3,4 [63,9] | 0,0 [60,2] | **0,0 [0,0]** |

Diğer satırlar: beyaz gürültüde ve tuzak dışı senaryolarda medyan her yerde 0. En kötü tohum ise neredeyse her yerde tam 60,0 (Bulgu 10E).

**Sonuç — tuzaklar** (tohum ortalaması; v3 / v4nf / v4):

| Ölçüt | Beyaz | Renkli |
|---|---|---|
| EMI sırasında ortak mod sayılan blok | %98 / %0 / %0 | %97 / %1 / %0 |
| EMI sırasında manyetometre suçlanıyor | %10 / %100 / %100 | %0 / %100 / %100 |
| EMI **sonrasında** manyetometre suçlanıyor | %76 / %100 / %100 | %91 / %100 / %100 |
| BME arızasında BME688 suçlanıyor | %84 / %83 / **%2** | %2 / %0 / %0 |
| BME arızasında ICM suçlanıyor | %8 / %0 / %0 | **%90** / %0 / %0 |
| BME arızasında belirsiz | — / %9 / %91 | — / **%92** / %92 |
| BME arızasında hareket kanalı suçlanıyor | %24 / %11 / %10 | %32 / %21 / %10 |
| Isıtıcı sırasında sensör suçlama (koşu başına blok) | 6,5 / 6,7 / 1,9 | 11,8 / 2,5 / 2,2 |

**Bulgu 10A: 9E ve 9F mekanizmaları doğrulandı.**
- **9E:** v3'te EMI bloklarının %97–98'i ortak mod sayılıyormuş. 1. düzeltmeyle bu oran %0–1'e iniyor. EMI'nin tek bir sensörün üç ekseni üzerinden ortak mod sanıldığı hipotezi doğru.
- **9F:** v3 renkli gürültüde BME arızasında suçu %90 oranında ICM'ye veriyormuş. 2. düzeltmeyle bu blokların %92'si belirsiz oluyor; yani v3'teki ICM suçlamalarının neredeyse hepsi 0 = 0 beraberliğinden geliyormuş. Hipotez doğru.
- **9B'nin açık sorusu da büyük olasılıkla cevaplandı:** Renkli gürültüde ısıtıcı sırasındaki sensör suçlaması v3'te 11,8, v4nf'te 2,5. Muhtemel mekanizma 9F ile aynı: ısıtıcıda beraberlik → ICM suçlanıyor → kanallar ısınan BME'ye göre değerlendiriliyor → my suçlanıyor. v4nf 1. ve 2. düzeltmeyi birlikte içerdiğinden ikisinin payı ayrı ayrı ölçülmedi. v4'te kalan ısıtıcı suçlamalarının tamamı gx'te; bunlar da Bulgu 10E'deki kilitli tohumlardan geliyor.

**Bulgu 10B: 1. düzeltme doğru, ama altındaki asıl sorunu açığa çıkarıyor: CUSUM doyması.**
- EMI artık modele öğretilmiyor. Manyetometre EMI sırasında %100 suçlanıyor; G1 tek başına bunu ayırt edemeyeceği için bu beklenen ve dürüst davranış (8D).
- Ama EMI bittikten sonra da kanallar %100 suçlu kalıyor (Figür 2 ve 3, emi: 5,0 saatten gün sonuna kadar).
- **Mekanizma (kod okumasıyla):** Model donduğu için EMI bitince artıklar normale dönüyor. Ama CUSUM EMI sırasında çok büyük değerler biriktirdi: her blokta z yüzler mertebesinde ve EMI ~20 blok sürüyor. Artık normale dönünce CUSUM bloğu başına yalnızca k = 0,5 azalıyor; boşalması binlerce blok sürer.
- Yani kilitlenmenin bir kaynağı model değil, **karar istatistiğinin kendisi**. 9E'de bu durum ortak mod emilimiyle gizleniyordu.
- **Düzeltme yönü:** CUSUM'ı üstten sınırlamak, örneğin S ≤ 2h. Eşiğin üstündeki değer karara bilgi katmıyor. Bu sınırla olay bittikten sonra serbest bırakma en fazla (2h − h)/k = 20 blok sürer.

**Bulgu 10C: 3. düzeltme hedefini vuruyor, ama bedeli kabul edilemez.**
- **Kazanç:** hyst-relax / beyaz'da yanlış alarm 150,6'dan **0'a** iniyor, 10 tohumun hepsinde. day-cycle / renkli'de en kötü tohum bile 0. Model hatası tabanı serbest bırakmayı gerçekten mümkün kılıyor (9H, 9I).
- **Bedel 1, gecikme:** base / beyaz'da gecikme 4,5'ten 49,5 dk'ya çıkıyor, kapsama %98'den %77'ye iniyor; two-faults'ta gecikme 65 dk. Bu **beyaz gürültüde, 10 tohumun hepsinde** 48,5–50,5 dk: rastgele değil, yapısal.
  - **Mekanizma:** Arıza 4,5 saatte, aşağı rampa sırasında başlıyor. b serbestçe değişebildiği için, sıcaklıkla doğrusal ilerleyen kaymanın bir kısmı "sıcaklık katsayısı değişti" diye açıklanıyor. Bu, Bulgu 6F'deki özdeşleştirilebilirlik sorunu: monoton rampada kayma ile sıcaklık katsayısı birbirinden ayrılamıyor. Sıcaklığın sabit olduğu hold-fault / beyaz'da gecikme yalnızca 7,5'ten 15,5 dk'ya çıkıyor; bu da mekanizmayı destekliyor.
- **Bedel 2, BME ayrımı:** Beyaz gürültüde BME arızasında BME688'in doğru suçlanma oranı v4nf'te %83, v4'te **%2**. Bunun yerine %91 belirsiz. Kanalların BME referanslı modelleri BME'nin kaymasını b'ye yediriyor; böylece "hangi referansa karşı daha çok kanal bozuluyor" ayrımı kayboluyor.
- **Sonuç:** Model hatası tabanı, öğrenme sırasında da açık olduğu sürece dedektörü fazla uyumlu yapıyor. Bu, 8C'deki "sağlam ama unutkan" ucuna geri kaymak demek. Bu biçimiyle kabul edilemez.
- **Düzeltme yönü:** Tabanı yalnızca **dondurulmuş** kanallara uygulamak. Amaç zaten serbest bırakmaydı. Kanal öğrenirken model katı kalır, kayma b'ye emilmez. Kanal donduğunda tahmin varyansı model hatası kadar büyür ve serbest bırakma mümkün olur. Gerçek bir kayma t ile büyür, b'den gelen tahmin belirsizliği √t ile. Bu yüzden gerçek arıza yine suçlu kalmalı. Bunu önceden kayda geçiriyorum: bu bir hipotez, v5'te ölçülecek.

**Bulgu 10D: Belirsiz durum dürüst, ama ısıtıcı tuzağındaki eski başarıyı da belirsizliğe çeviriyor olabilir.**
- Figür 2 ve 3'te, tohum 0'da, ısıtıcı aralığının neredeyse tamamı "T amb" (belirsiz) olarak işaretli. v1'de ısıtıcı 24/24 blok BME'ye yükleniyordu (Bulgu 7).
- v4'te ısıtıcı sırasında BME suçlama oranı CSV'ye yazılmadı. Bu yüzden düşüşün 2. düzeltmeden mi (eski suçlamalar zaten gerçek ayrıma mı dayanıyordu) yoksa 3. düzeltmenin b emiliminden mi geldiği bilinmiyor. Ölçülmesi gerekiyor.
- Belirsizlik, yanlış bir suçlamadan iyidir. Ama sık görülen bir olayda sürekli "bilmiyorum" demek de değerli bir çıktı değil. ADR-010'daki kalibre edilmiş güven, bu iki ucun arasını doldurmalı.

**Bulgu 10E: 10 tohum yeni bir arıza biçimi gösterdi: koşunun başından itibaren kilitli kanal.**
- Bazı koşularda yanlış alarm oranı **tam olarak 60,0/saat**. Blok süresi 1 dk, yani tek bir kanal puanlanan **bütün** bloklarda suçlu.
- Bunu yaşayan koşular:
  - v3 ve v4nf: beyaz tohum 9 ve renkli tohum 8.
  - v4: beyaz tohum 4 ve renkli tohum 8.
- Senaryodan bağımsız: aynı tohumda base, hold-fault, accel-step, two-faults ve bme-fault'ta aynı oran var. Isıtıcı sırasındaki suçlamaların kanal dağılımına göre suçlu kanal **gx**: v4 beyazda 150, renklide 175 blok, hepsi gx. (Bu sayım yalnız v4 içindir; v3 ve v4nf'nin beyaz tohum 9 kilidinde suçlu kanal mz, bkz. 10F.)
- 0–4 tohumlarında beyaz gürültüde görülmediği için v3'te fark edilmemişti; tek görünür izi tohum 3'teki 44/saat'ti (9B). **5 tohum yetmezdi; 9B'deki uyarı doğrulandı.**
- **Mekanizma bilinmiyor.** En olası adaylar, sıcaklığın sabit olduğu ilk saatteki ısınma dönemi ya da birim bazında örneklenen sıcaklık katsayısının dedektörün varsaydığı sb sınırını aşması. Bunun için bir tanı scripti gerekiyor.

**Genel değerlendirme:**
- 1. ve 2. düzeltme kalıcı olmalı. İkisi de bir mekanizmayı doğruladı ve yanlış yorumları kaldırdı.
- 3. düzeltme bu biçimiyle geri alınmalı; yerine "yalnızca dondurulmuş kanallarda taban" denenmeli.
- Yeni iki sorun var: CUSUM doyması (10B) ve baştan kilitlenen kanal (10E).
- Genellenebilirlik uyarısı (7D, 9) aynen geçerli.

**v5 için yön:**
1. CUSUM'ı üstten sınırlamak: S ≤ 2h (10B).
2. Model hatası tabanını yalnızca dondurulmuş kanallara uygulamak (10C).
3. Tanı: beyaz tohum 4 ve 9, renkli tohum 8'de gx'in neden baştan kilitlendiği (10E). → Bulgu 10F
4. Isıtıcı sırasında BME suçlama ve belirsizlik oranlarını kaydetmek (10D).
5. Ardından kabul ölçütlerini sonuçları görmeden yazmak ve ayrılmış test kümesini kurmak.

### Bulgu 10F: Baştan kilitlenen gx'in tanısı (10E)

**Script:** [`matlab/g1/v4/g1_diag_gx_lock.m`](matlab/g1/v4/g1_diag_gx_lock.m) · **Çıktı:** [`g1_diag_gx_lock_output.txt`](matlab/g1/v4/g1_diag_gx_lock_output.txt) · **Figür:** [`g1_diag_gx_lock.png`](matlab/figures/g1_diag_gx_lock.png)
Bu script ve aşağıdaki iki ek kontrol, kullanıcının bu görev için verdiği izinle benim tarafımdan (MATLAB `-batch`) koşuldu. Ek kontroller kalıcı birer script değil, geçici dosyalar olarak koşuldu (`diag2.m`: genişlik seçimi ve z'nin işaret oranı; `diag3.m`: beyaz tohum 9'da kilitlenen kanal; `smoke_v5.m`: v5 duman testi). Sonuçları aşağıda.

**Ne yapıldı:**
- base senaryosunda 10 tohum × 2 gürültü için v3 ve v4'te gx'in ilk suçlanma anı ve puanlanan blokların ne kadarında suçlu olduğu ölçüldü. Simülatörün birim katsayıları da yanına yazıldı (yalnızca tanı için gerçek değerler).
- Kilitlenen koşularda ilk suçlamanın çevresinde z, CUSUM, seçilen histerezis genişliği ve z'nin işaret istatistikleri incelendi.

**Tablonun ilk sonuçları:**
- gx'in kilitlendiği koşular: beyaz tohum 4 (yalnız v4) ve renkli tohum 8 (v3 ve v4).
- Beyaz tohum 9'daki v3 (ve v4nf) kilidi **gx'te değil**. Ek bir kontrolle (`diag3.m`, geçici) baktım: base'de kilitlenen kanal **mz**, 1,39 saatten itibaren 380/380 blokta suçlu. Yani 10E'deki "suçlu kanal gx" çıkarımı yalnız v4'ün ısıtıcı sayımına dayanıyordu ve bu tohum için yanlıştı. mz kilidinin tetiği burada incelenmedi. Rampanın ~0,4 saat içinde ve histerezis genişliği seçimi o anda zaten 1,0 iken oluşuyor; yani mekanizma 2 değil. Beyaz gürültüde manyetometrenin K değeri 0 olduğundan, donduktan sonra serbest bırakılması da mümkün değil (9H).
- Gerçek gyro sıcaklık katsayıları her tohumda dedektörün sınırının (sb) içinde (|kb/sb| ≤ 0,98). **"Katsayı sınırı aşıyor" adayı elendi.**
- Kilit ısınma döneminde değil, **ilk suçlamadan sonra** oluşuyor: ilk suçlama 0,9 saatte (renkli 8) veya 1,18 saatte (beyaz 4).

**Mekanizma 1, renkli tohum 8: ilişkili artıklar yanlış alarmı tetikliyor, dondurma sonrası z hiç sıfıra dönmüyor.**
- **Tetik:** Bu tohumda gx artıklarının birinci gecikmeli öz-ilişkisi (bloklar 31–150) **0,65**; diğer dokuz tohumda −0,00 ile 0,19 arası. Bu tohumdaki 1/f gerçekleşmesinin düşük frekanslı bir sapması var ve tek Gauss-Markov terimi bunu temsil edemiyor (9G). Artıklar arka arkaya +2…+3 oluyor ve CUSUM, sıcaklık henüz sabitken (0,89 saat) eşiği aşıyor. CUSUM'ın ARL0 hesabı (k = 0,5, h = 10 → ~1e5 blok) bağımsız artık varsayımına dayanıyor; ilişkili artıkta bu hesap geçersiz.
- **Kilit:** Dondurulduktan sonra z'nin %100'ü pozitif, ortalaması 0,83 (v4'te 0,78), öz-ilişkisi 0,70. Figürde z neredeyse sabit bir 0,8 çizgisi. İşaretli CUSUM her blokta z − k ≈ +0,3 ekliyor ve **hiç boşalmıyor** (8 saat sonunda ~100).
- **v3'teki serbest bırakma gerekçem yanlıştı.** "Tahmin varyansı büyür, sapma açıklanabilir hâle gelir, CUSUM boşalır" diye düşünmüştüm. Ama donmuş bir modelde gerçek sapma ile tahmin belirsizliği aynı hızda büyüyor ve z, sabit işaretli, ~1 büyüklüğünde bir değerde takılıyor. Boşalma için z'nin k = 0,5'in altına inmesi gerekiyor; bu olmuyor.

**Mekanizma 2, beyaz tohum 4 (v4): model henüz tanımlanmadan dondurma (7C'nin bir türü).**
- İlk saatte sıcaklık sabit, histerezis genişliğinin skorları eşit, seçim varsayılan olarak 0,2 °C'de duruyor (gerçek değer 1,0).
- 1,0 saatte rampa başlıyor ve geçiş sırasında artıklar 3–4σ'ya çıkıyor:
  - **v3:** Seçim 69. blokta 1,0'a geçiyor; CUSUM en fazla 3,7'ye çıkıyor, alarm yok.
  - **v4:** Seçim önce 0,5'e (68. blok), ancak 71. blokta 1,0'a geçiyor. Bu arada CUSUM 11'e ulaşıyor ve kanal donuyor.
- Donan kanalın modeli doğru genişlikle hiç öğrenemiyor. Artık rampa boyunca +2,2σ (ICM) ve +3…+4σ (BME) düzeyinde sabit kalıyor; CUSUM gün sonuna kadar büyüyor.
- v3 ile v4 arasındaki fark yalnızca bir blokluk zamanlama. Yani bu, tohuma ve küçük model farklarına bağlı **sınırda** bir olay. Kök neden, model tanımlanmamışken (ilk termal uyarımdan önce) CUSUM'ın kanıt toplaması ve dondurmaya izin verilmesi.

**v5 için sonuç (önemli; v5 tasarlandıktan sonra, ama koşulmadan önce yazıldı):**
- v5'in iki değişikliği (CUSUM üst sınırı ve yalnızca dondurulmuş kanallarda taban) **10E'yi çözmeyecek**:
  - Üst sınır S'yi 20'de tutar, ama z − k > 0 olduğu sürece S eşiğin (10) üstünde kalır.
  - Sabit sıcaklıkta tabanın tahmin varyansına katkısı neredeyse sıfır, çünkü b'nin çarpanı T − T0 ≈ 0.
- Bu tanıya göre gereken iki ek değişiklik var:
  - **C. Serbest bırakma testi z'nin düzeyine değil, büyümesine bakmalı.** Gerçek bir kaymada donmuş z zamanla büyür (kayma ∝ t, belirsizlik ∝ √t → z ∝ √t). Sağlam bir sapmada ise z sabit kalır. Dondurulmuş kanalda z'nin eğimi ≤ 0 ve |z| belirli bir sınırın altındaysa kanal serbest bırakılıp CUSUM sıfırlanmalı.
  - **D. Model seçimi değişince CUSUM sıfırlanmalı, ya da model tanımlanana kadar ("model hazır değil") kanıt toplanmamalı.** Reddedilen bir model hipotezi altında biriken artık, kanalın aleyhine kanıt değil. Bu, ADR-010'daki "güven yok" durumuna da karşılık geliyor.
- İlişkili artık sorunu (tetik) ayrıca ele alınmalı: ARL0 ilişkili artıkla yeniden hesaplanmalı ya da artıklar beyazlatılmalı.

**Duman testi (v5, metrikler okunmadı):** v5, v4'ün seçenekleriyle v4'e, v4nf'nin seçenekleriyle v4nf'ye bit düzeyinde eşit (fark 0; 3 senaryo × 2 gürültü). Varsayılan v5 hatasız çalışıyor ve S ≤ Smax. `checkcode`: v5 prototipi, v5 dedektörü ve `g1_evaluate.m` için uyarı yok. v5'in tam değerlendirmesi, kabul ölçütleri yazılana kadar bilerek koşulmadı.

**v5'e sonradan eklenenler (kullanıcı onayıyla, hiçbir v5 sonucu görülmeden):** 10F'deki C (büyümeye bakan serbest bırakma; W = 30 blok, tek yönlü α = 0,01, |z| < 3) ve D (histerezis genişliği seçimi değişince, suçlu olmayan kanalların CUSUM'u sıfırlanıyor). İkinci duman testi ([`g1_smoke_v5.m`](matlab/g1/v5/g1_smoke_v5.m), kullanıcı koştu): v4 ve v4nf ile eşdeğerlik farkı 0; tüm v5 varyantları çalışıyor. `checkcode` yalnızca smoke scriptinde iki biçim uyarısı verdi (`setfield`); bunlar giderildi.

---

## 11. G1 simülasyon aşamasının kabul ölçütleri (önceden ilan)

**Durum:** Bu bölüm, ölçütler, test senaryoları ve test scripti, **v5'in hiçbir sonucu görülmeden** yazılıp commit'lendi. Amaç, "G1 ne zaman bitti?" sorusuna sonuçlardan bağımsız bir cevap vermek (§14.2/7'deki "toleransı önceden ilan et" ilkesi) ve aynı 8 senaryoya aşırı uyumu kesmek.

**Scriptler:** [`matlab/g1/test/g1_scenarios_test.m`](matlab/g1/test/g1_scenarios_test.m) (ayrılmış senaryolar) · [`matlab/g1/test/g1_acceptance_test.m`](matlab/g1/test/g1_acceptance_test.m) (tek atışlık test; geçti/kaldı kararını kendisi veriyor)

### Sektörde neye bakılıyor? (araştırma özeti)

Kaynakların tam listesi: [Kaynaklar](#kaynaklar).

Bizim problem sınıfı, yani düşük maliyetli düğümlerde referanssız sağlık tahmini için **hazır bir standart sayı yok**. Komşu alanlardaki referanslar:
- **Literatürdeki ölçütler:** Arıza tespiti çalışmaları başarıyı üç ölçütle raporluyor: tespit gecikmesi, yanlış alarm oranı ve kaçırılan tespit oranı ([PMC8124649](https://pmc.ncbi.nlm.nih.gov/articles/PMC8124649/)) [R13]. Sayılar uygulamaya özgü. İHA ve quadrotor çalışmalarında gecikmeler milisaniye mertebesinde ([arXiv 2102.06439](https://arxiv.org/pdf/2102.06439)) [R14], ama bunlar ani ve büyük arızalar. Bizim yavaş termal kayma problemimizle doğrudan karşılaştırılamaz.
- **Havacılık ve GNSS bütünlüğü (RAIM/FDE):** Yanlış uyarı ≤ 10⁻⁵/saat (FDE) ya da 0,002/saat (hassas olmayan yaklaşma); kaçırılan tespit < 10⁻⁷ ([Navipedia: RAIM](https://gssc.esa.int/navipedia/index.php/RAIM_Algorithms), [Navipedia: Integrity](https://gssc.esa.int/navipedia/index.php/Integrity), [Wikipedia: RAIM](https://en.wikipedia.org/wiki/Receiver_autonomous_integrity_monitoring)) [R10]–[R12]. Bunlar can güvenliği seviyesi; düşük maliyetli MEMS düğümleri için hedef değil, ama ölçütün **saat başına olay** cinsinden tanımlandığını gösteriyor.
- **Endüstriyel alarm yönetimi (ISA-18.2 / EEMUA 191):** Operatör başına ortalama ≤ 6 alarm/saat "çok büyük olasılıkla kabul edilebilir" (yaklaşık 10 dakikada 1), 12/saat "yönetilebilecek en üst sınır" ([Emerson](https://www.emerson.com/documents/automation/alarm-management-by-numbers-en-38292.pdf), [Chemical Engineering](https://www.chemengonline.com/alarm-management-numbers/)) [R7]–[R9]. Bu bizim kullanım senaryomuza en yakın olanı: bir operatör ya da sunucu birçok düğümün alarmını izliyor.
- **İstatistiksel süreç kontrolü (CUSUM):** Yanlış alarm toleransı tasarımcı tarafından ARL0 olarak seçilir; eşik h bu toleransa göre ayarlanır. Düşük yanlış alarm, daha uzun tespit gecikmesi demektir ([NIST e-Handbook](https://www.itl.nist.gov/div898/handbook/pmc/section3/pmc3131.htm)) [R5], [R6].

**Bundan çıkan sonuç:**
- Ölçütler bizim tanımımız. Ama gerekçeli olmalı ve hem **olay sayısı** hem **etkilenen süre** cinsinden verilmeli.
- Şimdiye kadar yalnızca "suçlu blok/saat" ölçüyorduk. Bu, kilitlenmeyi iyi gösteriyor ama kaç kez alarm verildiğini göstermiyor. Bu yüzden olay tabanlı bir ölçüt ekledim (K1c).
- **Yorum:** Bunlar sahada kullanılabilirlik hedefi değil, **simülasyonda tutarlılık hedefi**. Sahada geçerli olup olmadıkları gerçek veriyle ayrıca sınanacak.

### Yapı: iki aşama

1. **Geliştirme (v5 koşusu, [`g1_prototype_v5.m`](matlab/g1/v5/g1_prototype_v5.m), mevcut 8 senaryo × 10 tohum).** G1'i geçirmez ya da kaldırmaz; yalnızca aday seçer.
   **Seçim kuralı:** Varsayılan aday v5. Bir ablasyon (v5a, v5noC, v5noD) aşağıdaki geliştirme ölçütlerinin hiçbirinde v5'ten kötü değilse ve en az birinde daha iyiyse, daha basit olan o ablasyon seçilir. Geliştirme ölçütleri, K1–K3'ün geliştirme kümesindeki karşılıkları: yanlış alarm medyanı ve en kötü tohum, tespit, gecikme medyanı, kapsama, ısıtıcı, EMI sonrası ve BME ölçütleri.
2. **Ayrılmış test (tek atış, [`g1_acceptance_test.m`](matlab/g1/test/g1_acceptance_test.m)).** 10 yeni senaryo × 2 gürültü × 20 tohum (100–119) = 400 koşu. Gürültü karakterizasyonu geliştirmedekiyle aynı.
   - **Geçerse** G1'in simülasyon aşaması kapanır.
   - **Kalırsa** kalan ölçüt yazılır, iddianın kapsamı daraltılır. Test kümesine bakarak yeniden ayar **yapılmaz**.
   - İzin verilen tek müdahale, dedektörün mantığını değiştirmeyen hata düzeltmesi.

### Ölçütler (her gürültü tipi için ayrı ayrı sağlanmalı)

| # | Ölçüt | Eşik | Gerekçe |
|---|---|---|---|
| K1a | Yanlış suçlama (arızasız kanallar, blok/saat), medyan koşu | ≤ 0,5 | Tipik bir koşuda saatte en fazla yarım dakika yanlış suçlama |
| K1b | Aynı, **her koşu** | ≤ 6 | Saatin %10'u. Tüm koşu boyunca kilitlenen bir kanal (60/saat) bu ölçütle kesin kalır (10E) |
| K1c | Yanlış alarm **olayı** (yeni başlayan yanlış suçlama)/saat, ortalama | ≤ 0,12 | ISA-18.2: operatör başına ≤ 6/saat. Bir operatöre **50 düğüm** düşerse (`assumed`), düğüm başına ≤ 0,12/saat (günde ~3) |
| K2a | Arızalı koşularda 120 dk içinde tespit oranı | ≥ %95 | Kaçırılan tespit ≤ %5 |
| K2b | Gecikme medyanı | beyaz ≤ 15 dk, renkli ≤ 40 dk | Geliştirmede v4nf: beyaz 4,5–5,5, renkli 15–31,5 dk; pay bırakıldı. Termal kayma saatler ölçeğinde bir süreç |
| K2c | Ortalama kapsama | ≥ %80 | Arıza başladıktan sonra çoğu blokta suçlu olmalı (unutmama, 8C) |
| K2d | Sabit sıcaklıkta yavaş kayma: 180 dk içinde tespit oranı | ≥ %80 | Algılanabilirlik sınırına yakın (9D), bu yüzden daha gevşek. Büyüklük 1 saatte ≥ 5·K·√(1 saat) olacak şekilde seçildi |
| K3a | Isıtıcı sırasında sensör suçlama, koşu başına blok | ≤ 1 | Tuzak sınıf 8 (6A) |
| K3b | Olay dışında "T src" alarmı, koşu başına blok | ≤ 1 | 6D, 8A |
| K3c | EMI **sonrasında** manyetometrenin suçlanma oranı | ≤ %10 | EMI sırasında suçlama kapsam dışı (G1 tek başına çözemez, 8D), ama olay bitince serbest bırakma çalışmalı (10B) |
| K3d | BME arızasında hareket kanalı suçlanıyor | ≤ %5 | 8E, 9F |
| K3e | BME arızasında ICM suçlanıyor | ≤ %5 | 9F |
| K3f | BME arızasında "BME suçlu" ya da "belirsiz" | ≥ %90 | Belirsizlik, yanlış suçlamadan iyidir (10D) |

K1 hesabında EMI olayı sırasındaki manyetometre suçlamaları sayılmıyor (K3c'deki gerekçeyle).

### Ayrılmış test senaryoları

Hepsi 8 saatlik simülasyon. Isıtıcı patlaması her senaryoda var, ama zamanı farklı.

| # | Senaryo | Sınıf | Neyi sınıyor | Geliştirmeden farkı |
|---|---|---|---|---|
| T1 | t1-fast-ramp | arıza | gz kayması 0,02 °/s/saat, aşağı rampanın ortasında | 20→35→20 °C, rampalar 10 °C/saat |
| T2 | t2-plateau-step | arıza | ax'te 0,2 mg basamak, platoda | Farklı kanal, büyüklük ve sıcaklık bölgesi |
| T3 | t3-slow-sine | arıza | gy kayması, 25 ± 5 °C ve 6 saat periyotlu sinüs | Daha yavaş ve küçük döngü, farklı kanal |
| T4 | t4-mag-drift | arıza | mz'de 0,3 µT/saat kayma | **Manyetometre arızası ilk kez** |
| T5 | t5-two-heaters | yok | İki ısıtıcı patlaması (rampada ve durgunken) | Çoklu ısıtıcı (simülatör genişletildi) |
| T6 | t6-emi-plateau | yok | Platoda EMI, genlik [−1 2 −0,5] µT | Sabit sıcaklıkta EMI |
| T7 | t7-bme-step | yok | BME688'de +1 °C basamak | Kayma yerine basamak |
| T8 | t8-cycle-clean | yok | 25 ± 8 °C, 3 saat periyot, arızasız | Saf yanlış alarm ölçümü |
| T9 | t9-relax-az | arıza | az kayması 0,3 mg/saat, gevşeme histerezisi τ = 300 s | Farklı τ ve kanal |
| T10 | t10-slow-drift | yavaş | Sabit 28 °C'de gx kayması 0,015 °/s/saat | K2d için |

**Simülatör değişikliği:** `simulate_node.m`'de `heaterOn` artık satır başına bir patlama alıyor. Tek satırlık varsayılan yol bit düzeyinde aynı; bunu v5 koşusundaki v4 regresyonu doğrulayacak.

---

## 12. G1 v5: geliştirme koşusu ve aday seçimi

**Script:** [`matlab/g1/v5/g1_prototype_v5.m`](matlab/g1/v5/g1_prototype_v5.m) · **Dedektör:** [`g1_detect_v5.m`](matlab/g1/v5/g1_detect_v5.m)
**Ham sonuçlar:** [`g1_v5_results.csv`](matlab/g1/v5/g1_v5_results.csv) (800 satır: 8 senaryo × 2 gürültü × 10 tohum × 5 dedektör) · **Konsol çıktısı:** [`g1_v5_output.txt`](matlab/g1/v5/g1_v5_output.txt)
**Figürler:** [`g1_v5_1.png`](matlab/figures/g1_v5_1.png) (kapsama ve yanlış alarm), [`g1_v5_2.png`](matlab/figures/g1_v5_2.png) (v5 suçlama grafiği, renkli, tohum 0), [`g1_v5_3.png`](matlab/figures/g1_v5_3.png) (aynısı, beyaz)

**Ne yapıldı:** §11'deki 1. aşama. v4nf (karşılaştırma), v5 ve üç ablasyonu (v5a: taban yok, v5noC: serbest bırakma testi yok, v5noD: model değişiminde sıfırlama yok) geliştirme kümesinde koşuldu. Koşuyu kullanıcı çalıştırdı.

**Kontroller:**
- **Eşdeğerlik:** v5, v4'ün seçenekleriyle v4'e eşit; fark 0.
- **Regresyon:** v4nf'nin 160 satırı v4 CSV'siyle karşılaştırıldı, en büyük göreli fark 3,3e-15. Bu, simülatördeki çoklu ısıtıcı değişikliğinin eski yolu bozmadığını da doğruluyor.

**Aday seçimi (§11'deki kurala göre): v5.** Her ablasyon en az bir geliştirme ölçütünde v5'ten kötü:
- **v5noD:** Beyaz gürültüde en kötü tohum 3,8/saat (v5: 1,9).
- **v5a:** Beyaz gürültüde en kötü tohum 2,7/saat; hyst-relax / beyaz medyanı 89/saat (v5: 25).
- **v5noC:** Her yerde belirgin biçimde kötü; en kötü tohum 32–60/saat.

**v5'in geliştirme kümesindeki durumu** (kabul ölçütlerinin geliştirme karşılıkları; hold-fault K2d yerine sayıldı; K1c bu CSV'de ölçülmedi):

| Ölçüt | Beyaz | Renkli | Sonuç |
|---|---|---|---|
| K1a yanlış alarm medyanı ≤ 0,5 | 0,00 | 0,16 | ✅ |
| K1b her koşu ≤ 6 | 35,1 | 50,1 | ❌ (EMI ve hyst-relax; renklide tohum 0 her senaryoda 6,47) |
| K2a 120 dk içinde tespit ≥ %95 | %100 | %100 | ✅ |
| K2b gecikme medyanı (≤ 15 / ≤ 40 dk) | 4,5 | 16,5 | ✅ |
| K2c kapsama ≥ %80 | %98 | %87 | ✅ (accel-step / renkli %76) |
| K2d yavaş kayma, 180 dk içinde ≥ %80 | %100 | %90 | ✅ |
| K3a ısıtıcı ≤ 1 blok/koşu | **1,54** | 0,00 | ❌ beyaz |
| K3c EMI sonrası ≤ %10 | **%29** | **%29** | ❌ |
| K3d BME arızasında hareket kanalı ≤ %5 | %0,0 | **%5,2** | ❌ renkli (kıl payı) |
| K3e BME arızasında ICM ≤ %5 | %0,1 | %0,3 | ✅ |
| K3f BME veya belirsiz ≥ %90 | %92 | %92 | ✅ |

Not: Geliştirme CSV'sinde K1 hesabına EMI olayı sırasındaki manyetometre suçlamaları da giriyor; kabul testinde bunlar dışarıda bırakılıyor. Bu yüzden EMI satırları burada biraz kötü görünüyor. Ama EMI sonrası suçlama tek başına K1b'yi aşıyor.

**Bulgu 12A: Serbest bırakma testi (C) çalışıyor; 10E'nin kilitlenmeleri büyük ölçüde gitti.**
- Baştan kilitlenen kanalların (60/saat) hepsi yok oldu. Beyaz gürültüde en kötü tohum 60 → 1,9/saat, renklide 60,2 → 6,5/saat (EMI ve hyst-relax hariç).
- Figür 2'de (tohum 0, renkli) az, ~4,8–5,5 saatte suçlanıp kendiliğinden serbest bırakılıyor; v4'te bu gün sonuna kadar sürüyordu.
- hyst-relax / beyaz: medyan 152 → 25/saat. EMI sonrası suçlama %100 → %29.
- v5noC ile karşılaştırma: C olmadan en kötü tohum 32–60/saat. Etkinin neredeyse tamamı C'den geliyor.

**Bulgu 12B: C, basamak arızasını da "sağlam sapma" sanıp serbest bırakıyor. Bu yapısal bir sınır.**
- accel-step / renkli'de kapsama %99 → %76. 10 tohumun 4'ünde kapsama %22–37'ye iniyor (v5noC'de hepsi %98–99).
- **Mekanizma:** Basamak arızası sabit bir ofsettir; donmuş modelde z büyümez. C'nin ayırt ettiği şey tam olarak "büyüyen" ve "sabit" sapma. Basamak sabit olduğu için serbest bırakılıyor. Renkli gürültüde tahmin belirsizliği büyüdükçe |z| 3'ün altına iniyor ve test geçiyor. Beyazda belirsizlik büyümediği için |z| > 3 kalıyor, kanal suçlu kalıyor (kapsama %100).
- **Sonuç:** "Büyüme" ölçütü kaymaları korur ama basamakları korumaz. Basamak arızasında doğru davranış tartışmalı: Kalıcı bir ofset "arıza" mı, yoksa yeniden kalibre edilip kabul edilecek "yeni normal" mi? Bu bir tasarım kararı. Teşhis kestiricisinin formel tanımında açıkça seçilmeli (§14.2/4); şimdiki hâliyle G1 renkli gürültüde basamağı bir süre sonra unutuyor.
- Ayrılmış testte T2 bir basamak arızası. K2c'nin orada kalma riski var.

**Bulgu 12C: Model yapısı uyuşmazlığı hâlâ yanlış alarm kaynağı; ama artık geçici.**
- hyst-relax / beyaz, Figür 3: aşağı rampa 6 saatte bitince gx, gy, ax ve ay ~6,2–6,8 saat arasında suçlanıyor, sonra serbest bırakılıyor.
- Gevşeme histerezisi, play operatörüyle temsil edilemiyor (7D). Dönüş noktalarında sistematik bir artık oluşuyor. C kilidi açıyor ama alarmı engellemiyor.
- Bu alarmlar ortak mod olarak da yakalanmıyor. Birden çok algılama elemanından kanal bozuluyor, ama aynı blokta ≥ 3 kanal eşiği aşmıyor; artıklar zamana yayılıyor.

**Bulgu 12D: EMI sonrası serbest bırakma yavaş ve bazen eksik.**
- Beyaz gürültüde manyetometreler EMI bittikten sonra 0,5–1,5 saatte serbest bırakılıyor. Renklide (tohum 0) mx gün sonuna kadar suçlu kalıyor.
- Yavaşlığın nedeni W = 30 blokluk pencere, ve pencere içinde |z| < 3 şartı. EMI sırasında |z| yüzlerle ölçülüyor, bu bloklar pencereden çıkana kadar serbest bırakma mümkün değil. Bu, W'nin önceden ilan edilmiş bir bedeli.

**Bulgu 12E: Artık öz-ilişkisi, model uyuşmazlığının iyi bir göstergesi.**
- Öz-ilişkisi 0,3'ü aşan koşular: beyaz gürültüde 19/80, bunların 10'u EMI ve 9'u hyst-relax. Renklide 17/80, bunların 10'u EMI, diğer senaryolarda koşu başına en fazla 1.
- Yani yüksek öz-ilişki büyük ölçüde gürültüden değil, **modelin açıklayamadığı yapıdan** (EMI, yanlış histerezis biçimi) geliyor.
- Bu, ADR-010'daki "model güvenilmez" durumu için doğrudan kullanılabilecek bir ölçü: kanal suçlanmadan önce "artıklar bağımsız mı?" diye sorulabilir. Henüz kullanılmadı; ileride değerlendirilmeli.

**Bulgu 12F: Geliştirme kümesinde v5 kabul ölçütlerinin dördünde kalıyor.**
- Kalanlar: K1b (her koşu ≤ 6), K3a (ısıtıcı, beyaz), K3c (EMI sonrası) ve K3d (BME arızası, renkli, kıl payı).
- Bunların nedenleri biliniyor (12B–12D). Ayrılmış testte de büyük olasılıkla kalacaklar. Test, bunların yeni senaryolara genellenip genellenmediğini ve diğer ölçütlerin (ilk kez test edilen manyetometre arızası, BME basamağı) tutup tutmadığını gösterecek.

---

## 13. G1 kabul testi (ayrılmış küme, tek atış): FAIL

**Script:** [`matlab/g1/test/g1_acceptance_test.m`](matlab/g1/test/g1_acceptance_test.m) (cbf4b01'deki ilan edilmiş hâliyle, değiştirilmeden) · **Ham sonuçlar:** [`g1_acceptance_results.csv`](matlab/g1/test/g1_acceptance_results.csv) (400 koşu) · **Çıktı:** [`g1_acceptance_output.txt`](matlab/g1/test/g1_acceptance_output.txt)

**Ne yapıldı:** Aday v5 (§12), 10 ayrılmış senaryo × 2 gürültü × 20 tohum (100–119) üzerinde bir kez koşuldu. Koşuyu kullanıcı çalıştırdı. Hata düzeltmesi gerekmedi. **Sonuç: FAIL.** §11'deki kurala göre bu sonuç üzerinden ayar yapılmayacak; bu küme artık "görülmüş" sayılıyor. Bundan sonraki bir sürüm yeni bir ayrılmış kümeyle sınanmalı.

| Ölçüt | Beyaz | Renkli |
|---|---|---|
| K1a yanlış alarm medyanı ≤ 0,5/saat | ✅ 0,00 | ✅ 0,00 |
| K1b her koşu ≤ 6/saat | ❌ 62,1 | ❌ 26,1 |
| K1c yanlış alarm olayı ≤ 0,12/saat | ❌ 0,53 | ❌ 0,14 |
| K2a 120 dk içinde tespit ≥ %95 | ✅ %100 | ✅ %98 |
| K2b gecikme medyanı (≤ 15 / ≤ 40 dk) | ✅ 5,5 | ✅ 27,0 |
| K2c kapsama ≥ %80 | ✅ %92,5 | ❌ %66,6 |
| K2d yavaş kayma, 180 dk içinde ≥ %80 | ✅ %100 | ✅ %100 |
| K3a ısıtıcı ≤ 1 blok/koşu | ✅ 0,37 | ✅ 0,30 |
| K3b olay dışı "T src" ≤ 1 blok/koşu | ❌ 23,2 | ❌ 23,2 |
| K3c EMI sonrası ≤ %10 | ❌ %16,0 | ❌ %14,2 |
| K3d BME arızasında hareket kanalı ≤ %5 | ✅ %0,5 | ✅ %2,1 |
| K3e BME arızasında ICM ≤ %5 | ✅ %0,0 | ✅ %0,1 |
| K3f BME veya belirsiz ≥ %90 | ✅ %100 | ✅ %99,9 |

**Bulgu 13A: Çekirdek tespit genelleniyor.**
- Tespit oranı, gecikme ve yavaş kayma ölçütleri yeni senaryolarda da geçiyor.
- **İlk kez test edilen manyetometre arızası (T4):** kapsama %97 (beyaz) / %93 (renkli), gecikme medyanı 7,5 / 15 dk.
- **İlk kez test edilen BME basamak arızası (T7):** BME suçlu ya da belirsiz %100. Hareket kanalı suçlama %0,5 / %2,1.
- Yanlış alarm medyanı her yerde 0. Tipik bir koşu temiz; sorun kuyrukta ve belirli senaryolarda.
- **İddia için anlamı:** "Sıcaklık değişimi altında kayma tipi arızaları, sağlam kanalları tipik olarak suçlamadan tespit etme" iddiası ayrılmış kümede destekleniyor.

**Bulgu 13B: K1b ve K1c kalıyor. Kaynak öngörülen iki mekanizma: model uyuşmazlığı ve EMI.**
- **T9 (gevşeme histerezisi, τ = 300 s) / beyaz:** yanlış alarm medyanı 45,6/saat, en kötüsü 62,1; olay oranı 3,86/saat. Bu, 12C'nin genellenmesi. Daha uzun τ ile uyuşmazlık daha da büyüyor.
  - Renkli gürültüde aynı senaryonun medyanı 0. Geniş gürültü bütçesi uyuşmazlığı yutuyor (9H'deki iki yönlü sonuç). Yani bu sorun yalnız gürültüsüz modelde görünür oluyor.
- **T6 (EMI):** medyan ~10/saat, olay oranı ~1/saat (12D).
- Diğer senaryolarda en kötü tohum 1,1–13,6/saat. K1b, T9 ve T6 olmadan da renkli gürültüde kalırdı (T4 12,2; T9 13,6; T10 11,8; T5 11,2).

**Bulgu 13C: K2c (renkli) kalıyor. Kaynak basamak arızası, tam 12B'nin öngördüğü gibi.**
- **T2 (platoda 0,2 mg basamak) / renkli: kapsama %11.** Beyazda %73.
- Serbest bırakma testi basamağı "büyümeyen sapma" olarak görüp bırakıyor. Kaba bir hesap: ivmeölçerin uydurulan K değeri ~0,04 mg/√saat. Random walk'un 3σ'sı 0,2 mg'a yaklaşık 3 saatte ulaşıyor. Bu süreden sonra basamak istatistiksel olarak random walk'tan ayrılamıyor.
- Diğer kapsama düşüşleri: T3 %77 ve T9 %65 (renkli).
- **Sonuç:** Bu bir ayar hatası değil, "kalıcı ofset arıza mıdır?" sorusunun cevapsız kalması (12B). Formel tanımda karar verilmeli.

**Bulgu 13D: K3b'de yeni ve beklenmedik bir arıza biçimi: sıcaklık kaynağı modelinin kilitlenmesi.**
- Olay dışı "T src" alarmları **yalnızca üç senaryoda**: T2'de koşu başına 179 blok (~3 saat), T8'de 40, T5'te 12,7. Değerler beyaz ve renkli gürültüde **birebir aynı**. Bu alarm yalnız sıcaklık okumalarına bakıyor; aynı tohumda aynı sıcaklıklar üretildiği için gürültüden bağımsız olması bekleniyor.
- Bu üç senaryoda ısıtıcı rampa sırasında (T2, T5) ya da sinüs içinde (T8) çalışıyor. Ama ısıtıcısı rampa sırasında olan T7'de alarm yok. Yani tek açıklama ısıtıcı değil.
- **Muhtemel mekanizma (doğrulanmadı):** Sıcaklık kaynağı modeli (T_bme ≈ lag(T_icm)) yalnız |zT| < 3 iken güncelleniyor. Bir kez dışarı çıkınca bir daha öğrenemiyor. Bu, 7C'deki "dondurma = kilit" sorununun sıcaklık kanalındaki hâli. C'nin bir karşılığı bu kanalda yok.
- Geliştirme kümesinde bu hiç görülmedi (orada olay dışı alarm 0,4). Ayrılmış testin değeri tam olarak bu.

**Bulgu 13E: K3c'nin ölçütü ile pencere uzunluğu çelişiyordu. Bu benim ilan hatam.**
- EMI sonrası suçlama %14–16. Serbest bırakma için pencerede 30 blok |z| < 3 gerekiyor. EMI bittikten sonra bu en az 30 dk demek. T6'da EMI sonrası ~4 saat var; 3 manyetometre kanalının her biri en az 30 dk suçlu kalırsa oran zaten ~%12 eder.
- Yani W = 30 ile K3c ≤ %10 neredeyse ulaşılamazdı. İkisini aynı anda ilan ederken bu tutarlılığı kontrol etmedim.
- Ölçüt geriye dönük olarak değiştirilmeyecek; bu not kayıt için.

**Genel değerlendirme:**
- G1 v5, simülasyon kabul testini geçmedi. Çekirdek tespit (K2a, K2b, K2d) ve tuzakların çoğu (K3a, K3d–K3f) yeni senaryolara genelleniyor.
- Kalan beş ölçütün dördünün nedeni önceden biliniyordu: model uyuşmazlığı (12C), EMI'den yavaş çıkış (12D), basamak arızası (12B) ve K3c'deki ölçüt çelişkisi (13E).
- Biri yeni: sıcaklık kaynağı kilidi (13D).
- **İddia kapsamı (ADR-019):** Şu an savunulabilecek ifade şu: "Termal ortak mod ayrıştırması, sıcaklık değişimi altında kayma tipi IMU arızalarını, tipik koşuda yanlış alarm üretmeden ve uydurulmuş gürültü modeliyle tutarlı bir gecikmeyle tespit eder." Kuyruk davranışı (en kötü koşu), basamak arızası, histerezis biçim uyuşmazlığı ve sıcaklık kaynağı kilidi açıkça sınırlama olarak yazılmalı.

**v6 için yön (öncelik sırasıyla; kullanıcıyla henüz karara bağlanmadı):**
1. **Önce tanı (13D):** Sıcaklık kaynağı modelinin T2, T5 ve T8'deki kilidi. Gürültüden bağımsız olduğu için tek tohumla incelenebilir. Mekanizma doğrulanırsa, C'nin bir karşılığı bu kanala da uygulanmalı.
2. **Çok durumlu çıktı (12B, 12E, 13B, 13C; ADR-010):** İkili "suçlu / sağlam" yerine en az şu durumlar:
   - **"arıza"**: büyüyen sapma.
   - **"ofset olayı, yeniden kalibre edildi"**: basamak tespit edilip modele kabul edildiyse. Bu bir kaçırılan tespit değil, rapor edilen bir olay.
   - **"model güvenilmez"**: artıklar ilişkili ya da birden çok elemanda dönüş noktasında yapısal artık varsa. Kanal suçlanmaz.
   Bu, 12E'deki öz-ilişki göstergesini doğrudan kullanır ve basamak ile histerezis sorunlarını ayar yapmadan, anlam düzeyinde çözer. Değerlendirme ölçütleri de buna göre (önceden) yeniden tanımlanmalı.
3. **Olay sonu algılama (12D, 13E):** Büyük bir sapmanın (|z| ≫ 3) aniden bitmesi ayrı bir durum. Pencerenin dolmasını beklemeden daha kısa bir onayla serbest bırakmak.
4. **Yeni ayrılmış küme:** §13'teki küme görüldü. v6 için yeni senaryolar ve tohum 200+ ile yeni bir küme, ölçütlerle birlikte v6 sonuçlarından önce ilan edilmeli. K3c gibi ölçüt ile tasarım parametresi arasındaki tutarlılık (13E) ilan sırasında kontrol edilmeli.

---

## 14. Tanı: sıcaklık kaynağı modelinin kilitlenmesi (13D)

**Script:** [`matlab/g1/v6/g1_diag_tsrc_lock.m`](matlab/g1/v6/g1_diag_tsrc_lock.m) · **Çıktı:** [`g1_diag_tsrc_lock_output.txt`](matlab/g1/v6/g1_diag_tsrc_lock_output.txt) · **Figür:** [`g1_diag_tsrc_lock.png`](matlab/figures/g1_diag_tsrc_lock.png)
Kullanıcı koştu. Yalnızca tanı amaçlı. §13'teki ayrılmış küme zaten görüldü; buradan v5'e ayar yapılmıyor.

**Ne yapıldı:**
- v5'in sıcaklık kaynağı modeli (T_bme ≈ a + b·lag(T_icm, τ), gecikme ızgarası, |zT| < 3 kapılı RLS) yalnızca sıcaklıkları okuyor. Bu yüzden `g1_detect_v5.m`'den satır satır kopyalandı (`tsrcModel`). Allan uydurması ya da hareket kanalı gerekmiyor ve gürültü türü önemsiz (yalnızca beyaz koşuldu).
- Kopyaya iki şey eklendi: kapıyı kaldırma anahtarı (her blokta güncelle) ve seçilen adayın iç durumunun kaydı (hata eT, öngörülen std sT, eğim b ve std'si, gecikme, güncellendi mi).
- 10 test senaryosu × tohum 100–119 koşuldu. Ayrıca T2, T5, T7 ve T8'in seçili tohumları ısıtıcısız tekrarlandı.

**Bulgu 14A: Kopya birebir.** Isıtıcı dışı alarm sayısı, kabul testi CSV'sindeki `tSrcFlagsOutside` ile **200/200 koşuda** aynı. Aşağıdaki her şey testteki davranışın kendisi.

**Bulgu 14B: T2 ve T5'teki kilidi ısıtıcı başlatıyor; kilidi yanlış öğrenilmiş eğim ve aşırı güvenli bir hata bütçesi tutuyor. 13D'deki hipotez doğrulandı, ama kapı tek başına neden değil.**
- **Tetik ısıtıcı:** Isıtıcısız tekrarda alarm **0** (T2/100: 216 → 0; T5/108: 173 → 0; T5/118: 172 → 0). Isıtıcı rampa sırasında açılınca zT ~37'ye çıkıyor, kapı kapanıyor. İlk ısıtıcı dışı alarm, son güncellemeden tam 22 blok sonra geliyor: 12 dk ısıtıcı + doğruluk penceresinin 10 dk kuyruğu (3τ_BME). Yani kilit, ısıtıcı penceresinin bittiği ilk blokta başlıyor.
- **Kilidi tutan şey eğim hatası:**
  - Kapı kapandığında b = 0,986 (T2/100) ve 0,984 (T5/108). Kapısız modelde b ~0,99–1,0'a oturuyor (şekilden okundu).
  - Isıtıcı rampa başladıktan yalnızca 0,5 saat sonra açılıyor ve o anda seçili gecikme 60 s. Geliştirmede bulunan etkin gecikme ise 80 s (§7).
  - Sıcaklık ~16 °C yükseldiğinde bu eğim hatası platoda ~0,1–0,15 °C'lik kalıcı bir hata üretiyor.
- **Aşırı güven:**
  - Model hatayı sT ≈ **0,020–0,031 °C** bekliyor. Bu değer ısınma süresindeki farkların std'sinden geliyor (taban 0,02 °C), yani kabaca okuma çözünürlüğü. Model hatası için bir pay yok.
  - Eğimin kendi std'si 0,0016–0,0023. Gerçek eğim hatası bunun yaklaşık 6–9 katı.
- **Kendiliğinden çıkış yok:** RLS yalnızca güncellemede unutuyor. Donmuşken kovaryansı büyümüyor, bu yüzden sT sabit kalıyor (kanallardaki 10C/B ve C'nin karşılığı bu kanalda yok). T2'de kilit, hata ancak iniş rampasında işaret değiştirip sıfırdan geçince çözülüyor (şekilde ~5 saat).
- **T5'in tohuma bağlılığı:**
  - T5 yalnızca tohum 108 ve 118'de kilitleniyor (126–127 blok); diğer 18 tohumda 0. İkisinde de ilk alarm 1,88 saatte.
  - Birim ofsetlerinde (offIcm, offBme) iki tohumu diğerlerinden ayıran bir örüntü yok.
  - Muhtemel açıklama: ısıtıcı geldiği anda eğim yakınsamış mı, yakınsamamış mı (sınırda bir durum). Şekilde T5/100'de b ısıtıcıdan önce 1'e yakın görünüyor, ama değer yazdırılmadı. **Doğrulanmadı.**
- **T7 neden kilitlenmiyor:** Isıtıcıdan önce 1 saat rampa var. Arızadan önceki ısıtıcı dışı alarm 20 tohumun hepsinde **0**. Arızadan sonraki 210 alarm (her tohumda aynı, ısıtıcısız da 210) doğru tespit, K3b'den haklı olarak çıkarılıyor.

**Bulgu 14C: T8'deki alarmlar ayrı bir mekanizma: model yapısı uyuşmazlığı. Isıtıcıyla ilgisi yok.**
- Son güncellemeyle ilk alarm arasında ısıtıcı yok. Isıtıcısız tekrarda da 40 alarm var (ısıtıcıyla toplam 60).
- Kapı 1,39 saatte, sinüsün iniş yamacında zT yavaşça −3'e kayınca kapanıyor. Hata −0,06'dan −0,13 °C'ye büyüyor, sT 0,020'de kalıyor.
- Kapısız modelde de ısıtıcı dışı 24–28 alarm var; kapı bunu ~40'a büyütüyor.
- **Muhtemel neden (doğrulanmadı):** Simülatörde BME, ortamı 200 s'lik tek bir gecikmeyle izliyor. Dedektörün modeli ise ICM'nin 120 s gecikmesine bir gecikme daha ekliyor (seri iki birinci derece sistem, tek bir birinci derece sistem gibi davranmaz). Hızlı sinüste (25 ± 8 °C, 3 saat periyot, ~17 °C/saate kadar) bu fark 0,02 °C'lik bütçeyi aşıyor.

**Bulgu 14D: Kapıyı kaldırmak çözüm değil.**
- Kapısız model T2'deki kilidi azaltıyor (~180 → 51–55).
- Ama bugün 0 olan senaryolarda alarm üretiyor: T3 132–143, T5 153–155, T7 64–103, T1 46–55, T9 27–39. Isıtıcının kuyruğunu modele öğreniyor ve sonra yanılıyor (ör. T2'de kapısız b ~1,13'e sıçrıyor).
- Yani kapı hem koruyor hem kilitliyor. Kanallarda 7C ve 10F'de gördüğümüz ikilemin sıcaklık kanalındaki hâli.

**Sonuç ve v6 için anlamı (henüz uygulanmadı):** 13D'nin kaynağı üç parçalı: dondurulmuş bir RLS, model hatası payı olmayan bir hata bütçesi ve yeterli uyarım olmadan güvenilen bir eğim. Kanallar için bulunan çözümlerin karşılıkları bu kanala uygulanmalı:
1. sT'ye bir model hatası payı eklemek.
2. Donmuşken (a, b) kovaryansını büyütmek, böylece serbest kalmanın bir yolu olur (10C/B).
3. Eğim ve gecikme yeterli termal uyarımla belirlenmeden modele güvenmemek (6F).
4. T8 ayrı bir iş: model yapısı (iki gecikme) ya da hızlı değişimde sT'yi genişletmek.

Bu parametrelerin hepsi v6'nın yeni ayrılmış kümesi ilan edilmeden önce sabitlenmeli (§11 protokolü).

---

## Açık konular

- [x] ~~Termal katsayıları ICM-42688-P veri sayfasından teyit etmek~~ → Bulgu 4
- [x] ~~Değerleri veri sayfası Rev 1.6 ile karşılaştırmak~~ → Tablo 1, 2, 4 aynı
- [ ] Veri sayfası tablolarını PDF üzerinden bir kez gözle kontrol etmek
- [ ] Sıcaklık sensörü modeline birim bazında ofset (±5 °C) ve kazanç hatası eklemek (Bulgu 4E)
- [ ] Bias instability ve rate random walk değerlerini gerçek statik logdan çıkarmak (`assumed` → `allan_fit`, [§14.2/2](mihenk.md)); veri sayfası bunları vermiyor (Bulgu 4B)
- [ ] Termal katsayıların birim bazında ±sınır içinden örneklenmesi (Bulgu 4A)
- [ ] Manyetometre (MMC5983MA / LIS2MDL) ve BME688 veri sayfalarını da aynı şekilde teyit etmek
- [ ] `first_allan_check.m`'e sabit tohum eklemek
- [x] ~~Sensör başına ayrı sıcaklık ve dış termal model (gradyan, histerezis, öz-ısınma, gecikme)~~ → Bulgu 5
- [ ] Termal model parametrelerini (τ, gradyan, R_th, histerezis) termal salınım kaydından ölçmek (`assumed` → ölçüm)
- [ ] Sıcaklık sensörü kazanç hatasını modele eklemek (şu an yalnız ofset ve kuantizasyon var)
- [x] ~~Termal modeli ivmeölçer ve manyetometre bias'larına da bağlamak~~ → `simulate_node.m` (§6)
- [x] ~~G1 v1'i birden çok tohum ve senaryoyla değerlendirmek~~ → Bulgu 8
- [x] ~~**G1 v3:** Allan parametrelerine dayanan, gürültüyü bilen bir sıfır modeli (random walk bias durumu olan Kalman filtresi) ve kilitlenmeye karşı serbest bırakma kuralı (Bulgu 8B, 7C)~~ → Bulgu 9 (serbest bırakma yalnızca kısmen çalışıyor: 9H, 9I)
- [x] ~~Faktöriyel değerlendirme: her tuzak için beyaz ve renkli gürültü (Bulgu 8F)~~ → Bulgu 9
- [ ] EMI için G1 dışı kaldıraçlar: `‖m‖` sabitliği ve üç yönlü oylama (Bulgu 8D)
- [x] ~~Model-uyuşmazlığı testi: simülatörde play operatöründen farklı bir histerezis biçimi (Bulgu 7D, ADR-012)~~ → Bulgu 9H: v1 ve v3 beyaz gürültüde başarısız
- [x] ~~**G1 v4:** ortak mod kuralı farklı fiziksel sensörler gerektirsin (9E); sıcaklık kaynağı beraberliğinde belirsiz durum (9F); model hatası için süreç gürültüsü tabanı (9H); dondurulmuş kanalda sıcaklığa bağlı hata (9I)~~ → Bulgu 10 (taban bu biçimiyle reddedildi, 10C)
- [x] ~~Değerlendirme: tuzak ölçütlerine olay sonrası penceresi; yanlış alarmı medyan ve en kötü tohumla raporlamak; tohum sayısını artırmak (9B, 9E)~~ → Bulgu 10
- [x] ~~Renkli gürültüde ısıtıcı sırasında my suçlamasının nedenini bulmak (9B)~~ → Bulgu 10A (muhtemelen beraberlikte ICM'nin suçlanması)
- [x] ~~Blok düzeyinde doğrulama: EMI sırasında `R.common`, BME arızasında `blameIcm` oranı~~ → Bulgu 10A, iki mekanizma da doğrulandı
- [ ] **G1 v5:** CUSUM üst sınırı (10B); model hatası tabanı yalnızca dondurulmuş kanallarda (10C); ısıtıcı sırasında BME suçlama ve belirsizlik ölçütü (10D). Kod hazır, duman testi geçti, tam değerlendirme koşulmadı.
- [x] ~~Tanı: beyaz tohum 4 ve 9, renkli tohum 8'de gx'in baştan kilitlenmesi (10E)~~ → Bulgu 10F
- [x] ~~v5'e C (büyümeye bakan serbest bırakma; W = 30 blok, tek yönlü α = 0,01, sonuçlardan önce ilan edildi) ve D (model seçimi değişince CUSUM sıfırlama) eklemek (10F)~~ → `g1_detect_v5.m`
- [ ] İlişkili artıklar (10F tetiği): ikinci Gauss-Markov terimi ya da beyazlatma; v5'te yalnızca tanı olarak ölçülüyor (`innovAC1max`)
- [ ] Beyaz tohum 9'da (v3, v4nf) mz'nin 1,39 saatte kilitlenmesinin tetiğini bulmak (10F)
- [x] ~~G1 simülasyon aşamasının kabul ölçütlerini sonuçları görmeden yazmak~~ → §11
- [x] ~~v5 geliştirme koşusu → §11'deki kurala göre aday seçimi~~ → §12, aday v5
- [x] ~~Ayrılmış test (`g1_acceptance_test.m`, tek atış)~~ → §13, FAIL
- [x] ~~Tanı: sıcaklık kaynağı modelinin T2, T5 ve T8'de kilitlenmesi (13D)~~ → Bulgu 14 (T2/T5: ısıtıcı + yanlış eğim + payı olmayan sT; T8: model yapısı)
- [ ] **G1 v6, sıcaklık kaynağı modeli:** sT'ye model hatası payı, donmuşken (a, b) kovaryansının büyümesi, uyarım olmadan eğime güvenmemek; T8 için iki gecikmeli model ya da hıza bağlı sT (14B–14D)
- [ ] T5'te yalnız tohum 108 ve 118'in kilitlenme nedenini doğrulamak (ısıtıcı anında b yakınsamış mı? 14B)
- [ ] Yeni sürüm için **yeni** bir ayrılmış küme (tohum 200+, yeni senaryolar); §13'teki küme artık görülmüş sayılıyor
- [ ] Basamak arızasında doğru davranış: kalıcı ofset "arıza" mı, "yeni normal" mi? Formel tanıma yazmak (12B)
- [ ] Artık öz-ilişkisini "model güvenilmez" durumu için kullanmayı değerlendirmek (12E, ADR-010)
- [ ] Bellek bütçesi: v4'te 90 Kalman filtresi × 14 sayı ≈ 5 KB (float) veya ~2,5 KB (16 bit), ATmega328P'nin 2 KB'ını aşıyor; sadeleştirme gerekiyor (örneğin genişlik ızgarası)
- [ ] "En küçük algılanabilir kayma hızı"nı K ve izin verilen gecikme cinsinden formel tanıma yazmak (9D)
- [ ] G1 skorunu kalibre edilmiş bir güven skoruna çevirmek (ECE, reliability diagram; ADR-010)
- [ ] "Model yapısı uyumsuzluğu" (Bulgu 7C) ve "termal uyarım yetersizliği" (Bulgu 6F) koşullarını teşhis kestiricisinin formel tanımına yazmak ([§14.2/4](mihenk.md))
- [ ] Çapraz doğrulama toleransını, karşılaştırmaya başlamadan **önce** yazılı olarak ilan etmek ([§14.2/7](mihenk.md))

---

## Kaynaklar

Metinde [R#] olarak anılıyor. ISA-18.2 ve EEMUA 191 standartlarının [R7] metnine erişilmedi; sayıları ikincil kaynaklardan [R8]–[R9] alındı. Bu durum ilgili satırda da belirtildi.

**Sensör ve gürültü modeli**
- **[R1]** TDK InvenSense, *ICM-42688-P Datasheet*, DS-000347, Rev 1.6, 2021. Repoda: [`docs/ds-000347-icm-42688-p-v1.6.pdf`](docs/ds-000347-icm-42688-p-v1.6.pdf). → §4, Rev 1.5 karşılaştırması dahil
- **[R2]** IEEE Std 952-1997, *IEEE Standard Specification Format Guide and Test Procedure for Single-Axis Interferometric Fiber Optic Gyros*, Ek C (Allan varyansı ve gürültü terimleri N, B, K). → §1, §2
- **[R3]** N. J. Kasdin, "Discrete simulation of colored noise and stochastic processes and 1/f^α power law noise generation", *Proceedings of the IEEE*, 83(5), 802–827, 1995. MATLAB `fractalcoef` filtresinin dayanağı. → §2, §8
- **[R4]** MathWorks, *imuSensor* ve *fractalcoef* dokümantasyonu, MATLAB R2026a (Navigation / Sensor Fusion and Tracking Toolbox). → §1–§3

**Karar istatistiği**
- **[R5]** E. S. Page, "Continuous inspection schemes", *Biometrika*, 41(1/2), 100–115, 1954. CUSUM'ın ilk tanımı. → §7, §9 (işaretli CUSUM)
- **[R6]** NIST/SEMATECH, *e-Handbook of Statistical Methods*, "Cusum Average Run Length". <https://www.itl.nist.gov/div898/handbook/pmc/section3/pmc3131.htm> → §9 (ARL0), §11

**Alarm yükü ve bütünlük standartları** (§11 ölçütlerinin gerekçesi)
- **[R7]** ANSI/ISA-18.2, *Management of Alarm Systems for the Process Industries*, ve EEMUA Publication 191, *Alarm Systems – A Guide to Design, Management and Procurement*. Standartların metni okunmadı; sayılar [R8]–[R9]'dan alındı.
- **[R8]** Emerson Process Management, "Alarm Management by the Numbers". <https://www.emerson.com/documents/automation/alarm-management-by-numbers-en-38292.pdf> → operatör başına ≤ 6 alarm/saat "çok büyük olasılıkla kabul edilebilir", ≤ 12 "yönetilebilir üst sınır"
- **[R9]** *Chemical Engineering*, "Alarm Management By the Numbers". <https://www.chemengonline.com/alarm-management-numbers/> → [R8] ile aynı sınırlar
- **[R10]** ESA Navipedia, "RAIM Algorithms". <https://gssc.esa.int/navipedia/index.php/RAIM_Algorithms> → FDE yanlış uyarı ≤ 10⁻⁵/saat
- **[R11]** ESA Navipedia, "Integrity". <https://gssc.esa.int/navipedia/index.php/Integrity> → uyarı süresi (time-to-alert), bütünlük riski tanımları
- **[R12]** Wikipedia, "Receiver autonomous integrity monitoring". <https://en.wikipedia.org/wiki/Receiver_autonomous_integrity_monitoring> → genel tanım; birincil kaynak değil

**IMU arıza tespiti literatürü** (ölçüt türleri ve büyüklük mertebeleri)
- **[R13]** "A Particle Filtering Approach for Fault Detection and Isolation of UAV IMU Sensors: Design, Implementation and Sensitivity Analysis", *Sensors*, 2021. <https://pmc.ncbi.nlm.nih.gov/articles/PMC8124649/> → başarım ölçütleri: tespit gecikmesi, yanlış alarm oranı, kaçırılan tespit oranı
- **[R14]** "Fast Fault Detection on a Quadrotor using Onboard Sensors and a Kalman Filter Approach", arXiv:2102.06439. <https://arxiv.org/pdf/2102.06439> → ani arızalarda milisaniye mertebesinde gecikme; yavaş termal kaymayla doğrudan karşılaştırılamaz
