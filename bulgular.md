# MIHENK — Bulgular

Bu dosyada her test/kontrol scripti için şunlar kayıtlıdır: **nerede olduğu, neyi nasıl test ettiği, neden var olduğu ve ne bulduğu.** Her yeni script koşulup yorumlandığında buraya bir girdi eklenir.

**Ortam:** MATLAB R2026a (Windows 11) · Sensor Fusion and Tracking Toolbox + Navigation Toolbox (`imuSensor` ve `allanvar` ortak `shared/positioning` altında).
**Kabul toleransı:** ±%10 (M1 faz çıkış kriteri, [`mihenk.md` §10.4](mihenk.md)).
**Parametre kaynakları:** Her değerin kaynağı script içinde belirtilir: `datasheet` veya `assumed`.
**Figürler:** [`figures/`](figures/) klasöründe. İlke için bkz. [`mihenk.md` §S2.5](mihenk.md).

---

## Özet

| # | Script | Test edilen | Sonuç |
|---|---|---|---|
| 1 | [`first_allan_check.m`](matlab/reference-model/first_allan_check.m) | Beyaz gürültü yoğunluğu (N) | ✅ −%0,04 (düzeltme sonrası) |
| 2 | [`allan_noise_terms_check.m`](matlab/reference-model/allan_noise_terms_check.m) | Rate random walk (K), bias instability (B) | ✅ K, ✅ B (1/f filtresiyle) · ❌ B (varsayılan filtre) |
| 3 | [`thermal_model_check.m`](matlab/reference-model/thermal_model_check.m) | Sıcaklık bias'ı ve ölçek faktörü, sıcaklık değişimi altında gürültü sürekliliği | ✅ Formül tam (hata 0) · ✅ N, K |
| 4 | — (veri sayfası teyidi) | ICM-42688-P parametreleri, DS-000347 Rev 1.6 | Termal katsayılar ve gyro N teyit edildi · B ve K veri sayfasında yok · sıcaklık sensörü ofseti ±5 °C |

**Kritik kurallar** (MATLAB referans modelinde her zaman uygulanacak):

1. `NoiseType` her zaman `'single-sided'` olarak verilir. Varsayılan `'double-sided'` N'yi √2 küçük, K'yı √2 büyük üretir ve bunu sessizce yapar. → Bulgu 1, 2A
2. Bias instability için `BiasInstabilityCoefficients` her zaman `fractalcoef(K, 1)` olarak verilir. Varsayılan filtre 1/f gürültüsü üretmez. → Bulgu 2B
3. `imuSensor`'ın termal modeli G1 için tek başına **yetersizdir**. Gradyan, histerezis ve öz-ısınma modelin dışında kurulmalıdır. → Bulgu 3

---

## 1. Beyaz gürültü yoğunluğu (N)

**Script:** [`matlab/reference-model/first_allan_check.m`](matlab/reference-model/first_allan_check.m)
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

**Script:** [`matlab/reference-model/allan_noise_terms_check.m`](matlab/reference-model/allan_noise_terms_check.m)
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

**Script:** [`matlab/reference-model/thermal_model_check.m`](matlab/reference-model/thermal_model_check.m)
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
- Figür ([`figures/thermal_figure_2.png`](figures/thermal_figure_2.png)): τ ≈ 40 s'ye kadar iki eğri üst üste. Sonra ham eğri yukarı ayrılıyor; τ ≈ 1000 s'de aradaki fark yaklaşık 2 kat. Öngörüyle uyumlu.
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

## Açık konular

- [x] ~~Termal katsayıları ICM-42688-P veri sayfasından teyit etmek~~ → Bulgu 4
- [x] ~~Değerleri veri sayfası Rev 1.6 ile karşılaştırmak~~ → Tablo 1, 2, 4 aynı
- [ ] Veri sayfası tablolarını PDF üzerinden bir kez gözle kontrol etmek
- [ ] Sıcaklık sensörü modeline birim bazında ofset (±5 °C) ve kazanç hatası eklemek (Bulgu 4E)
- [ ] Bias instability ve rate random walk değerlerini gerçek statik logdan çıkarmak (`assumed` → `allan_fit`, [§14.2/2](mihenk.md)); veri sayfası bunları vermiyor (Bulgu 4B)
- [ ] Termal katsayıların birim bazında ±sınır içinden örneklenmesi (Bulgu 4A)
- [ ] Manyetometre (MMC5983MA / LIS2MDL) ve BME688 veri sayfalarını da aynı şekilde teyit etmek
- [ ] `first_allan_check.m`'e sabit tohum eklemek
- [ ] Sensör başına ayrı sıcaklık ve dış termal model (gradyan, histerezis, öz-ısınma, gecikme) — Bulgu 3D
- [ ] Çapraz doğrulama toleransını, karşılaştırmaya başlamadan **önce** yazılı olarak ilan etmek ([§14.2/7](mihenk.md))
