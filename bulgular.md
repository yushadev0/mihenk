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
| 6 | [`g1_prototype_v0.m`](matlab/g1/g1_prototype_v0.m) | G1 ilk prototip: ortak mod / kanala özgü ayrıştırma | ✅ ısıtıcı tuzağı çözüldü · ⚠️ histerezis, gecikme ve pencere uyumu zayıflıkları |

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

**Amaç:** Beyaz gürültü dışındaki iki stokastik terimin IEEE Std 952 tanımlarına uyup uymadığını görmek. Bu, olmazsa olmaz #4 ile ilgili ("Allan-tutarlı gürültü sentezi, 1/f dahil"). Bu doğrulama yapılmazsa [§11](mihenk.md)'deki "sentetik gürültünün kolaylığı" riski gerçekleşir: yöntem beyaz gürültüde çalışır, gerçek 1/f gürültüsünde çöker.

**Ne test ediyor:** Her terim **tek başına** simüle ediliyor ve Allan eğrisinin hem büyüklüğü hem eğimi kontrol ediliyor.

| Terim | IEEE beklentisi | Beklenen eğim |
|---|---|---|
| Rate random walk K | `σ(τ) = K·√(τ/3)` | +½ |
| Bias instability B | Düz taban, `0,664·B` (`√(2 ln2/π)·B`) | 0 |

**Nasıl:**
- Değerler yer tutucu (`assumed`): K = 20 °/h/√h, B = 5 °/h. Her terim tek başına koşulduğu için yalnızca ölçülen/beklenen oranı önemli.
- A durumu: 100 Hz, 2 saat, `single-sided` ve `double-sided` ayarları yan yana. K, `σ·√(3/τ)` değerinin medyanından kestiriliyor.
- B durumu: varsayılan `BiasInstabilityCoefficients` ile. Taban değeri τ ∈ [1 s, T/10] aralığındaki medyan Allan değeri.
- C durumu: `fractalcoef(2000, 1)` ile (Kasdin 1/f filtresi, 2000 kutup). Maliyeti düşük tutmak için 10 Hz ve 4 saat. Taban değeri τ ∈ [1, 100] s aralığından.
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
**Kaynak:** TDK InvenSense, *ICM-42688-P Datasheet*, DS-000347, **Rev 1.6 (06/20/2021)**. Dosya repoda: [`docs/ds-000347-icm-42688-p-v1.6.pdf`](docs/ds-000347-icm-42688-p-v1.6.pdf). Değerler Tablo 1 (gyro, s. 11), Tablo 2 (ivmeölçer, s. 12), Tablo 4 (sıcaklık sensörü, s. 14) ve §4.13'ten alındı.

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

**Script:** [`matlab/g1/g1_prototype_v0.m`](matlab/g1/g1_prototype_v0.m)
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
- [ ] Termal modeli ivmeölçer ve manyetometre bias'larına da bağlamak (şu an yalnızca gyro x)
- [ ] Çapraz doğrulama toleransını, karşılaştırmaya başlamadan **önce** yazılı olarak ilan etmek ([§14.2/7](mihenk.md))
