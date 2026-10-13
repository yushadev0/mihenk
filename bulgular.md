# MIHENK — Bulgular

Bu dosyada her test/kontrol scripti için şunlar kayıtlıdır: **nerede olduğu, neyi nasıl test ettiği, neden var olduğu ve ne bulduğu.** Her yeni script koşulup yorumlandığında buraya bir girdi eklenir.

**Ortam:** MATLAB R2026a (Windows 11) · Sensor Fusion and Tracking Toolbox + Navigation Toolbox (`imuSensor` ve `allanvar` ortak `shared/positioning` altında).
**Kabul toleransı:** ±%10 (M1 faz çıkış kriteri, [`mihenk.md` §10.4](mihenk.md)).
**Parametre kaynakları:** Her değerin kaynağı script içinde belirtilir: `datasheet` veya `assumed`. İlke için bkz. [`mihenk.md` §S2.5](mihenk.md).
**Klasör düzeni:** [`matlab/README.md`](matlab/README.md). Modeller `matlab/models/`, kontrol scriptleri `matlab/checks/`, G1 prototipleri `matlab/g1/`, figürler [`matlab/figures/`](matlab/figures/) altında. Klasör düzeni §6'dan sonra kuruldu; önceki girdilerdeki commit'ler dosyaları eski yerleriyle (`matlab/reference-model/`, `figures/`) gösterir.
**G1 Oynatıcı (yayında):** [yusa.app/mihenk/replay](https://yusa.app/mihenk/replay/) · proje sayfası [yusa.app/mihenk](https://yusa.app/mihenk/). Kaynak ve yayın betiği: [`viewer/`](viewer/README.md).

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
| 15 | [`g1_dev_tsrc_v6.m`](matlab/g1/v6/g1_dev_tsrc_v6.m) | v6 sıcaklık kaynağı modeli: lead-lag, ızgara payı, donmuşken büyüme ve ablasyonları; geliştirme + kullanılmış küme | ✅ v5 kopyası 280/280 birebir · ✅ lead-lag (L) bütün kilitleri kaldırıyor (T2 179 → 0, T8 40 → 0, T5 12,7 → 0) · aday L · ⚠ yapı simülatörle aynı (ADR-012) · ❌ donmuşken büyüme ısıtıcıyı ve kaymayı yutuyor |
| 16 | [`g1_prototype_v6.m`](matlab/g1/v6/g1_prototype_v6.m) | v6 (A: lead-lag T kaynağı, B: olay sonu bırakma, C1: ofset olayı, C2: model güvenilmez) ve ablasyonları; geliştirme + kullanılmış küme | ✅ eşdeğerlik 0 · ✅ T src dışı alarm 13 → 0, EMI sonrası %25 → %0, basamak kapsaması %11–76 → %99 · aday v6 · ❌ K1b: histerezis uyuşmazlığı (T9 beyaz 52/saat) · ⚠ C1 uyuşmazlıkta kaymayı ofset sanıyor · ⚠ C2 etkisiz |
| 17 | [`g1_diag_v6_side.m`](matlab/g1/v6/g1_diag_v6_side.m) | Tanı: v6 yan etkileri (16E), referans maskesi ve model izi | ❌ H1/H3 reddedildi · mz: eşiğe yakın yanlılık, 10 tohumun 2sinde · ✅ erken bırakma sistematik (10/10): donmuş kanalda model hatası (T − T0)² ile ölçekleniyor, 15C ile aynı hata |
| 18 | [`g1_prototype_v7.m`](matlab/g1/v7/g1_prototype_v7.m) | v7 (D1: donma anına göre model hatası, D2: büyük ve büyümeyen sapma = ofset) ve ablasyonları | ✅ eşdeğerlik 0, v6 regresyonu 4·10⁻¹⁵ · ✅ D1 basamağın erken bırakılmasını çözüyor · ❌ D1 histerezis uyuşmazlığını açığa çıkarıyor (T9 beyaz 52 → 127/saat) · ❌ D2 yavaş kaymaları ofset sanıyor · kurala göre aday v7, ama v6 genel olarak daha iyi; kuralda önceki sürüm karşılaştırması yoktu |
| 19 | [`g1_prototype_v8.m`](matlab/g1/v8/g1_prototype_v8.m) | v8 (v6 + D1 + R: gevşeme histerezisi adayları) ve ablasyonları, v6'ya karşı iki adımlı kural | ✅ eşdeğerlik 0, iki regresyon 4·10⁻¹⁵ · ✅ R histerezis alarmlarını kaldırıyor (beyaz en kötü 51,6 → 3,8/saat) · ❌ renkli kapsama %79,7 → %78,0 (tolerans 1 puan) → kurala göre G1 = v6 · ⚠ kayıp çoğunlukla D1'den, two-faults'ta sistematik · ⚠ renkli gürültüde biçim seçimi şaşıyor |
| 19 (tanı) | [`g1_diag_v8.m`](matlab/g1/v8/g1_diag_v8.m) | Kapsama kaybının mekanizması; ızgara dışı histerezis parametreleri ve taze tohumlarla genelleme | ❌ H1 two-faults'ta reddedildi: kayıp C2'den ("güvenilmez" arızalı blokların %57'si) · ✅ day-cycle ve T9 / renklide H1 doğrulandı (D1 + büyüme testi rampada ofset sanıyor) · ✅ R ızgara dışına genelleniyor (τ = 600: en kötü 78 → 3,3/saat), tohumlara uyum yok · ❌ D1, τ = 600'de K1b'yi aşıyor |
| 20 | [`g1_prototype_v9.m`](matlab/g1/v9/g1_prototype_v9.m) | v9 (v8 − C2 + E: ofset olayı için eşdeğerlik testi) ve ablasyonları, v6'ya karşı iki adımlı kural | ✅ eşdeğerlik 0, iki regresyon 4·10⁻¹⁵ · ✅ C2'siz two-faults %55 → %98 · ✅ E rampada ofset sanmayı çözüyor · ❌ E bazı yanlış alarmları bırakamıyor (en kötü 53,5 beyaz, 32,7 renkli) → kurala göre G1 = v6 · ⚠ v9noE (= v8 − C2) iki eşiği de geçiyor ama 1. adım onu seçemiyor (kural açığı) |
| 20 (tanı) | [`g1_diag_v9.m`](matlab/g1/v9/g1_diag_v9.m) | E'nin bırakamadığı yanlış alarmlar ve T10'daki ofset olayları | ✅ iz davranışı değiştirmiyor, oranlar CSV ile aynı · H2 dört koşunun üçünde (kural gereği kabul edilmedi), H3 hiçbirinde · ⚠ geliştirmedeki iki koşu 10F'nin baştan kilitlenen kanalları: E, büyüme testinin güvenlik kapısını kapatıyor · ❌ T10: renkli gürültüde 30 blokluk pencerede se iyimser → öneri v10 = v9noE |
| 21 | [`g1_acceptance_test2.m`](matlab/g1/test2/g1_acceptance_test2.m) | v10 (= v9noE) ve v6, ikinci ayrılmış küme: 100 tohumdan otomatik üretilmiş senaryo × 2 gürültü, PI histerezisi, ikinci derece BME yolu (önceden ilan) | Küme, ölçütler (K1–K4) ve iki karar kuralı sonuçlardan önce commit'lendi · ✅ **G1 = v10** (87 iyi / 12 kötü hücre; beyaz en kötü 161,4 → 31,6, kapsama %78,6 → %97,6) · ✅ K2a–K2d, K3c–K3f, K4 geçti · ❌ **kabul FAIL**: K1b (31,6 / 12,8), K1c beyaz, K3a beyaz (sınırda), K3b (ortak sıcaklık kaynağı modeli, 19,1) |
| 22 | [`g1_diag_tsrc2.m`](matlab/g1/v10/g1_diag_tsrc2.m) | Tanı: ikinci kabul testindeki olay dışı "T src" alarmları (21C); ısıtıcısız ve birinci derece BME yolu karşı-olgusalları | ✅ kopya 100/100 birebir · ✅ H1 (ısıtıcı) K3b'nin ~%73'ü: ısıtıcı penceresinde tek bir "geri giriş" güncellemesi modeli bozuyor · ✅ H2 (ikinci derece yol, τ2 ≥ 359 s) ~%24: model hatası payı olmayan sT yine kilitliyor · H3 iki koşu: biri puanlama sınır bloğu |
| 23 | [`g1_dev_tsrc_v11.m`](matlab/g1/v11/g1_dev_tsrc_v11.m) | Sıcaklık kaynağı modeli: geri giriş beklemesi (H) ve geniş gecikme ızgarası (W), dev + iki kullanılmış küme | Varyantlar ve seçim kuralı sonuçtan önce commit'lendi · ✅ kontroller 100/100, 280/280 · ✅ HW spent2'de K3b'yi 19,4 → 0,84'e indiriyor · ❌ kurala göre v6 kalıyor: ısıtıcı payı 0,873 → 0,851 · ⚠ düşüşün tamamı v6'nın kilitlendiği 11 koşudan, kısmen ters işaretli kilit alarmları (sonuç sonrası) |
| 23b | [`g1_dev_tsrc_v11b.m`](matlab/g1/v11/g1_dev_tsrc_v11b.m) | §23'ün yeniden koşusu, tek değişiklik: işaretli ısıtıcı ölçütü (zT > 0), sonuç sonrası karar | ✅ C1–C3 birebir (1520/1520) · ✅ **sıcaklık kaynağı modeli HW**: spent2 K3b 19,4 → 0,84, ısıtıcı payı 0,822 → 0,824 · ⚠ karar ölçüt değişikliğiyle döndü (sonuç sonrası) · ⚠ işaretli ölçüt BME arızasıyla çakışan ısıtıcı penceresinde arıza alarmlarını saymıyor |

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

## 15. G1 v6: sıcaklık kaynağı modeli, geliştirme koşusu

**Script:** [`matlab/g1/v6/g1_dev_tsrc_v6.m`](matlab/g1/v6/g1_dev_tsrc_v6.m) · **Model:** [`g1_tsrc_v6.m`](matlab/g1/v6/g1_tsrc_v6.m) · **Çıktı:** [`g1_dev_tsrc_v6_output.txt`](matlab/g1/v6/g1_dev_tsrc_v6_output.txt) · **Ham sonuçlar:** [`g1_dev_tsrc_v6_results.csv`](matlab/g1/v6/g1_dev_tsrc_v6_results.csv) · **Figür:** [`g1_dev_tsrc_v6.png`](matlab/figures/g1_dev_tsrc_v6.png)

Kullanıcı koştu. Model, varyantlar, kontroller ve seçim kuralı sonuçlardan önce commit edildi (60dccc3).

**Ne yapıldı:** §14'teki teşhise göre sıcaklık kaynağı modelinde üç değişiklik yapıldı. Her biri ayrı bir anahtar, böylece her biri tek tek ablasyonla ölçülebiliyor:
1. **Lead-lag yapısı (L).**
   - İki kalıp da ortamı birinci derece bir gecikmeyle izliyor (τ_I ve τ_B). Ortamı denklemden çıkarınca tam ilişki `T_bme = L + τ_I·dL/dt + sabit` oluyor; burada `L = lag(T_icm, τ_B)`.
   - Türev üçüncü bir regresör olarak eklendi. Model parametrelerde doğrusal kalıyor; ızgarada yalnız τ_B aranıyor, τ_I katsayı olarak öğreniliyor.
   - v5 bunun τ_I = 0 olan özel hâli.
2. **Izgara hata payı (G).**
   - Gecikme 20 s'lik ızgaradan seçiliyor. Bu yüzden varyansa `Δτ²/12 · (dL/dt)²` ekleniyor.
   - Değer ayarlanmadı, ızgara adımından geliyor.
3. **Donmuşken kovaryans büyümesi (F).**
   - Kanallardaki B düzeltmesinin karşılığı.
   - Sonuçlardan önce aday dışı bırakıldı, yalnızca ablasyon olarak koşuldu. Gerekçesi: kalıcı bir BME ofsetini "eğim değişti" diye yutacağı öngörülüyordu (12B ikilemi).

**Varyantlar ve veri:**
- **Varyantlar:** v5, L, G, LG (önceden ilan edilen aday) ve LGF.
- **Geliştirme kümesi:** g1_scenarios_v3, 8 senaryo × tohum 0–9.
- **Kullanılmış test kümesi:** 10 senaryo × tohum 100–119. §13'te görüldüğü için artık geliştirme verisi.
- Model yalnızca sıcaklıkları okuyor, bu yüzden yalnız beyaz gürültü koşuldu.

**Kontroller:**
- **C1:** v5 varyantı, kabul testi CSV'siyle 200/200 koşuda birebir aynı.
- **C2:** v5 varyantı, v5 geliştirme CSV'siyle 80/80 koşuda birebir aynı.

Yani "v5" sütunu gerçekten v5.

| Senaryo (seçme) | v5 | L | G | LG | LGF |
|---|---|---|---|---|---|
| T2 olay dışı alarm, ortalama [en kötü] | 179,2 [194] | **0 [0]** | 7,8 [155] | 0 [0] | 0 [0] |
| T5 | 12,7 [127] | **0 [0]** | 0 [0] | 0 [0] | 0 [0] |
| T8 | 40,0 [44] | **0 [0]** | 0 [0] | 0 [0] | 0 [0] |
| Diğer 15 senaryo | ≤ 0,5 [1] | 0 [0] | ≤ 0,5 [1] | 0 [0] | 0 [0] |
| Isıtıcı penceresinde alarm payı (aralık) | 0,91–1,00 | 0,91–0,96 | 0,86–0,98 | 0,86–0,96 | 0,68–0,95 |
| BME kayması (geliştirme): kapsama / gecikme medyanı | 0,92 / 14,5 dk | 0,93 / 13,5 dk | 0,91 / 16,5 dk | 0,92 / 15,5 dk | 0,66 / 62,5 dk |
| T7 BME basamağı: kapsama / gecikme | 1,00 / 0,5 dk | 1,00 / 0,5 dk | 1,00 / 0,5 dk | 1,00 / 0,5 dk | 1,00 / 0,5 dk |

**Bulgu 15A: Kilitleri tek başına lead-lag yapısı çözüyor. Seçim kuralına göre aday LG değil, L.**
- L, 18 senaryonun 280 koşusunun hiçbirinde ısıtıcı dışında alarm vermiyor. T2'de 179'dan 0'a, T8'de 40'tan 0'a, T5'te 12,7'den 0'a iniyor.
- Isıtıcı ve BME arızası yakalanmaya devam ediyor.
- LG de olay dışı alarm vermiyor, ama ızgara payı sT'yi genişlettiği için ısıtıcıyı daha az yakalıyor (ör. T2'de 0,86, L'de 0,91). BME kaymasında da L'den 2 dk geç.
- L hiçbir ölçütte LG'den kötü değil ve birkaçında daha iyi. İlan edilmiş kurala göre aday **L**. Izgara payı, yapı doğru kurulunca gereksiz kalıyor.
- §14B'deki "yanlış eğim" de yapı kaynaklıymış: L ve LG'de koşu sonunda öğrenilen eğim her senaryoda b = 1,000 (v5'te kilit anında 0,984–0,986).
- **Uyarı (ADR-012, döngüsellik):** Simülatör tam olarak bu fiziği kullanıyor (iki birinci derece gecikme). Yani simüle veride L'nin yapısı kusursuz uyuyor; bu sonuç büyük ölçüde bundan geliyor. Gerçek bir kartta termal yollar birinci derece olmayacak. L'nin değeri, yapısı farklı bir termal modelde ölçülmeden bilinemez. **Yeni ayrılmış kümede BME için farklı bir termal yapı olmalı** (ör. iki düğümlü / ikinci derece bir yol, ya da sensörlerin farklı ortam gördüğü hava akımı).

**Bulgu 15B: Yalnız ızgara payı (G) kilitleri kısmen çözüyor, ama güvenilir değil.**
- T5 ve T8 sıfırlanıyor.
- T2'de 20 tohumun 19'unda kilit kalkıyor, tohum 100'de ise 155 blokluk kilit sürüyor.
- Yani yanlış yapının bedelini genişletilmiş bir hata bütçesi yalnızca çoğu zaman karşılıyor.

**Bulgu 15C: F (donmuşken büyüme) ısıtıcıyı ve kaymayı yutuyor. T7 basamağı için yaptığım öngörü ise yanlıştı.**
- LGF'de ısıtıcı penceresinde alarm payı 0,68'e düşüyor. Şekilde ısıtıcı zirvesi v5'te grafiğin dışına çıkarken LGF'de ~17'de kalıyor: model dondukça sT büyüyor ve ısıtıcının kendisini kısmen "açıklıyor".
- Geliştirmedeki BME kaymasında kapsama 0,92'den 0,66'ya düşüyor, gecikme 15'ten 62 dakikaya çıkıyor.
- **Öngörü hatası:** T7'deki 1 °C'lik basamağın ~1 saatte yutulacağını öngörmüştüm. Gerçekleşmedi, kapsama 1,00 kaldı. Şekilde zT 4,5–6 saat arasında ~+7'de duruyor, iniş rampası bitince büyüyor.
- **Muhtemel neden (doğrulanmadı):** Eğim belirsizliğinin sT'ye katkısı `(L − L0)²` ile ölçekleniyor. L0 koşunun ilk bloğundaki sıcaklık. İniş rampasında sıcaklık başlangıca döndükçe bu katkı küçülüyor. Yani F'nin etkisi sıcaklığın başlangıca uzaklığına bağlı; bu, merkezlemenin bir yan etkisi, tasarlanmış bir davranış değil.
- Sonuç yine de aynı: F aday değil. Aday dışı bırakma kararı doğruydu, ama gerekçesi (T7) yanlıştı.

**Bulgu 15D: Öğrenilen yapı fiziksel olarak tutarlı, tek tek parametreler kaymış.**
- Gerçek değerler τ_B = 200 s ve τ_I = 120 s. L/LG'nin öğrendiği medyan değerler çoğu senaryoda τ_B = 220 s ve c ≈ 145 s; T3 ve T9'da 200 / 125 s.
- Tek tek değerler 20–25 s kaymış, ama farkları (net gecikme) 75–80 s ile gerçek değere (80 s) yakın. Rampalarda net gecikme iyi belirleniyor, iki zaman sabitinin ayrı ayrı değerleri zayıf belirleniyor.
- Kaymanın bir kısmı ayrık uygulamadan geliyor olabilir: gecikme filtresindeki bir adımlık (10 s) gecikme ve blok ortalaması. **Doğrulanmadı.**
- **T10 (sabit 28 °C):** τ_B = 0 ve c = 0 kalıyor. Termal uyarım yok, bütün adayların skoru eşit ve ilk aday seçiliyor. Alarm da yok, yani zararsız. Bu, 6F'deki belirlenebilirlik koşulunun sıcaklık kanalındaki hâli: yapı yalnızca uyarımla öğrenilebiliyor.

**Bulgu 15E: Geliştirme kümesi bu model için zayıf. Kendi tasarım hatam.**
- Geliştirmedeki 8 senaryonun 6'sı aynı sıcaklık profilini, aynı ısıtıcıyı ve aynı birim tohumlarını kullanıyor. Bu yüzden sıcaklık kaynağı sonuçları birebir aynı.
- Bağımsız sıcaklık senaryosu sayısı yalnızca 3: varsayılan profil, day-cycle ve bme-fault.
- Ayrımı yapan veri kullanılmış test kümesi. Yeni ayrılmış küme tasarlanırken sıcaklık profilleri ve ısıtıcı zamanları senaryolar arasında çeşitlendirilmeli.

**Bellek notu:** L'de aday başına 3 parametre var. Saklananlar: θ (3) + P (6, simetrik) + skor (1) + gecikme filtresi durumu (1) + önceki blok sonu (1) = 12 sayı. 16 adayla bu 192 sayı, float olarak ~770 B. v5'te ~450 B'ydı. Net gecikme iyi belirlendiği için ızgara seyreltilebilir (bellek bütçesi açık konusu).

**Kullanıcıyla alınan kararlar (2026-10-05, §15'ten sonra):**
- **Terim:** 15A'daki döngüsellik etkisine **"yapı uyuşmazlığı payı"** deniyor. Bu ad, G'deki "ızgara hata payı" ile karışmasın diye seçildi. Bu pay varsayılmayacak, ölçülecek: L'nin yeni kümedeki farklı termal yapılı senaryolardaki performansı ile kusursuz yapıdaki performansı arasındaki fark.
- **Kalıcı ofset (basamak) arıza değil (12B, 13C):** Sensörler ayarlanabilir ve ortama göre yeniden ayar gerekebilir. Bu yüzden G1'in çıktısına üçüncü bir durum ekleniyor: **"ofset olayı: tespit edildi, raporlandı, yeniden kalibre edildi"**. Değerlendirmede böyle bir olay ne kaçırılmış tespit ne de yanlış alarm sayılacak; ölçütler buna göre yeni küme ile birlikte yeniden ilan edilecek.
- **Çeşitlendirme (15E):** Yeni ayrılmış küme elle seçilmeyecek. Önceden ilan edilen parametre aralıklarından otomatik çekilecek (mihenk.md S5'teki DoE fikrinin küçük ölçeklisi). Çeşitlendirilecek eksenler:
  - **Sıcaklık profili:** rampa hızı 2–30 °C/saat, plato süresi, sinüs periyodu 2–12 saat, rastgele yürüyen ortam, ani sıçrama.
  - **Isıtıcı:** rampada, platoda ya da dönüş noktasında; 1–3 patlama; farklı süre ve güç.
  - **Termal yapı:** ikinci derece BME yolu, farklı τ'lar, sensör başına farklı ortam.
  - **Histerezis:** play, relax ve yeni bir biçim.
  - **Birim tohumları:** 200 ve üstü.

- **Değerlendirme tanımı (2026-10-05, v6 kanal tasarımı öncesi):**
  - Sağlam bir kanalda "ofset olayı" çıkması bir **yanlış alarm olayı** sayılır (K1c). Kısa sürdüğü için saatlik oranı (K1a/K1b) şişirmez. Gerekçe: sağlam bir sensörü boşuna yeniden kalibre etmek hafif ama gerçek bir hata.
  - **"Model güvenilmez"** blokları yanlış alarm sayılmaz. Ama ayrı bir ölçütle sınırlanır: bu durumdaki süre, koşunun en fazla %X'i olabilir. X yeni ölçütlerle birlikte ilan edilecek. Böylece dedektör "emin değilim" diyerek sorunlardan kaçamaz.

**Sonuç:** v6'nın sıcaklık kaynağı modeli **L**: lead-lag yapısı, ızgara payı yok, donmuşken büyüme yok. 13D'deki kilit, simülasyonda yapı düzeltilerek tamamen kalkıyor. Ama bu sonuç simülatörle aynı yapıya dayanıyor (15A). Gerçek değeri, yeni ayrılmış kümedeki farklı termal yapı senaryosunda ölçülecek.

---

## 16. G1 v6: geliştirme koşusu

**Script:** [`matlab/g1/v6/g1_prototype_v6.m`](matlab/g1/v6/g1_prototype_v6.m) · **Dedektör:** [`g1_detect_v6.m`](matlab/g1/v6/g1_detect_v6.m) · **Duman testi:** [`g1_smoke_v6.m`](matlab/g1/v6/g1_smoke_v6.m) · **Çıktı:** [`g1_v6_output.txt`](matlab/g1/v6/g1_v6_output.txt) · **Ham sonuçlar:** [`g1_v6_results.csv`](matlab/g1/v6/g1_v6_results.csv)

Kullanıcı koştu. Dedektör, ablasyonlar, yeni ölçütler ve seçim kuralı sonuçlardan önce commit edildi (45f6e2c).

**Ne yapıldı:** v6 = v5 + üç değişiklik:
- **A:** Sıcaklık kaynağı modeli L (§15).
- **B:** Olay sonu bırakma. Alarm sırasında |z| ≥ 10'a çıkan ve sonra 5 blok üst üste |z| < 3 kalan kanal hemen bırakılıyor.
- **C1:** Ofset olayı. Büyüme testi bir kanalı bıraktığında bu "ofset olayı" olarak raporlanıyor ve ofset durumunun varyansı başlangıç değerine sıfırlanıyor, yani kanal yeniden kalibre ediliyor.
- **C2:** Model güvenilmez. Ardışık iki artık arasındaki ilişki (öz-ilişki, 30 blokluk pencerede) en az iki sensör elemanında aynı anda 3/√30'u aşarsa ve sıcaklık son 30 blokta hareket ettiyse, o kanallar suçlanmıyor.

Her değişiklik ayrı bir ablasyonla ölçüldü. Veri: geliştirme kümesi (8 senaryo, tohum 0–9) ve kullanılmış test kümesi (10 senaryo, tohum 100–109), her biri beyaz ve renkli gürültüde.
- **Eşdeğerlik:** Dört değişiklik kapalıyken v6 = v5, fark 0.
- **Duman testi:** Üç koşuda fark 0.

| Ölçüt (bütün koşular) | v5 beyaz | v6 beyaz | v5 renkli | v6 renkli |
|---|---|---|---|---|
| Tespit | %100 | %100 | %98 | %99 |
| Gecikme medyanı | 5,5 dk | 5,5 dk | 25,5 dk | 25,5 dk |
| Kapsama (yeni tanım) | %96 | %89 | %75 | %80 |
| Yanlış alarm/saat, en kötü koşu | 62,1 | 51,6 | 38,2 | 13,6 |
| Yanlış alarm olayı/saat | 0,47 | 0,41 | 0,20 | 0,11 |
| Isıtıcı dışı "T src" alarmı / koşu | 13,1 | **0** | 13,1 | **0** |
| EMI sonrası manyetometre suçlama | %25 | **%0** | %22 | **%0** |
| "Güvenilmez" süre payı | – | %2 | – | %1 |

Seçim kuralına göre aday **v6**. Hiçbir ablasyon "hiçbir yerde daha kötü değil" koşulunu sağlamıyor:

| Ablasyon | v6'dan kötü olduğu hücre | v6'dan iyi olduğu hücre |
|---|---|---|
| noA | 42 | 6 |
| noB | 17 | 3 |
| noC1 | 15 | 34 |
| noC2 | 11 | 50 |

**Bulgu 16A: A ve B, hedefledikleri sorunu yan etkisiz çözüyor.**
- **A:** Isıtıcı dışı "T src" alarmı her senaryoda 0. T2'de koşu başına 180'den 0'a iniyor (§15'in kanal tarafında da geçerli olduğu görüldü).
- **B:** EMI sonrası suçlama %16–29'dan %0'a iniyor. EMI senaryosunda yanlış alarm medyanı 12,5/saatten 0'a, en kötü koşu 23'ten 1,9'a düşüyor.
- Bu iki ablasyon az sayıda hücrede v6'dan iyi; hepsi küçük farklar.

**Bulgu 16B: C1 basamak sorununu çözüyor, ama kayan bir kanalı yanlışlıkla "ofset" sayıp gizleyebiliyor.**
- **Basamak kapsaması** (yeni tanım: basamak alarm verdiğinde ya da ofset olayı olarak raporlandığında kapsanmış sayılıyor):
  - accel-step / renkli: %76 → **%99**.
  - T2 / renkli: %11 → **%99** (13C'nin çözümü).
  - Basamaklar artık ofset olayı olarak raporlanıp yeniden kalibre ediliyor.
- **Ama T9 / beyazda bir kayma (az) ofset sanılıyor.**
  - Kapsama tohumlar 100, 102, 105 ve 106'da %58–66'ya düşüyor. Bu dört koşunun dördünde de az kanalında bir ofset olayı var; diğer koşularda yok ve kapsama %86–97.
  - Muhtemel mekanizma: büyüme testi, model uyuşmazlığının gürültüsü içinde kaymanın büyümesini anlamlı bulamıyor. Kanal ofset olayı olarak bırakılıyor, yeniden kalibrasyon da kaymayı hızla modele katıyor. Yeniden kalibrasyon olmadan (noC1) kapsama %86–97.
- **Sağlam kanallarda ofset olayı:** Histerezis uyuşmazlığı olan senaryolarda koşu başına ~3 (hyst-relax, T9 beyaz). Bunlar yanlış alarm olayı sayılıyor.
- Bu yüzden noC1, 34 hücrede v6'dan iyi; 15 hücrede, basamak senaryolarında, kötü.

**Bulgu 16C: C2 amacına ulaşmıyor. Model uyuşmazlığındaki yanlış alarmlar sürüyor.**
- T9 / beyaz: yanlış alarm medyanı 43,5/saatten 37,6'ya, en kötü koşu 62'den 52'ye iniyor. Ama kapsama %88'den %80'e düşüyor. hyst-relax / beyaz: medyan 25 → 20, ama en kötü koşu 34'ten 39'a çıkıyor.
- "Güvenilmez" durum koşunun yalnızca %2–3'ünde devreye giriyor. Duman testinde koyduğum tahmin (öz-ilişkinin 30 blokta yavaş birikmesi, alarmların ise dönüş noktasında birkaç blokta çıkması) bununla tutarlı. **Doğrulanmadı.**
- Gerçek arızanın üstünü örttüğü süre %4–6. Kapsamadaki düşüş bundan biraz büyük; CUSUM sıfırlandıktan sonra kanıtın yeniden birikmesi gerekiyor.
- noC2, 50 hücrede v6'dan iyi; çoğu küçük kapsama farkları.

**Bulgu 16D: K1b hâlâ uzakta. Kaynağı tek: histerezis biçim uyuşmazlığı.**
- v6'da en kötü koşu 6/saat sınırını aşan hücreler:
  - **Büyük aşımlar:** T9 / beyaz 51,6; hyst-relax / beyaz 38,8. İkisi de gevşeme histerezisi, yani dedektörün play modeline uymayan biçim.
  - **Küçük aşımlar:** Renkli gürültüde 6,5–13,6 arası bir dizi hücre. Altı senaryoda birebir aynı 6,5 değeri muhtemelen aynı tohumun kendi gürültüsü.
- v6'nın bu hâliyle yeni bir ayrılmış kümede K1b'yi geçmesi beklenmiyor.

**Genel değerlendirme:**
- v6, v5'in §13'teki beş başarısızlığından üçünü geliştirme verisinde çözüyor: sıcaklık kaynağı kilidi (K3b), EMI sonrası (K3c) ve basamak kapsaması (K2c, renkli).
- Kalanlar:
  - **K1b:** histerezis biçim uyuşmazlığı. C2 bunu çözmedi.
  - C1'in uyuşmazlık altında kaymayı ofset sanması.
- İkisinin kökü aynı: kanal modeli, ICM'nin histerezis biçimini temsil edemiyor.

**Bulgu 16E: Oynatıcıda görülen iki yan etki (T2 / beyaz, tohum 100). Toplu tabloda da izi var, mekanizma doğrulanmadı.**
- **Kaynak:** [`g1_export_replay.m`](matlab/g1/v6/g1_export_replay.m) ile dışa aktarılan koşu, [G1 Oynatıcı](viewer/replay.html)'da incelendi (yayında: [yusa.app/mihenk/replay](https://yusa.app/mihenk/replay/)). Kontrol: v5 ve v6'nın zT'si, sıcaklık kaynağı modelinin ayrı hesabıyla 6/6 koşuda birebir aynı.
- **A'nın kanallardaki bedeli:**
  - v5'te sıcaklık kaynağı kilidi 3,1–6,1 saat arasında BME referansını kullanılamaz yapıyordu. v6'da kilit yok, BME referansı yeniden kullanılıyor.
  - Bunun bir sonucu olarak mz, 3,8–4,8 saat arasında boşuna suçlanıyor. v5'te bu alarm yok.
  - Toplu tabloda da tutarlı: T2 / beyazda en kötü koşu, noA'da (v5'in sıcaklık kaynağı) 0,8/saat, A'nın açık olduğu bütün varyantlarda 6,6/saat.
  - Yani v5'in kilidi, BME referansındaki başka bir sorunu gizliyormuş. **Mekanizma doğrulanmadı.**
- **B, kalıcı bir basamağı da "olay bitti" sanabiliyor:**
  - ax basamağı 4,0 saatte |z| ≥ 10 ile yakalanıyor. 5 blok sakin geçince 4,09'da bırakılıyor; olay sonu bırakmasının tanımına uyuyor.
  - Basamak sürdüğü için 5,3'te yeniden yakalanıyor ve 6,14'te ofset olayı olarak raporlanıyor.
  - Toplu tabloda T2 / beyazın yalnız alarmlarla hesaplanan kapsaması v5'te %75, v6'da %46.
  - Muhtemel neden: kanal donmuşken kullanılabilir iki referanstan hangisinin basamağı daha iyi açıkladığı değişiyor ve |z| düşüyor. **Doğrulanmadı.**
- **T9'daki 16B mekanizması oynatıcıda doğrudan görülüyor:**
  - az kayması 4,62'de yakalanıyor ve 5,11'de ofset olayı sayılıyor. Kanal 6,10'a kadar sessiz kalıyor, yani kayma ~1 saat kaçırılıyor.
  - Sağlam kanallarda (gy, gz, ay) dönüş noktalarından sonra ofset olayları var.

---

## 17. Tanı: v6'nın iki yan etkisi (16E)

**Script:** [`matlab/g1/v6/g1_diag_v6_side.m`](matlab/g1/v6/g1_diag_v6_side.m) · **Çıktı:** [`g1_diag_v6_side_output.txt`](matlab/g1/v6/g1_diag_v6_side_output.txt) · **Figür:** [`g1_diag_v6_side.png`](matlab/figures/g1_diag_v6_side.png)

Kullanıcı koştu. Yalnızca tanı amaçlı; v6'da bir şey değiştirilmedi.

**Ne yapıldı:**
- `g1_detect_v6.m`'ye iki tanı anahtarı eklendi. Varsayılanlarında davranış değişmiyor.
  - `refMask`: kanal kararlarında kullanılabilecek referansları sınırlıyor.
  - `trace`: seçili genişlikteki modelin ofset ve tempco değerlerini kaydediyor.
- T2 / beyaz / tohum 100 üç varyantla koşuldu: v6, noA ve yalnız ICM referanslı v6.
- mz'nin alarm başlangıcı ile ax basamağı etrafı blok blok yazdırıldı.
- Tohum 100–109'da yan etkilerin ne kadar yaygın olduğu sayıldı.

**Bulgu 17A: mz alarmı BME referansından gelmiyor. 16E'deki yorumum yanlıştı.**
- **H1 (referanslar arasında gidip gelmek) reddedildi:** mz'nin iki referansa göre z'si neredeyse aynı (zB ≈ zI − 0,3). İkisi de 3,6–3,9 saat arasında sürekli hafif negatif (ortalama ~ −0,8σ). Kullanılan değer çoğu blokta zI.
- **Ortak kök:** CUSUM, bu kalıcı küçük yanlılığı **üç varyantta da** biriktiriyor.
  - Platonun başında (3,0–4,0 saat) zirveler v6'da ~14, noA'da ~8, yalnız ICM'de ~5,5.
  - Rampanın sonunda (6,6–7,0 saat) üçünde de ~6.
  - v6 eşiği (h = 10) küçük bir farkla aşıyor, diğerleri aşmıyor. Varyantların geçmişi 3,14 saatte, noA'da BME'nin suçlanmaya başladığı anda ayrışıyor.
- **Yaygınlık:** Tohum 100–109'da sağlam kanalda alarm yalnız iki tohumda var. Tohum 100'de v6'da mz 42 blok. Tohum 108'de mz v6'da 6 blok, noA'da 4, yalnız ICM'de 4 blok.
- **Sonuç:** Bu, eşiğe yakın bir model yanlılığı; tohuma göre eşiği aşıp aşmıyor. §16'daki "noA 0,8 / v6 6,6" farkı bu tek tohumdan geliyor. "v5'in kilidi BME referansındaki bir sorunu gizliyordu" yorumu desteklenmiyor.
- **Yanlılığın nedeni bilinmiyor.** Termal dönüşlerden sonra görünüyor. Manyetometrenin kendi gecikmesi (90 s) ve gradyanı referanslardan farklı; ama bu tek başına saatlerce süren bir yanlılığı açıklamıyor. **Açık konu.**

**Bulgu 17B: Erken bırakmanın nedeni, donmuş kanalın tahmin belirsizliğinin bir blokta patlaması. Bu sistematik.**
- **H3 (referans değişimi) reddedildi:** ax'ın iki referansa göre z'si birebir aynı (25,59 / 25,72, sonra 2,99 / 3,01). Yalnız ICM referanslı koşuda da aynı şey oluyor.
- **Gözlem:** Basamak 0,2 mg ve sürüyor. Buna rağmen z, ilk blokta 25,6'dan bir sonraki blokta 3,0'a düşüyor. Sonra 2,38, 1,87, 1,61, 1,36 diye sönüyor, yani ~3/√n gibi (3/√2 = 2,1; 3/√3 = 1,7; 3/√4 = 1,5; 3/√5 = 1,3).
- **Mekanizma (hesapla tutarlı, ayrıca koşturularak doğrulanmadı):**
  - v5'in B düzeltmesi, donmuş kanalın tempco'suna her blokta qm = sb²/1440 kadar varyans ekliyor. İvmeölçerde sb = 0,15 mg/°C, yani qm = 1,6·10⁻⁵.
  - Bu varyans tahmine (T − T0)² çarpanıyla giriyor; T0 koşunun ilk bloğundaki sıcaklık. Platoda T − T0 ≈ 14,5 °C, yani bir blokta eklenen varyans ≈ 0,0033 mg², std ≈ 0,057 mg.
  - 0,2 mg'lık basamak da z ≈ 3,5'e düşüyor; gözlenen 3,0. Sonraki bloklarda std √n ile büyüyor ve z √n ile sönüyor.
  - |z| < 3 olan 5 blok dolunca olay sonu kuralı (B) kanalı bırakıyor.
- **Yaygınlık:** 10 tohumun 10'unda ax, 4,09–4,11 saatte, iki varyantta da bırakılıyor.
- **15C ile aynı tasarım hatası:** Orada sıcaklık kaynağı modelinde (L − L0) vardı, burada kanal modelinde (T − T0) var. Tempco'ya eklenen model hatası, sıcaklığın **koşu başındaki** değerden uzaklığıyla ölçekleniyor. Oysa önemli olan, kanalın **donduğu andan** beri sıcaklığın ne kadar değiştiği.
- **Bu, önceki bulguların bir kısmını da açıklıyor olabilir:**
  - 12B: serbest bırakma testinin basamakları bırakması.
  - 16B: C1'in uyuşmazlık altında kaymayı ofset sanması.
  - Uzak bir platoda donan her kanalın sapması, gerçek büyüklüğünden bağımsız olarak hızla "anlamsız" hâle geliyor.

**v7 için anlamı (henüz uygulanmadı):**
1. **Donma anına göre ölçeklenen model hatası:** Kanal donunca model hatası (T − T_donma)² ile büyümeli. Platoda donan bir kanal gerçek sapmasını korur, rampada ise belirsizlik sıcaklık değiştikçe büyür.
2. **Ofset olayını açıkça tanımak:** 1. madde uygulanınca bir basamak artık kendiliğinden "küçülmeyecek". Büyümeyen ama büyük kalan bir sapma (|z| ≫ 3, eğim yok) doğrudan ofset olayı olarak tanınmalı. Bu kullanıcının kararıyla uyumlu (§15).
3. **mz yanlılığının nedeni:** Eşiğe yakın, termal dönüşlerden sonra görülen bir yanlılık. 1. maddeden sonra yeniden bakılmalı.

---

## 18. G1 v7: geliştirme koşusu

**Script:** [`matlab/g1/v7/g1_prototype_v7.m`](matlab/g1/v7/g1_prototype_v7.m) · **Dedektör:** [`g1_detect_v7.m`](matlab/g1/v7/g1_detect_v7.m) · **Duman testi:** [`g1_smoke_v7.m`](matlab/g1/v7/g1_smoke_v7.m) · **Çıktı:** [`g1_v7_output.txt`](matlab/g1/v7/g1_v7_output.txt) · **Ham sonuçlar:** [`g1_v7_results.csv`](matlab/g1/v7/g1_v7_results.csv)

Kullanıcı koştu. Dedektör, ablasyonlar ve seçim kuralı sonuçlardan önce commit edildi (12dc15f).

**Ne yapıldı:** v7 = v6 + iki değişiklik (§17'deki 1. ve 2. madde):
- **D1:** Donmuş kanalın model hatası `nF · qm · ((T − T_donma)² + (dr − dr_donma)²)`. Yani hata, koşu başındaki sıcaklığa göre değil, kanalın donduğu andaki sıcaklığa göre ölçekleniyor.
- **D2:** Son 30 blokta anlamlı biçimde büyümeyen, tek işaretli ve her blokta |z| ≥ 3 olan bir sapma ofset olayı sayılıyor.

Veri v6 ile aynı. Kontroller:
- **Eşdeğerlik:** D1 ve D2 kapalıyken v7 = v6, fark 0.
- **Regresyon:** Bu koşudaki v6 satırları §16'daki CSV ile aynı (3879 değer, en büyük göreli fark 4·10⁻¹⁵). Yani v6'ya §17'de eklenen tanı anahtarları hiçbir şeyi değiştirmemiş.

| Ölçüt (bütün koşular) | v6 | noD2 (= v6 + D1) | noD1 (= v6 + D2) | v7 |
|---|---|---|---|---|
| Kapsama, beyaz | %89 | %91 | %86 | %86 |
| Kapsama, renkli | %80 | %79 | %72 | %70 |
| En kötü koşu, beyaz (yanlış alarm/saat) | 51,6 | 127,1 | 51,6 | 106,1 |
| En kötü koşu, renkli | 13,6 | 14,4 | 13,6 | 14,4 |
| Yanlış alarm olayı/saat, renkli | 0,11 | 0,08 | 0,11 | 0,08 |
| Arızalı kanalda ofset olayı / koşu, beyaz | 0,1 | 0,1 | 0,6 | 1,4 |

**Seçim kuralının sonucu: v7.** Her iki ablasyon da bazı hücrelerde v7'den kötü (noD1: 43 kötü / 60 iyi; noD2: 11 kötü / 33 iyi).

**Ama v7, v6'dan genel olarak kötü.** Kural yalnızca ablasyonları v7 ile karşılaştırıyor; bir önceki sürümü (v6) karşılaştırmaya almıyor. Bu, kuralı ilan ederken yaptığım bir tasarım boşluğu. Kurala göre aday v7, ama v7'yi v6'nın yerine **önermiyorum**. Gerekçe aşağıda. Bundan sonraki kurallarda bir önceki sürüm de karşılaştırmaya girecek.

**Bulgu 18A: D1 doğru çalışıyor; düzelttiği hata, histerezis uyuşmazlığının alarmlarını kısa tutuyormuş.**
- **Hedeflenen sorun çözüldü:** T2 / beyazda basamak artık erken bırakılmıyor. noD2'de basamak boyunca alarm veriliyor, yalnız alarmlarla hesaplanan kapsama %46'dan %98'e çıkıyor.
- **Başka iyileşmeler:**
  - T2 / beyazdaki mz alarmı da kayboluyor; en kötü koşu 6,6'dan 1,1/saate iniyor. 17A'daki mz alarmının süresi muhtemelen eski hata yüzünden uzuyordu. **Doğrulanmadı.**
  - Renkli gürültüde en kötü koşu birçok senaryoda düşüyor (base 6,5 → 3,9; bme-fault 10,7 → 4,6).
- **Bedeli histerezis uyuşmazlığında:**
  - En kötü koşu hyst-relax / beyazda 38,8'den 99,9'a, T9 / beyazda 51,6'dan 127'ye çıkıyor.
  - v6'da donmuş kanalın belirsizliği hızla büyüyordu; uyuşmazlık yüzünden donan sağlam kanallar bu sayede çabuk "sönüp" bırakılıyordu. D1 ile sapmalarını koruyorlar ve uzun süre suçlu kalıyorlar.
  - Duman testindeki tahmin (T9'da arıza bloğu 332 → 791) böylece doğrulanmış oluyor.
- **Sonuç:** D1 doğru, ama histerezis biçim sorunu çözülmeden tek başına net bir kazanç değil. v6'nın histerezis uyuşmazlığındaki görece iyi sonucu, bir hatanın yan etkisiymiş.

**Bulgu 18B: D2 yavaş kaymaları ofset sanıyor. "Büyüme bulunamadı", "büyüme yok" demek değil.**
- D2'nin olduğu iki varyantta (noD1 ve v7), arızalı kanallarda ofset olayı sayısı belirgin artıyor; kapsama da düşüyor:
  - T3 / beyaz: koşu başına 6,2 ofset olayı, kapsama %98 → %83.
  - day-cycle / beyaz: 4,8 ofset olayı, kapsama %97 → %82.
  - T10 / renkli: sabit sıcaklıkta yavaş kayma, kapsama %91 → %67.
- Bu düşüş noD1'de (v6 + D2) de var. Yani nedeni D1 değil, D2.
- **Mekanizma:** Büyüme testi, 30 blokluk pencerede z'nin eğimi istatistiksel olarak anlamlı değilse "büyümüyor" diyor. Yavaş bir kaymada 30 dakikalık eğim gürültünün içinde kalıyor; test büyümeyi bulamıyor ve sapma "büyük ama büyümeyen" sayılıyor.
- Bu, istatistiksel güç (power) sorunu: anlamlı büyüme bulamamak, büyümenin yokluğuna kanıt değil.
- Aynı sorun v6'nın C1'inde de vardı (16B'deki T9 kayması), ama |z| < 3 şartı onu sınırlıyordu. D2 bu sınırı kaldırınca sorun büyüdü.

**Sonuç ve sonraki adım için anlamı:**
- **Mevcut en iyi sürüm v6 olarak kalıyor.** v7'den D1 doğru bir düzeltme olarak tutulmalı; D2 bu hâliyle bırakılmalı.
- **Histerezis biçimi artık her şeyin önünde.** Hem K1b'nin hem D1'in görünür kıldığı alarmların kaynağı bu.
- **D2 yeniden tasarlanmalı.** "Büyüme yok" bir eşdeğerlik testiyle (equivalence test) gösterilmeli: eğimin güven aralığının üst sınırı, tespit edilmesi gereken en küçük kayma hızının altında kalmalı. Bu, açık konulardaki "en küçük algılanabilir kayma hızı" (9D) tanımına doğrudan bağlanıyor.
- **Seçim kuralı:** Bundan sonra bir önceki sürüm de karşılaştırmaya girecek.

---

## 19. G1 v8: geliştirme koşusu ve v6 ile karşılaştırma

**Script:** [`matlab/g1/v8/g1_prototype_v8.m`](matlab/g1/v8/g1_prototype_v8.m) · **Dedektör:** [`g1_detect_v8.m`](matlab/g1/v8/g1_detect_v8.m) · **Duman testi:** [`g1_smoke_v8.m`](matlab/g1/v8/g1_smoke_v8.m) · **Çıktı:** [`g1_v8_output.txt`](matlab/g1/v8/g1_v8_output.txt) · **Ham sonuçlar:** [`g1_v8_results.csv`](matlab/g1/v8/g1_v8_results.csv)

Kullanıcı koştu. Dedektör, ablasyonlar ve iki adımlı seçim kuralı sonuçlardan önce commit edildi (db4c1c6).

**Ne yapıldı:** v8 = v6 + v7'nin D1'i + **R**. D2 kapalı.
- **R (gevşeme histerezisi adayları):** Kanal modeli histerezisi şimdiye kadar yalnız play biçiminde tanıyordu. R, play genişliklerinin yanına `h = T − gecikme(T, τh)` regresörünü ekliyor. τh ızgarası 60, 120, 240, 480, 960 s; seçimi yine SSE yapıyor. Izgara simülatörün 180 s'sini ve T9'un 300 s'sini bilerek içermiyor; ızgara uyuşmazlığının payı saklanmıyor, ölçülüyor.
- **Bedel:** Kanal ve referans başına model sayısı 5'ten 10'a çıkıyor (bellek bütçesi, açık konular).

Veri v6 ve v7 ile aynı (geliştirme kümesi tohum 0–9 + kullanılmış küme tohum 100–109). Kontroller:
- **Eşdeğerlik:** R kapalı ve eski taban modunda v8 = v6; R kapalıyken v8 = v7noD2. İkisinde de fark 0.
- **Regresyon:** v6 satırları §16'daki CSV ile, v8noR satırları §18'deki v7noD2 satırlarıyla aynı (her biri 3879 değer, en büyük göreli fark 4·10⁻¹⁵).

| Ölçüt (bütün koşular) | v6 | noR (= v6 + D1) | noD1 (= v6 + R) | v8 |
|---|---|---|---|---|
| En kötü koşu, beyaz (yanlış alarm/saat) | 51,6 | 127,1 | 8,1 | **3,8** |
| En kötü koşu, renkli | 13,6 | 14,4 | 11,8 | 11,8 |
| Yanlış alarm olayı/saat, beyaz | 0,41 | 0,39 | 0,05 | **0,04** |
| Yanlış alarm olayı/saat, renkli | 0,11 | 0,08 | 0,10 | 0,08 |
| Kapsama, beyaz | %89,3 | %91 | %91 | **%92,2** |
| Kapsama, renkli | **%79,7** | %79 | %77 | %78,0 |
| Tespit, beyaz / renkli | %100 / %99 | aynı | aynı | aynı |
| Gecikme medyanı, beyaz / renkli (dk) | 5,5 / 25,5 | aynı | aynı | aynı |

**Seçim kuralının sonucu: G1 dedektörü v6 olarak kalıyor.**
- **1. adım (v8 ailesi):** aday v8. noR 29 hücrede kötü / 39'unda iyi; noD1 42 kötü / 46 iyi. İkisi de "hiçbir yerde kötü değil" şartını sağlamıyor.
- **2. adım (v8, v6'ya karşı):**
  - (a) v8, 59 hücrede iyi / 58'inde kötü → geçti.
  - (b) beyaz: en kötü 3,8 / 51,6, kapsama %92,2 / %89,3, tespit eşit → geçti.
  - (b) renkli: en kötü 11,8 / 13,6, tespit eşit, ama **kapsama %78,0 / %79,7**. Fark 1,7 puan, ilan edilen tolerans 1 puan → **kaldı**.

**Bulgu 19A: R hedeflediği sorunu çözüyor. K1b beyaz gürültüde ilk kez geçer durumda.**
- Histerezis uyuşmazlığından gelen alarmlar neredeyse tamamen gitti:
  - hyst-relax / beyaz: en kötü 38,8 → 0, kapsama %92 → %98;
  - T9 / beyaz: en kötü 51,6 → 3,0, olay oranı 3,95 → 0,03/saat, kapsama %80 → %92.
- Beyaz gürültüde bütün koşuların en kötüsü 3,8/saat; K1b eşiği (≤ 6) altında. Bu geliştirme kümesinde bir gözlem, ayrılmış test değil.
- **Biçim seçimi beyaz gürültüde doğru:** gevşeme biçimi relax senaryolarında blokların %91–98'inde seçiliyor, play senaryolarında %0–1'inde. Seçilen τ duman testinde 240 s'ye oturdu (ızgarada 180 ve 300'e en yakın değer).
- **D1, R ile birlikte işe yarıyor:** §18'de D1 tek başına histerezis alarmlarını büyütüyordu (noR'da en kötü 127). R uyuşmazlığı kaldırınca D1'in T2 basamağındaki kazancı kalıyor (T2 / beyaz kapsama %65 → %98).

**Bulgu 19B: Renkli kapsamadaki kaybın büyük kısmı D1'den geliyor ve sistematik.**
- Kapsama kaybı birkaç senaryoda yoğunlaşıyor:

| Senaryo | v6 | noR | noD1 | v8 |
|---|---|---|---|---|
| two-faults / beyaz | %55 | %41 | %55 | %41 |
| two-faults / renkli | %62 | %57 | %62 | %58 |
| day-cycle / renkli | %85 | %77 | %86 | %77 |
| T9 / renkli | %62 | %54 | %58 | %53 |

- two-faults ve day-cycle'da noD1, v6 ile aynı; kayıp D1 olan iki varyantta var. Yani kaynak R değil, D1.
- two-faults / beyazda v8 10 tohumun 10'unda %40–42 veriyor (v6: %42–70). Tohumdan bağımsız bu kadar dar bir değer, deterministik bir mekanizmaya işaret ediyor. **Mekanizma doğrulanmadı.** Tahmin (H1): iki arıza bir rampada birlikte başlayınca D1'in sabitlenmiş model hatası `(T − T_donma)²` ile büyüyor, |z| 3'ün altına iniyor, büyüme testi "büyüme yok" deyip kanalı ofset olayı olarak bırakıyor ve yeniden kalibrasyon kaymayı yutuyor (16B'deki mekanizmanın D1'li hâli).
- T9 / renklide kayıp iki bileşende de var (noR %54, noD1 %58).
- Kazançlar da var: T2 / beyaz +33 puan, T9 / beyaz +12, hyst-relax / beyaz +6, T3 / renkli +6.

**Bulgu 19C: Renkli gürültüde R, play histerezisinde de gevşeme biçimini seçiyor.**
- base / renkli %23, two-faults / renkli %28, accel-step / renkli %24 blokta gevşeme seçiliyor. Gerçek histerezis bu senaryolarda play türünde.
- Beyazda bu oran %0–1. Renkli gürültünün yavaş bileşeni, iki biçimi SSE ile ayırmayı zorlaştırıyor (tanınabilirlik, 6F ile aynı aile).
- Bu yanlış seçimin kapsamaya etkisi tutarsız: base / renklide etki yok, T3 / renklide noD1'in kapsaması %65'ten %48'e düşüyor.

**Bulgu 19D: Aşırı uyum (overfitting) sorusu. Geliştirme koşusu buna tek başına cevap veremez.**
- R'nin kazançları tam olarak simülatörün gevşeme biçimini kullanan senaryolarda yoğunlaşıyor. R bu biçimi birebir modelliyor (ADR-012, döngüsellik).
- Izgaranın gerçek τ'yu içermemesi τ'ya uyumu dışlıyor, **biçime uyumu dışlamıyor**. Biçime uyumu ancak modellenmemiş üçüncü bir histerezis biçimi içeren ayrılmış küme sınayabilir.
- Geliştirme koşusunda tohumlara uyum riski düşük: aynı farklar 10 tohumun çoğunda görülüyor. Bu yine de ayrıca sınanacak (aşağıda).

**Kullanıcı önerisi ve kayıt:** Kullanıcı, sonuçları gördükten sonra renkli kapsama toleransının 1 puandan 2 puana çıkarılmasını önerdi; gerekçe v8'in yanlış alarmlardaki büyük üstünlüğü. Fark 1,7 puan olduğu için bu değişiklik v8'i geçirmeye tam yetecek kadar. Uygulanırsa **sonuç sonrası karar** olarak işaretlenecek. Karar aşağıdaki tanıdan sonra verilecek.

**Sonraki adım:** [`g1_diag_v8.m`](matlab/g1/v8/g1_diag_v8.m), iki bölüm:
1. **Mekanizma (19B):** two-faults, day-cycle / renkli ve T9 / renklide arızalı kanal başına kapsama, serbest bırakmalar (tür), ofset olayları ve bırakmadan sonra kaybedilen bloklar; H1'in sınanması.
2. **Genelleme (19D):** Taze tohumlarda (300–309; ayrılmış küme bu aralığı kullanmayacak) ızgarada olmayan parametrelerle v6, noD1 ve v8: gevşeme τ = 90 ve 600 s, play genişliği 0,6 ve 1,6 °C (simülatöre varsayılanı 1,0 olan bir genişlik alanı eklendi; varsayılan yol bit düzeyinde aynı), ayrıca two-faults ve day-cycle'ın taze tohumları.

### 19 (devam). Tanı: kapsama kaybının mekanizması ve genelleme

**Script:** [`matlab/g1/v8/g1_diag_v8.m`](matlab/g1/v8/g1_diag_v8.m) · **Çıktı:** [`g1_diag_v8_output.txt`](matlab/g1/v8/g1_diag_v8_output.txt)

Kullanıcı koştu. H1 ve okuma kuralı sonuçlardan önce commit edildi (44633a1). Kontroller:
- `simulate_node` varsayılan yolu ile `hystWidth = 1,0` birebir aynı (fark 0).
- Mekanizma bölümünde yeniden hesaplanan kapsama, geliştirme koşusunun CSV'siyle aynı (en büyük fark 5·10⁻¹⁶).

**Bulgu 19E: H1 two-faults için reddedildi. Kayıp C2'den geliyor; D1 onu büyütüyor.**
- two-faults / beyazda v8 arızalı kanalları **hiç serbest bırakmıyor** (büyüme testi bırakması 0/10 tohum). H1'in öngördüğü yol bu senaryoda yok.
- Olay kaydı (tohum 0): gz ve ax 4,58 saatte suçlanıyor, sonra bayrak bir serbest bırakma olmadan düşüyor, 6,61 saatte yeniden kalkıyor.
- Bayrağı serbest bırakmasız düşüren şey C2 ("model güvenilmez", §16): CUSUM'u sıfırlıyor ve kanalı 3. duruma alıyor. Geliştirme CSV'sindeki güvenilmez payı:

| two-faults | v6 | noR | noD1 | v8 |
|---|---|---|---|---|
| Arızalı blokların "güvenilmez" payı, beyaz | %40 | %57 | %40 | %57 |
| Kapsama (yalnız alarm), beyaz | %55 | %41 | %55 | %41 |
| Arızalı blokların "güvenilmez" payı, renkli | %19 | %25 | %18 | %23 |

- Beyazda kapsama ile güvenilmez payı birlikte %95–98'e tamamlanıyor: kaybolan blokların neredeyse hepsi C2'ye gidiyor.
- **Mekanizma (çıkarım):** İki farklı sensing elemanında (jiroskop ve ivmeölçer) aynı anda başlayan iki kayma, z'lerde yüksek öz-ilişki üretiyor. Sıcaklık da rampada. Bu, C2'nin tetik koşulunun ("en az iki elemanda ilişkili artık + sıcaklık hareket etti") birebir aynısı. Yani C2 iki gerçek arızayı "model güvenilmez" diye okuyor. D1, donmuş kanalın sapmasını koruduğu için öz-ilişki daha uzun sürüyor ve pay %40'tan %57'ye çıkıyor.
- v6 da bu senaryoda aynı nedenle kayıp yaşıyor; bu yüzden two-faults v6'da bile %55.
- **C2 için anlamı:** §16C'de C2'nin etkisiz olduğu bulunmuştu. Şimdi iki eşzamanlı arızada zararlı olduğu da görüldü. Kaldırılması gerekiyor.

**Bulgu 19F: day-cycle ve T9 / renklide H1'in mekanizması doğrulandı.**
- D1 olan varyantlarda büyüme testi gz'yi ya da az'ı rampada ofset olayı olarak bırakıyor; yeniden kalibrasyon kaymayı yutuyor:

| Senaryo | | v6 | noR | noD1 | v8 |
|---|---|---|---|---|---|
| day-cycle / renkli | büyüme bırakması olan tohum | 0/10 | 7/10 | 0/10 | 8/10 |
| | bırakmadan sonra kaybedilen blok | %0 | %9 | %0 | %10 |
| | kapsama | %85 | %77 | %86 | %77 |
| T9 / renkli | büyüme bırakması olan tohum | 3/10 | 8/10 | 2/10 | 7/10 |
| | kaybedilen blok | %13 | %21 | %11 | %22 |
| | kapsama | %62 | %54 | %58 | %53 |

- Bırakmaların %88–100'ü rampada (son 30 blokta ICM sıcaklığı > 1 °C değişmiş). Kaybedilen bloklar kapsama farkının büyük kısmını açıklıyor (day-cycle: 10 puan kayıp, 8–9 puan fark).
- **Mekanizma:** D1'in donma anına sabitlenen model hatası `(T − T_donma)²` ile büyüyor. Döngüsel ya da uzun rampalarda kanalın tahmin belirsizliği büyüyor, |z| 3'ün altına iniyor. Yavaş bir kaymada 30 blokluk eğim de gürültünün içinde kalınca büyüme testi "büyüme yok" diyor ve kanal ofset sayılıyor. Bu, 18B'deki güç (power) sorununun D1'li hâli.

**Bulgu 19G: R ızgara dışına genelleniyor; geliştirme farkları taze tohumlarda tekrarlanıyor.** Taze tohum 300–309:

| Hücre | Ölçüt | v6 | noD1 | v8 |
|---|---|---|---|---|
| relax τ = 90 / beyaz | en kötü yanlış alarm/saat | 7,7 | **0,0** | **0,0** |
| relax τ = 600 / beyaz | en kötü | 78,0 | **3,3** | 16,3 |
| | medyan | 66,1 | 0,3 | 2,3 |
| | kapsama | %85 | %98 | %98 |
| play 0,6 ve 1,6 / beyaz | en kötü | 0,0 | 0,0–0,2 | 0,0–0,2 |
| renkli hücrelerin hepsi | en kötü | 4,6–4,7 | 4,7 | 4,7 |
| two-faults / beyaz | kapsama | %51 | %51 | %41 |
| day-cycle / renkli | kapsama | %89 | %89 | %81 |

- **τ'ya uyum yok:** Izgarada olmayan τ = 90 ve 600 s'de R'nin üstünlüğü sürüyor. τ = 600'de v6 saatte 66 alarm (medyan) üretirken noD1 0,3.
- **Play tarafında zarar yok:** Izgarada olmayan genişliklerde (0,6 ve 1,6) R nötr.
- **Renkli gürültüde R nötr:** Bütün renkli hücrelerde üç dedektör aynı. Renkli gürültüde histerezis uyuşmazlığı zaten gürültü bütçesinin içinde kalıyordu (13B). Play 0,6 / renklide biçim seçimi blokların %18–21'inde gevşemeye kayıyor (19C), ama sonuca etkisi yok.
- **Tohumlara uyum yok:** two-faults ve day-cycle'daki kayıplar taze tohumlarda da aynı büyüklükte tekrarlanıyor.
- **D1'in bedeli burada da görünüyor:** τ = 600 / beyazda v8'in en kötü koşusu 16,3/saat, K1b eşiğinin (≤ 6) üstünde; noD1'de 3,3.
- **Bu bölümün cevaplayamadığı:** Modellenmemiş üçüncü bir histerezis biçimine uyum. Bunu yalnızca yeni ayrılmış küme sınayabilir (19D).

**Tanının sonucu:**
- v8'in kapsama kaybının iki kaynağı da adı konmuş, düzeltilebilir mekanizmalar: **C2** (iki eşzamanlı arızada) ve **D1 × büyüme testi** (rampada ofset sanma). İkisi de yapısal bir bedel değil.
- R, hedeflediği yerde ve ızgara dışında net kazanç; play senaryolarında ve renkli gürültüde nötr.
- Bu yüzden sonuç sonrası tolerans artışına gerek görünmüyor; düzeltmeleri içeren bir v9 doğru yol.

---

## 20. G1 v9: geliştirme koşusu ve v6 ile karşılaştırma

**Script:** [`matlab/g1/v9/g1_prototype_v9.m`](matlab/g1/v9/g1_prototype_v9.m) · **Dedektör:** [`g1_detect_v9.m`](matlab/g1/v9/g1_detect_v9.m) · **Duman testi:** [`g1_smoke_v9.m`](matlab/g1/v9/g1_smoke_v9.m) · **Çıktı:** [`g1_v9_output.txt`](matlab/g1/v9/g1_v9_output.txt) · **Ham sonuçlar:** [`g1_v9_results.csv`](matlab/g1/v9/g1_v9_results.csv)

Kullanıcı koştu. Dedektör, ablasyonlar ve seçim kuralı sonuçlardan önce commit edildi (8c714dc). Kural v8'inkiyle aynı (iki adım, aynı eşikler).

**Ne yapıldı:** v9 = v8 − C2 + E.
- **C2 kapalı (19E):** "Model güvenilmez" durumu iki eşzamanlı gerçek arızayı yutuyordu.
- **E (ofset olayı için eşdeğerlik testi, 19F):** Büyüme testi "büyüme bulunamadı" deyince kanalı ofset olayı sayıyordu; rampada bu zayıf bir kanıttı. E bunun yerine "kayma yok"un kanıtını istiyor: donmuş kanalın artığı (kanal biriminde, D1'in şişirmesi girmiyor) donmadan beri en fazla 240 blok üzerinden zamana regresyonlanıyor ve kanal yalnız `|eğim| + t·se < dMin` ise ofset olayı oluyor. Bu, iki tek yönlü testin (TOST [R15]) ikisinin de dMin büyüklüğünde bir kaymayı reddetmesi demek. `dMin = 5·√3·σA(1 saat)` / saat, kanalın Allan uyumundan (9D'deki "en küçük algılanabilir kayma hızı"nın ilk formel hâli). Yeni ayarlanmış parametre yok.
- Ablasyonlar: **v9noE** (= v8 − C2, büyüme testi) ve **v9noC2** (= v8 + E).

Veri v6–v8 ile aynı (geliştirme tohum 0–9 + kullanılmış küme tohum 100–109, gürültü tipi başına 180 koşu). Kontroller:
- **Eşdeğerlik:** C2 açık ve büyüme testiyle v9 = v8, fark 0.
- **Regresyon:** v6 ve v8 satırları §19'daki CSV ile aynı (en büyük göreli fark 4·10⁻¹⁵ ve 2,8·10⁻¹⁵).

| Ölçüt (bütün koşular) | v6 | v8 | v9noE (= v8 − C2) | v9noC2 (= v8 + E) | v9 |
|---|---|---|---|---|---|
| En kötü koşu, beyaz (yanlış alarm/saat) | 51,6 | **3,8** | **3,8** | 53,5 | 53,5 |
| En kötü koşu, renkli | 13,6 | **11,8** | **11,8** | 32,7 | 32,7 |
| 10/saat'i aşan koşu, beyaz / renkli (180'er koşudan) | 19 / 3 | 0 / 1 | 0 / 1 | 8 / 7 | 8 / 7 |
| Kapsama, beyaz | %89,3 | %92,2 | %96,9 | %92,6 | **%97,5** |
| Kapsama, renkli | %79,7 | %78,0 | **%81,0** | %76,8 | %80,3 |
| Arızalı blokların "güvenilmez" payı, beyaz / renkli | %4 / %2 | %5 / %2 | %0 / %0 | %5 / %2 | %0 / %0 |
| Tespit, beyaz / renkli | %100 / %99 | aynı | aynı | aynı | aynı |
| Gecikme medyanı, beyaz / renkli (dk) | 5,5 / 25,5 | aynı | aynı | aynı | aynı |

**Seçim kuralının sonucu: G1 dedektörü v6 olarak kalıyor.**
- **1. adım (v9 ailesi):** aday v9. v9noE 20 hücrede kötü / 54'ünde iyi; v9noC2 48 kötü / 15 iyi. İkisi de "hiçbir yerde kötü değil" şartını sağlamıyor.
- **2. adım (v9, v6'ya karşı):**
  - (a) v9, 75 hücrede iyi / 63'ünde kötü → geçti.
  - (b) beyaz: kapsama %97,5 / %89,3, tespit eşit, ama **en kötü 53,5 / 51,6** → kaldı.
  - (b) renkli: kapsama %80,3 / %79,7, tespit eşit, ama **en kötü 32,7 / 13,6** → kaldı.
- Bilgi için v9, v8'e karşı: 56 hücrede kötü / 56'sında iyi.

**Bulgu 20A: C2'yi kaldırmak hedefini tutturdu.**
- two-faults kapsaması: beyaz %55 (v6) / %41 (v8) → %96 (v9noE) / %98 (v9); renkli %62 / %58 → %83 / %87.
- "Güvenilmez" payı bütün koşularda %0'a indi; 19E'deki mekanizma doğrulanmış oldu.
- **Bedel küçük ve renkli gürültüde:** v9noE'de bazı renkli hücrelerin en kötü koşusu yükseldi (base 4,6 → 7,9, T1 6,2 → 9,5, T4 5,5 → 9,6/saat), sağlıklı kanallarda ofset olayı 0,1'den 0,2'ye çıktı. Hepsi bütün koşuların en kötüsünün (11,8) altında kalıyor.

**Bulgu 20B: E rampada ofset sanmayı çözüyor, ama bazı yanlış alarmları hiç bırakamıyor.**
- **Kazanç (19F'nin hedefi):** day-cycle / renkli kapsama %77 → %88 (arızalı kanalda ofset olayı 0,8 → 0); T9 / beyaz %92 → %97 (1,0 → 0).
- **Basamak arızaları artık ofset olayı:** accel-step ve T2 / beyazda alarm kapsaması düşüyor (%99 → %85, %98 → %62), toplam kapsama aynı kalıyor ya da artıyor. Kanal kalıcı sapmayı yaklaşık bir saat sonra ofset olayı olarak raporluyor; bu, §15'teki karara uygun davranış.
- **Bedel 1, bırakılamayan yanlış alarmlar:** E olan iki varyantta 10/saat'i aşan koşu sayısı 0–1'den 7–8'e çıkıyor. Bunlar birkaç tohumda yoğunlaşıyor:
  - geliştirme kümesinde tek bir tohum (beyazda 9, renklide 8), arızasız senaryolar dahil hepsinde aynı değer (35,1 ve 32,7/saat). Yani yanlış alarm senaryonun arızasından değil, o tohumun sağlıklı bir kanalından geliyor;
  - bu koşularda ısıtıcı penceresinde (ısıtıcı açıkken ve sonraki soğuma süresince) herhangi bir sensörde alarm olan blok sayısı 25 (v9noE'de 0). Alarm ısıtıcı penceresine de yayılıyor, ama ısıtıcıdan önce başlıyor (20D). T1 tohum 108'de bu sayı 0, çünkü oradaki ısıtıcı arıza başladıktan sonra geliyor ve ölçüt arızalı dönemi saymıyor;
  - kullanılmış kümede T6 tohum 103 (53,5) ve T1 tohum 108 (46,9).
  - Renkli gürültüde yanlış alarm medyanı da 0,1'den 0,9/saat'e çıkıyor.
- **Bedel 2, yavaş kayma ofset sanılıyor:** T10 / renklide (gx, 0,015 °/s/saat) kapsama %91 → %86, arızalı kanalda ofset olayı 0 → 0,3. Kayma hızı renkli dMin'in (gx 0,0116) yalnız ~1,3 katı; duman testinde işaretlenen risk gerçekleşti.
- **Mekanizma doğrulanmadı.** Tahmin (H2): dMin yalnız sensör gürültüsünden türetiliyor, donmuş modelin sıcaklıkla büyüyen tahmin hatasını içermiyor. Isıtıcı gibi bir sıcaklık değişiminde sağlıklı kanalın artığında da bir eğim oluşuyor; eğim dMin'den büyük olduğu için "kayma yok" hiçbir zaman gösterilemiyor ve alarm sürüyor. Büyüme testi aynı alarmı (z büyümediği için) bırakıyordu.

**Bulgu 20C: Kuralın dışında kalan bir gözlem: v9noE iki eşiği de geçiyor.** (Sonuç sonrası gözlem; G1 kararını değiştirmez.)
- v9noE, v6'ya karşı: beyaz en kötü 3,8 / 51,6, kapsama %96,9 / %89,3; renkli en kötü 11,8 / 13,6, kapsama %81,0 / %79,7; tespit eşit. 2. adımın (b) şartını iki gürültü tipinde de sağlıyor.
- Kural onu seçemiyor: 1. adım bir ablasyonu yalnız "hiçbir yerde kötü değilse" seçiyor; v9noE 54 hücrede iyi, 20'sinde kötü (çoğu E'nin kazandırdığı rampa hücreleri).
- **Kuraldaki zayıflık:** 1. adım asimetrik. Tam sürüme karşı açıkça daha iyi bir ablasyon tek bir kötü hücre yüzünden elenebiliyor. §18'deki "önceki sürümle karşılaştırma yok" eksiği gibi bu da kuralın bir açığı. Kural, bir sonraki koşudan önce ve sonuç görmeden düzeltilecek.
- v9noE'nin geliştirme kümesindeki sayıları artık görülmüş sayıları. Onu seçmek bir sonuç sonrası karar olur; asıl sınavı ancak yeni ayrılmış küme olabilir.

**Sonraki adım için öneri:**
1. **Kısa tanı (H2):** [`g1_diag_v9.m`](matlab/g1/v9/g1_diag_v9.m). E'nin yanlış alarm kuyruğundaki dört koşu (geliştirme beyaz tohum 9, renkli tohum 8, T6 tohum 103, T1 tohum 108) ve T10 / renklideki ofset olayları. Hangi kanal, ne zaman donuyor; eğim, se ve dMin oranı; artık sıcaklığı izliyor mu; v9noE'de aynı alarm büyüme testiyle mi bırakılıyor. Okuma kuralı (H2 / H3 / açıklanamadı) betiğin başında, sonuçlardan önce commit edildi. Tanı izi için dedektöre yalnız `trace` açıkken dolan çıktılar eklendi; davranış değişmedi, betik bunu ayrıca denetliyor.
2. **v10:** Tanıya göre ya dMin'e donmuş modelin tahmin hatasından gelen bir eğim payı eklenir (E kalır, rampa kazancı korunur), ya da v10 = v9noE olur. İki durumda da 1. adım önce düzeltilir ve geliştirme sayıları görülmüş sayılır; karar yeni ayrılmış kümede verilir.

### 20 (devam). Tanı: E'nin bırakamadığı alarmlar ve T10'daki ofset olayları

**Script:** [`matlab/g1/v9/g1_diag_v9.m`](matlab/g1/v9/g1_diag_v9.m) · **Çıktı:** [`g1_diag_v9_output.txt`](matlab/g1/v9/g1_diag_v9_output.txt)

Kullanıcı koştu. Okuma kuralı sonuçlardan önce commit edildi (14056c3). Kontroller:
- İz açıkken ve kapalıyken durum ve skor birebir aynı (fark 0).
- Betiğin hesapladığı yanlış alarm oranları CSV ile aynı (35,1 / 32,7 / 53,5 / 46,9; v9noE 2,7 / 0,2 / 0,3 / 0,6).

**Bulgu 20D: Kurala göre H2 dört koşunun üçünde geçerli; dördüncüsü "açıklanamadı". H2 bu yüzden 20B'nin mekanizması olarak kabul edilmiyor.**

| Koşu | Kanal | Alarm süresi | Nasıl bitti | Eğim ≥ dMin olan değerlendirme | Eğim / dMin (medyan) | Artık–sıcaklık R² | Büyüme testi bırakırdı | Kural |
|---|---|---|---|---|---|---|---|---|
| geliştirme base / beyaz, tohum 9 | mz | 222 dk | ofset olayı | %94 | 3,1 | 0,73 | 18 dk sonra | açıklanamadı |
| geliştirme base / renkli, tohum 8 | gx | 206 dk | ofset olayı | %98 | 2,4 | 0,97 | 1 dk sonra | H2 |
| T6 / beyaz, tohum 103 | ax | 329 dk | CUSUM düştü | %99 | 65 | 1,00 | 3 dk sonra | H2 |
| T1 / beyaz, tohum 108 | ax | 293 dk | CUSUM düştü | %100 | 96 | 0,99 | 1 dk sonra | H2 |
| kontrol: base / beyaz, tohum 0 | — | 30 bloktan uzun alarm yok | | | | | | |

- Dört koşuda da E'yi geçirmeyen şey eğimin kendisi; belirsizlik (t·se) değil. **H3 hiçbir koşuda geçerli değil.**
- Dört koşuda da büyüme testi aynı kanalı 1–18 dakika içinde bırakırdı. v9noE gerçekten bırakıyor (en fazla 17 dk) ya da kanalı hiç işaretlemiyor.
- Tek sapma beyaz tohum 9: eğim ve büyüme testi şartları sağlanıyor, ama artık sıcaklığı yalnız R² = 0,73 ile izliyor (eşik 0,8). Kural gereği "açıklanamadı".
- T6 ve T1'de artığın sıcaklığa göre eğimi 0,13 ve −0,17 mg/°C. Bu, donmuş modelin sıcaklık katsayısının büyük ölçüde yanlış olduğu anlamına geliyor. Eğim dMin'in 65–96 katı; küçük bir model hatası payı bunu kapatamaz.

**Sonuç sonrası gözlem (kural dışı, işaretli):**
- Dört alarm da puanlanan pencerenin ilk bloğunda (1,68 saat) başlıyor. Yani kanallar pencere başlamadan önce işaretlenmiş; asıl başlangıç anı bu betikte ölçülmedi.
- Geliştirme kümesindeki iki koşu, 10F'deki **baştan kilitlenen kanalların** ta kendisi: beyaz tohum 9'da mz, renkli tohum 8'de gx. v5'teki büyüme testi (C) bu kilitleri serbest bırakarak çözmüştü (§12). E, büyüme testinin yerini aldığı için bu güvenlik kapısını kapattı ve eski kilitler geri döndü.
- Yani E'nin sorunu küçük ve birikimli bir model hatası değil, **model tanımlanmadan dondurulmuş kanallar**. Böyle bir kanalın artığı sıcaklıkla birlikte hareket ediyor. Rampada bu durum gerçek bir kaymadan ayırt edilemiyor, çünkü sıcaklık zamanla doğrusal değişirken "sıcaklık katsayısı hatası" ve "kayma" aynı eğimi üretiyor (tanınabilirlik, 6F ile aynı aile). E rampada "kayma yok"u yapısı gereği kanıtlayamıyor.

**Bulgu 20E: T10'da kuralın şartı sağlandı, ama kuralda yazılı yorum verilere uymuyor.**

| Tohum | Ofset olayı | O andaki eğim (gerçek kaymaya oranı) | t·se | Pencere |
|---|---|---|---|---|
| 101 | 3,02 saat | 0,0024 (0,16×) | 0,0031 | 30 blok |
| 101 | 4,33 saat | 0,0056 (0,37×) | 0,0058 | 30 blok |
| 104 | 2,91 saat | 0,0058 (0,39×) | 0,0034 | 30 blok |
| 100 (kontrol) | yok | en iyi (|eğim| + t·se) / dMin 1,01 | | |

- Gerçek kayma hızı 0,015 °/s/saat, dMin 0,0116. Üç bırakmada da eğim tahmini dMin'in altında, yani kuralın şartı sağlandı.
- Kuralda yazılı yorum "dMin, G1'in yakalaması gereken en küçük kaymaya çok yakın" idi. Veriler buna uymuyor. Tahminler gerçeğin 0,16–0,39 katı ve |eğim| + t·se en fazla 0,011. dMin gerçek kayma hızına (0,015) eşit olsaydı bile kanal bırakılırdı.
- **Sonuç sonrası yorum:** Bırakmaların hepsi en kısa pencerede (30 blok, yani kanal donduktan hemen sonraki ilk değerlendirme) ve sıcaklık sabitken (aralık 0,00 °C) oluyor. Eğim tahmininin gerçekleşen hatası (~0,009–0,013) t·se'nin (~0,003–0,006) 2–4 katı. Renkli gürültüde artıklar ilişkili ve en küçük kareler se'si (bağımsız artık varsayımıyla) belirsizliği olduğundan küçük gösteriyor. Bu, 10F'deki "ilişkili artık ARL0 hesabını geçersiz kılıyor" sorununun eşdeğerlik testindeki karşılığı.

**Tanının sonucu:**
- E iki ayrı nedenle güvenilmez:
  1. Rampada tanımlanmamış bir modeli kaymadan ayıramıyor ve 10F'nin kilitlerini geri getiriyor (20D).
  2. Renkli gürültüde kısa pencerede kendinden fazla emin (20E).
- E'yi onarmak için hem sıcaklık katsayısı belirsizliğinin hem de artık ilişkisinin teste girmesi gerekiyor. İkisi de yeni tasarım demek. Üstelik görülmüş bir geliştirme kümesinde ayarlanacaklardı.
- **Öneri:** v10 = v9noE (= v8 − C2). E çıkar. Rampada ofset sanma sorunu (19F; day-cycle ve T9 / renkli) açık konu olarak kalır; v9noE'de bu sorun eşiklerin içinde.

---

## 21. G1 v10 ve ikinci ayrılmış küme (önceden ilan)

**Durum:** Bu bölüm, v10, ayrılmış küme, ölçütler ve iki karar kuralı, **bu kümede hiçbir dedektör koşulmadan** yazılıp commit'lendi. Kullanıcı v10 = v9noE kararını §20'den sonra verdi.

**Scriptler:** [`g1_detect_v10.m`](matlab/g1/v10/g1_detect_v10.m) · [`g1_scenarios_test2.m`](matlab/g1/test2/g1_scenarios_test2.m) (küme üreteci) · [`g1_smoke_test2.m`](matlab/g1/test2/g1_smoke_test2.m) (ön kontroller) · [`g1_acceptance_test2.m`](matlab/g1/test2/g1_acceptance_test2.m) (tek atışlık test)

**v10:** `g1_detect_v9`'un büyüme testli ve C2'siz hâli, yani v9noE'nin işlem işlem aynısı: v6 (A, B, C1) + D1 + R. E çıkarıldı (20D, 20E). v10 v9 koşusundan sonra seçildiği için geliştirme sayıları görülmüş sayılıyor. Kararı yalnız bu küme veriyor.

**Neden yeni bir küme:** §13'teki küme görüldü (v5'te), dört sürümdür kullanılmış küme olarak koşuluyor. Yeni küme üç şeyi sınıyor:
1. **Seçilmemiş senaryolar.** Senaryolar elle yazılmadı. Her tohum (200–299) ilan edilen aralıklardan kendi rastgele akışıyla (tohum 50000 + s) bir senaryo çekiyor. Bu tohumlar daha önce hiç kullanılmadı (geliştirme 0–9, kullanılmış küme 100–119, tanı 300–309).
2. **Modellenmemiş üçüncü histerezis biçimi (19D):** Prandtl–Ishlinskii operatörü, yani farklı genişlikte iki play operatörünün ortalaması. G1 yalnız tek play ve gevşeme biçimlerini tanıyor. Bu, R'nin biçime aşırı uyup uymadığını gösterecek tek sınav.
3. **BME688 için farklı termal yol (15A):** Koşuların yarısında BME yolu ikinci dereceden (iki ardışık gecikme, ikincisi 100–400 s). v6'nın sıcaklık kaynağı modeli (lead-lag) simülatörün birinci derece yapısıyla aynıydı (ADR-012).

**Simülatör değişikliği:** `thermal_node` iki isteğe bağlı alan aldı: `hystWidths` (iki ya da daha fazla genişlik: PI biçimi) ve `tau2` (ikinci gecikme aşaması). `simulate_node` bunları `hystType = "pi"`, `hystWidths` ve `bmeTau2` alanlarıyla açıyor. İkinci derece yolda ısıtıcının gerçek değer penceresi soğumayı da kapsayacak biçimde `3·(τ + τ2)` oluyor. `D.truth.Teff` eklendi (yalnız tanı için). Varsayılan, play ve gevşeme yolları değişmedi; duman testi bunu v9 CSV'sine karşı ve "iki eşit genişlikli PI = play" eşitliğiyle denetliyor.

**Küme: 10 aile × 10 tohum × 2 gürültü = 200 koşu,** hepsi 8 saat. Aile = (s − 200) mod 10.

| Aile | Sınıf | Olay |
|---|---|---|
| drift-ramp | arıza | Rastgele kanalda kayma, trapez profil |
| drift-sine | arıza | Rastgele kanalda kayma, sinüs profil |
| step | arıza | Rastgele kanalda basamak (ofset) |
| slow | yavaş | Sabit sıcaklıkta yavaş kayma (K2d), jiroskop ya da ivmeölçer |
| two-faults | arıza | İki farklı algılama elemanında iki kayma, en fazla 30 dk arayla |
| clean | yok | Arıza yok |
| heaters | yok | Arıza yok, üç ısıtıcı patlaması |
| emi | yok | Manyetometrede EMI |
| bme-drift | yok | BME688 sıcaklığında kayma |
| bme-step | yok | BME688 sıcaklığında basamak |

**İlan edilen aralıklar** (her biri düzgün dağılımdan; işaretler rastgele):
- **Profil:** trapez (taban 15–30 °C, fark 8–18 °C, rampa 5–15 °C/saat, ilk plato 0,75–1,5 saat, üst plato 1–2,5 saat) ya da sinüs (ortalama 20–32 °C, genlik 4–10 °C, periyot 2–6 saat, rastgele faz). drift-ramp ve drift-sine aileleri biçimi sabitliyor, diğerleri yarı yarıya çekiyor; slow sabit 18–35 °C.
- **Isıtıcı:** 1–2 patlama (heaters ailesinde 3), her biri 10–20 dk, [1, 7,6] saatin eşit dilimlerine birer tane.
- **Histerezis (ICM):** üçte bir play (genişlik 0,5–1,5 °C), üçte bir gevşeme (τ 90–600 s), üçte bir PI (genişlikler 0,2–0,6 ve 1,0–2,0 °C).
- **BME yolu:** yarı yarıya birinci derece ya da ikinci derece (τ2 100–400 s).
- **Kayma büyüklüğü:** jiroskop 0,02–0,04 °/s/saat, ivmeölçer 0,3–0,6 mg/saat, manyetometre 0,3–0,6 µT/saat; başlangıç 2,5–5,5 saat.
- **Basamak:** jiroskop 0,02–0,05 °/s, ivmeölçer 0,2–0,5 mg, manyetometre 0,5–1,5 µT; başlangıç 2,5–5,5 saat.
- **Yavaş kayma:** jiroskop 0,015–0,025 °/s/saat, ivmeölçer 0,22–0,35 mg/saat (renkli Allan uyumunun 5·K·√1 saat değerinin yaklaşık 1,1 katı ve üstü); başlangıç 1,5–3 saat.
- **EMI:** başlangıç 2–5 saat, süre 10–40 dk, eksen başına genlik 0,5–2 µT.
- **BME arızası:** kayma 0,5–2 °C/saat ya da basamak 0,5–2 °C; başlangıç 2,5–5,5 saat.

**Puanlama (§11'den farkları, çok durumlu çıktı nedeniyle; v6–v9 geliştirme koşularındaki tanımlarla aynı):**
- Yanlış alarm = arızasız kanalda 1. durum (EMI sırasında manyetometre hariç). Arızasız kanaldaki bir ofset olayı yanlış alarm **olayı** sayılıyor (K1c).
- Bir basamak arızası, ilk ofset olayından itibaren raporlanmış sayılıyor (§15 kararı). Gecikme, başlangıçtan sonraki ilk 1. durum.
- K2a, K2b, K2c ve K2d **arıza başına** hesaplanıyor (two-faults'ta iki arıza ayrı sayılıyor). Tespit edilmeyen arıza K2a'da kaçırılmış sayılıyor.
- Puanlama penceresi iki dedektör için ortak (v0'ın penceresiyle kesişim).

**Ölçütler (her gürültü tipi için ayrı ayrı):** K1a–K3f §11'deki eşiklerle aynı. Yeni ölçüt:
- **K4:** Arızalı blokların "güvenilmez" (3. durum) payı, ortalama ≤ %10. Gerekçe: 19E'de C2'nin gerçek arızaları yuttuğu görüldü; bir dedektör arızayı "güvenilmez" diyerek saklayıp kapsama ölçütünden kaçamamalı. v10'da C2 kapalı olduğu için bu ölçüt v10 için kendiliğinden sağlanıyor; v6 için bağlayıcı.

**Ölçüt ile tasarım tutarlılığı (13E'deki hatanın tekrarlanmaması için, ilan sırasında kontrol edildi):**
- K3c: EMI en geç 5,67 saatte bitiyor, sonrasında en az 2,3 saat var. Olay sonu bırakması (B) tepe |z| ≥ 10 ve 5 sessiz blok istiyor; 0,5 µT'lik EMI manyetometre gürültüsünün çok üstünde. %10'a ulaşılabilir.
- K2a: Arızalar en geç 5,5 saatte başlıyor, 120 dk'lık pencere koşunun içinde kalıyor. K2d: yavaş kaymalar en geç 3 saatte başlıyor, 180 dk sığıyor.
- K2b: geliştirmede v9noE'nin medyanları 5,5 / 25,5 dk; eşikler 15 / 40 dk.

**Karar 1, G1 dedektörü** (v8/v9 koşularındaki 2. adımla aynı kural, bu kez ayrılmış veride). v10, v6'nın yerini yalnız şu iki şart birlikte sağlanırsa alıyor:
- (a) aile × gürültü hücreleri (20) × 13 ölçütte, kötü olduğu hücreden çok iyi olduğu hücre var;
- (b) iki gürültü tipinde de, bütün koşular üzerinden: en kötü yanlış alarm ≤ v6, ortalama kapsama ≥ v6 − 1 puan, ortalama tespit ≥ v6.

**Karar 2, kabul:** G1'in simülasyon aşaması, karar 1'in seçtiği dedektör K1a–K4'ün **hepsini** iki gürültü tipinde de geçerse kapanıyor. Ölçüt tablosu iki dedektör için de yazdırılıyor.

**Duman testi** ([çıktı](matlab/g1/test2/g1_smoke_test2_output.txt), kullanıcı koştu; ayrılmış kümede hiçbir dedektör sonucu yazdırmıyor):
- v10 ve v6, v9 CSV'sindeki v9noE ve v6 satırlarını 3,6·10⁻¹⁴ farkla tekrarlıyor (dört koşu; gevşeme yolu dahil). Simülatör yolları değişmedi, v10 = v9noE.
- İki eşit genişlikli PI, play ile bit düzeyinde aynı (fark 0).
- Çekilen 100 senaryo ilan edilen aralıklarda. Biçimler: play 36, gevşeme 36, PI 28; ikinci derece BME yolu 48 senaryoda. Ortam sıcaklığı 1,3–45,2 °C, geliştirmedekinden (20–40 °C) geniş. Büyük τ'lu gevşemede ICM'nin histerezis sapması 1,2 °C'ye çıkıyor.
- Her aileden bir senaryo simülatörde ve iki dedektörde hatasız koştu.

**Sonuç ne olursa olsun:**
- Koşu bir kez yapılıyor. Kalan ölçüt yazılıyor, iddianın kapsamı daraltılıyor. Bu kümeye bakarak ayar yapılmıyor ve küme bundan sonra kullanılmış sayılıyor.
- İzin verilen tek müdahale, dedektörün mantığını değiştirmeyen hata düzeltmesi.
- Aile, histerezis biçimi ve BME yolu kırılımları yalnız betimleyici. Karar onlarla verilmiyor, ama bir ölçüt kalırsa nedenini onlar gösterecek (örneğin PI biçiminde K1b kalırsa R biçime aşırı uymuş demektir).

### 21 (sonuç). İkinci kabul testi: G1 = v10, kabul FAIL

**Script:** [`g1_acceptance_test2.m`](matlab/g1/test2/g1_acceptance_test2.m) (ee988b4'teki ilan edilmiş hâliyle, değiştirilmeden) · **Çıktı:** [`g1_acceptance2_output.txt`](matlab/g1/test2/g1_acceptance2_output.txt) · **Ham sonuçlar:** [`g1_acceptance2_runs.csv`](matlab/g1/test2/g1_acceptance2_runs.csv), [`g1_acceptance2_faults.csv`](matlab/g1/test2/g1_acceptance2_faults.csv)

Kullanıcı bir kez koştu (200 koşu × 2 dedektör, ~20 dk). Hata düzeltmesi gerekmedi. Küme artık kullanılmış sayılıyor.

**Karar 1: G1 dedektörü artık v10.**
- (a) v10, 87 hücrede iyi / 12'sinde kötü → geçti.
- (b) beyaz: en kötü 31,6 / 161,4, kapsama %97,6 / %78,6, tespit %100 / %100 → geçti.
- (b) renkli: en kötü 12,8 / 33,8, kapsama %81,5 / %70,0, tespit %100 / %100 → geçti.

**Karar 2: Kabul FAIL.** v10 beyazda 14 ölçütün 10'unu, renklide 12'sini geçiyor (v6: 5 ve 9).

| Ölçüt | v10 beyaz | v10 renkli | v6 beyaz | v6 renkli |
|---|---|---|---|---|
| K1a yanlış alarm medyanı ≤ 0,5/saat | ✅ 0,00 | ✅ 0,00 | ✅ 0,32 | ✅ 0,00 |
| K1b her koşu ≤ 6/saat | ❌ 31,6 | ❌ 12,8 | ❌ 161,4 | ❌ 33,8 |
| K1c yanlış alarm olayı ≤ 0,12/saat | ❌ 0,194 | ✅ 0,071 | ❌ 2,06 | ❌ 0,141 |
| K2a 120 dk içinde tespit ≥ %95 | ✅ %100 | ✅ %100 | ✅ %100 | ✅ %98 |
| K2b gecikme medyanı (≤ 15 / ≤ 40 dk) | ✅ 4,4 | ✅ 16,0 | ✅ 4,6 | ✅ 13,9 |
| K2c kapsama ≥ %80 | ✅ %97,7 | ✅ %81,8 | ❌ %66,0 | ❌ %61,0 |
| K2d yavaş kayma, 180 dk içinde ≥ %80 | ✅ %100 | ✅ %100 | ✅ %100 | ✅ %100 |
| K3a ısıtıcı ≤ 1 blok/koşu | ❌ 1,08 | ✅ 0,74 | ❌ 9,21 | ✅ 0,84 |
| K3b olay dışı "T src" ≤ 1 blok/koşu | ❌ 19,1 | ❌ 19,1 | ❌ 19,1 | ❌ 19,1 |
| K3c EMI sonrası ≤ %10 | ✅ %0,0 | ✅ %0,0 | ✅ %2,6 | ✅ %0,4 |
| K3d BME arızasında hareket kanalı ≤ %5 | ✅ %2,6 | ✅ %1,0 | ❌ %12,2 | ✅ %1,1 |
| K3e BME arızasında ICM ≤ %5 | ✅ %0,0 | ✅ %0,2 | ✅ %1,7 | ✅ %0,3 |
| K3f BME veya belirsiz ≥ %90 | ✅ %98,2 | ✅ %98,0 | ✅ %96,6 | ✅ %98,0 |
| K4 arızalı blokların "güvenilmez" payı ≤ %10 | ✅ %0 | ✅ %0 | ❌ %14,1 | ✅ %6,7 |

**Bulgu 21A: v10'un geliştirmedeki üstünlüğü görülmemiş senaryolarda daha da büyüyor.** Geliştirmede v10 (v9noE) ile v6 arasındaki en kötü koşu farkı 3,8'e 51,6 idi; burada 31,6'ya 161,4.
- 6/saat'i aşan koşu: v10'da 11 (9 beyaz, 2 renkli), v6'da 38 (32 beyaz, 6 renkli), 200'er koşudan.
- **Tespit tarafının hepsi geçti:** K2a–K2d iki gürültüde de geçiyor, beyaz kapsama %97,7. two-faults kapsaması %98 / %86 (v6: %34 / %39); 19E'deki C2 sorunu ayrılmış kümede de doğrulandı.
- **Tuzakların çoğu geçti:** EMI sonrası %0 (13E'deki ölçüt sorunu olay sonu bırakmasıyla çözülmüş görünüyor), BME arızası ölçütleri (K3d–K3f) ikinci derece BME yolunda da geçiyor.
- **v6 bu kümede çöktü:** gevşeme biçiminde beyaz en kötü 161,4/saat, kapsama %69. Izgara dışı τ ve büyük histerezis sapmaları R'siz bir dedektör için §13'teki T9'dan çok daha ağır.

**Bulgu 21B: K1b'nin kuyruğu üç kaynaktan geliyor; yalnız biri önceden öngörülmüştü.** v10'un 6/saat'i aşan 11 koşusu (betimleyici, sonuç sonrası):
- **Izgara dışı uzun τ'lu gevşeme (5 koşu, τ 541–593 s):** 22,3 / 6,8 / 31,6 / 15,6 beyaz, 8,8 renkli. 19G bunu öngörmüştü: τ = 600'de D1'li v8'in en kötü koşusu 16,3, D1'siz noD1'in 3,3 idi. Bu kuyruk D1'in bedeli olabilir; doğrulanmadı.
- **PI biçimi (3 koşu):** 13,1 / 8,8 / 30,6 beyaz. İlan edilen yorum ("PI'de K1b kalırsa R biçime aşırı uymuş demektir") şartı sağlandı: PI / beyaz en kötü 30,6. Ama kuyruk PI'ye özgü değil. PI'nin ortalama kapsaması %99 / %82 ve renkli en kötüsü 5,8; ayrıca modellenen play biçiminde de 23,7'lik bir koşu var. Yani "biçime aşırı uyum" bu kuyruğun **tek** açıklaması olamaz.
- **Play biçimi (3 koşu):** heaters-236 / beyaz 23,7, clean-205 / renkli 12,8, heaters-216 / beyaz 6,2. Dedektörün modellediği biçimde kuyruk olması, histerezis dışında bir mekanizmaya işaret ediyor (adaylar: ısıtıcı, 10F tipi baştan kilitlenme). Doğrulanmadı.
- Uzun τ'lu gevşeme koşuları çıkarılsa da K1b kalırdı (beyaz 30,6, renkli 12,8).

**Bulgu 21C: K3b iki dedektörde ve iki gürültüde birebir aynı (19,1). Kaynak, ortak sıcaklık kaynağı modeli.**
- "T src" alarmı yalnız sıcaklık okumalarına bakıyor ve v6 ile v10'da aynı model (A, lead-lag) kullanılıyor. Aynı tohumda sıcaklıklar gürültüden bağımsız olduğu için değerin aynı çıkması bekleniyor (13D ile aynı imza).
- Olay dışında alarm 12 senaryoda var (100'den), koşu başına 55–294 blok. 7'si ikinci derece BME yolunda, 5'i birinci derecede. Yani tek neden ikinci derece yol değil. Mekanizma doğrulanmadı.
- K3a / beyaz (1,08) sınırda kalıyor. Isıtıcı penceresinde alarmın en yüksek olduğu iki koşuda (heaters-216 ve heaters-286) "T src" alarmı da var (155 ve 153 blok).

**Bulgu 21D: K1c / beyaz (0,194) aileye yayılmış.** En yüksekleri emi (0,43), drift-ramp (0,35), step ve bme-drift (0,28). Tek bir senaryo sınıfından gelmiyor.

**Genel değerlendirme:**
- G1 dedektörü v10. Simülasyon aşaması kapanmadı. Kalan dört ölçüt: K1b (iki gürültü), K1c (beyaz), K3a (beyaz, sınırda), K3b (iki gürültü, ortak sıcaklık kaynağı modeli).
- **İddia kapsamı:** "v10, daha önce görmediği ve elle seçilmemiş senaryolarda, modellenmemiş bir histerezis biçimi ve farklı bir BME termal yolu altında da kayma ve basamak arızalarını gecikme ve kapsama ölçütlerinin hepsini geçerek tespit ediyor; tipik koşuda yanlış alarm üretmiyor." Sınırlama olarak yazılacaklar: en kötü koşuda yanlış alarm kuyruğu (yaklaşık 20 koşudan biri), ızgara dışı uzun τ'lu gevşeme, sıcaklık kaynağı modelinin olay dışı alarmları.
- Bu kümeye bakarak ayar yapılmayacak. Sonraki adım tanı: K3b gürültüden bağımsız olduğu için tek tohumla incelenebilir (13D'deki yol); K1b kuyruğu için D1'in uzun τ'daki bedeli ve play'deki iki ısıtıcı koşusu. Tanıdan çıkan yeni bir sürüm, ancak üçüncü bir ayrılmış kümeyle sınanabilir.

## 22. Tanı: ikinci kabul testindeki "T src" alarmları (21C)

**Script:** [`matlab/g1/v10/g1_diag_tsrc2.m`](matlab/g1/v10/g1_diag_tsrc2.m) · **Çıktı:** [`g1_diag_tsrc2_output.txt`](matlab/g1/v10/g1_diag_tsrc2_output.txt) · **Figür:** [`g1_diag_tsrc2.png`](matlab/figures/g1_diag_tsrc2.png)

**Ne yapıyor ve neden:** K3b'nin 19,1'lik değeri, 100 senaryonun 12'sindeki olay dışı "T src" alarmlarından geliyor. Bu değer v6'da ve v10'da, beyaz ve renkli gürültüde aynı. İki dedektör de aynı sıcaklık kaynağı modelini (`g1_tsrc_v6.m`, lead-lag, ızgara payı yok, donmuşken büyüme yok) çağırıyor ve bu model yalnız sıcaklıkları okuyor. Bu yüzden betik modeli doğrudan çağırıyor ve yalnız beyaz gürültüyü simüle ediyor. Dedektör koşulmuyor. Küme kullanılmış durumda; buradan çıkan hiçbir şey kabul sonucunu değiştirmiyor.

**Önceden ilan edilen hipotezler** (betik koşulmadan commit'lendi):
- **H1, ısıtıcı tetikliyor (14B'nin benzeri):** Isıtıcı |zT|'yi kapının dışına itiyor, model güncellemeyi durduruyor ve gerçek ısıtıcı penceresi bittikten sonra geri dönmüyor. Bir koşu için doğrulanmış sayılır, eğer (a) aynı koşu ısıtıcısız (`heaterOn = []`) yapıldığında BME arızası dışında alarm kalmıyorsa **ve** (b) son güncelleme ile ilk olay dışı alarm arasında bir ısıtıcı darbesi varsa.
- **H2, ikinci derece BME yolu (yapı uyuşmazlığı, ADR-012):** Lead-lag yapısı yalnız birinci derece BME yolu için kesin. `bmeTau2 > 0` olan bir koşu için doğrulanmış sayılır, eğer aynı koşu `bmeTau2 = 0` ile yapıldığında ısıtıcı penceresi ve BME arızası dışında alarm kalmıyorsa.
- **H3, ikisi de değil:** Isıtıcısız ve birinci derece yolla da alarm kalıyorsa koşu "açıklanamadı" olarak raporlanır. İlk alarmın bağlamı (profil evresi, değişim hızı, güncelleme boşluğu) verilir.
- H1 ve H2 aynı koşuda birlikte doğrulanabilir. Alarmları yalnız ikisinin birlikte kaldırıldığı karşı-olgusal siliyorsa koşu "H1+H2 birlikte" diye raporlanır.

**Adımlar:**
1. **Kopya kontrolü:** Her senaryoda (tohum 200–299) ısıtıcı penceresi ve BME arızası dışındaki alarmlar, kabul testinin puanlama penceresinde (blok > ısınma ve v0 geçerli) sayılır. Bu sayı `g1_acceptance2_runs.csv`'deki v10 / beyaz `tSrcFlagsOutside` ile birebir aynı olmalı. Koşu başına ayrıca şunlar verilir: betimleyici model varyantlarının sayıları (noGate: her blokta güncelle, frozenFloor, gridErr), en uzun kesintisiz alarm, ilk alarm, ondan önceki güncellemesiz blok sayısı, ve bu boşlukta ısıtıcı olup olmadığı.
2. **Karşı-olgusallar:** Alarmlı her koşu için ısıtıcısız, `bmeTau2 = 0` (yalnız > 0 olanlarda) ve ikisi birlikte. Hüküm yukarıdaki kurallarla verilir.
3. **Bağlam:** İlk alarmın çevresindeki bloklar (eT, sT, zT, seçilen gecikme, b, c) ve alarmlı her koşu için sıcaklık ve zT figürü.

### 22 (sonuç)

Kullanıcı bir kez koştu (~7 dk + karşı-olgusallar). Betik değiştirilmedi.

**Hükümler (ilan edilen kurala göre):**

| Koşu | τ2 [s] | Alarm | Isıtıcısız | τ2 = 0 | İkisi | Hüküm |
|---|---|---|---|---|---|---|
| step-212 | 370 | 55 | 0 | 0 | 0 | H1 ve H2 |
| heaters-216 | 131 | 155 | 0 | 174 | 0 | H1+H2 birlikte (ısıtıcısız 0, ama boşlukta ısıtıcı yok) |
| drift-ramp-220 | 235 | 272 | 0 | 289 | 0 | H1 |
| emi-227 | 377 | 139 | 139 | 0 | 0 | H2 |
| clean-235 | 0 | 289 | 0 | – | – | H1 |
| step-242 | 0 | 194 | 0 | – | – | H1 |
| emi-257 | 361 | 165 | 165 | 0 | 0 | H2 |
| two-faults-264 | 286 | 294 | 0 | 317 | 0 | H1 |
| bme-step-269 | 0 | 43 | 1 | – | – | H3 |
| drift-ramp-270 | 359 | 150 | 150 | 0 | 0 | H2 |
| heaters-286 | 0 | 153 | 0 | – | – | H1 |
| bme-step-289 | 0 | 1 | 1 | – | – | H3 |

**Bulgu 22A: Kopya birebir.** 100 koşunun 100'ünde alarm sayısı kabul CSV'si ile aynı. Yani K3b'nin tamamı `g1_tsrc_v6`'dan geliyor; dedektörlerin geri kalanı katkı vermiyor.

**Bulgu 22B: H1 doğrulandı (5 koşu, artı step-212'de H2 ile birlikte). Mekanizma 14B'den farklı: ısıtıcı penceresinde tek bir "geri giriş" güncellemesi.** Bağlam tablolarında hep aynı sıra görülüyor (drift-ramp-220, clean-235, step-242, heaters-286, two-faults-264):
1. Isıtıcı |zT|'yi kapının dışına itiyor, model donuyor. Buraya kadar beklenen davranış.
2. Model donukken sT büyüyor: 0,06 → 0,36 °C (step-242), 0,02 → 0,39 (two-faults-264). Neden: x = [1; L − L0; dL/dt] rampada öğrenilmiş bölgeden uzaklaşıyor ve parametre belirsizliği x'Px büyüyor. two-faults-264 ve bme-step-269'da ısıtıcı başlangıç platosuna denk geliyor, orada öncü terim c hiç öğrenilmemiş (öncül std 300 s). Rampa başlayınca dL/dt × P_cc sT'yi şişiriyor.
3. Isıtıcının kalıntısı hâlâ duruyorken (eT 0,25–1,35 °C, gerçek ısıtıcı penceresi hâlâ açık) |zT| bir blok için 3'ün altına iniyor: 1,9 / 2,5 / 2,6 / 2,7. Bu tek güncelleme büyük bir adım atıyor, çünkü P büyük ve hata büyük. Örnekler: b 0,995 → 1,234 (step-242), b 1,095 → 1,259 (drift-ramp-220), c 0 → 833 s (two-faults-264). Seçilen gecikme de sıçrıyor.
4. Yeni model yanlış ama kendinden emin: sT ~0,03'e iniyor, |zT| 10–36. Model saatlerce kilitli kalıyor (ilk alarmdan sonra 380 bloktan 20–180'inde güncelleme var).
- Kapı, kendi belirsizliği şiştiği anda kirli bir bloğu içeri alıyor. Bu durum, belirsizlik arttıkça kapının gevşemesinin bedeli. 14B'de ise sorun kısa rampada öğrenilmiş bir eğimdi.
- **heaters-216 (sonuç sonrası okuma):** Kural "boşlukta ısıtıcı yok" dediği için H1 sayılmadı. Ama aynı imza var: 135. blokta |zT| 2,9 iken (eT −3,3, sT 1,1) tek güncelleme b'yi 1,002'den 0,704'e çekiyor; c zaten 669 s, yani model daha önceki ısıtıcıda bozulmuş. Isıtıcı kaldırılınca alarm 0. Bozan güncelleme ilk alarmdan çok önce olduğu için ilan edilen "boşluk" kuralı onu göremiyor.
- **bme-step-269 (sonuç sonrası okuma):** Kurala göre H3, çünkü ısıtıcısız da 1 alarm kalıyor. Bağlamı ise H1 ile aynı: c 0 → 825 s, ısıtıcıyla 43 alarm. Kalan 1 alarm büyük olasılıkla 22D'deki sınır bloğu (doğrulanmadı).

**Bulgu 22C: H2 doğrulandı (3 koşu, artı step-212). Mekanizma 14B'nin "model hatası payı yok" sorunu.** Isıtıcı yok. Alarm, rampa sonunda ya da platoda başlıyor. eT on blokta 0,02'den 0,16 °C'ye doğrusal sürünüyor: BME'nin ikinci derece yolunun yavaş oturması. Seçilen gecikme ızgaranın ucunda (300 s); gerçek net gecikme 200 + τ2 ≈ 560–580 s. b 0,94–0,98.
- sT ≈ 0,021 °C, yani taban değerin (0,02) hemen üstünde. Kapı, hata yalnız **0,06–0,07 °C** iken kapanıyor. Ardından sürünme 5σ'yı geçiyor ve model donuk kalıyor.
- H2 yalnız τ2 ≥ 359 s olan koşularda görüldü. Bu aralıktaki 10 koşunun 4'ünde var, 6'sında yok. τ2 < 359 olan hiçbir koşuda yok. Izgara sınırı (300 s) ile ikinci derece yapı burada ayrılamıyor: τ2 = 0 ikisini birden kaldırıyor.

**Bulgu 22D: H3'teki iki koşudan biri puanlama hatası.** bme-step-289'daki tek alarm, BME basamağının kendisi (3,08 h). eT 0,57 °C, basamağın (1,72) kabaca üçte biri; sonraki blokta tam 1,72. Yani basamak bloğun ortasında başlıyor, `D.truth.tempFault = tB >= t0` ise o bloğu arıza saymıyor. Doğru bir tespit olay dışı alarm olarak sayılmış. Etkisi küçük (koşu başına en çok 1 blok, K3b'de 0,01–0,02), ama sonraki testlerde arıza başlangıcını içeren blok arızaya dahil edilmeli. Bu değişiklik kabul sonucunu geriye dönük değiştirmiyor.

**Bulgu 22E: Payların toplamı (19,1'in dağılımı).** H1 tipi (heaters-216 ve bme-step-269 dahil) 1400 blok (~%73), H2 454 (~%24), ikisi birlikte (step-212) 55 (~%3), sınır bloğu 1. Toplam 1910 = 19,1 × 100.

**Bulgu 22F (betimleyici varyantlar):**
- frozenFloor (donmuşken P büyüsün) H2 koşularını neredeyse siliyor: 139 → 9, 165 → 7, 150 → 2, 55 → 0. heaters-286'yı da siliyor (153 → 0). Ama §15'te ısıtıcıyı ve kaymayı yuttuğu görülmüştü, burada BME arızaları ölçülmedi.
- noGate çözüm değil: bazı koşuları azaltıyor, bazılarını artırıyor (heaters-286 153 → 276).
- gridErr hiçbir şeyi değiştirmiyor.

**Genel değerlendirme ve öneri (karar kullanıcının):**
- K3b iki ayrı mekanizmadan geliyor. İkisi de sıcaklık kaynağı modelinin kapı ve hata bütçesiyle ilgili; hareket kanallarıyla ilgisi yok.
- **H1 için aday düzeltme:** Geri giriş kuralı. Kapı dışına çıkmış bir model ancak art arda m blok |zT| < zU kaldıktan sonra yeniden güncellensin. Alternatif: güncelleme adımı yalnız ölçüm gürültüsüne göre sınırlansın (sağlam / Huber güncellemesi). Böylece parametre belirsizliği şiştiğinde içeri alınan tek bir blok modeli taşıyamaz.
- **H2 için aday düzeltme:** sT'ye ölçülen bir yapı uyuşmazlığı payı (§15'te kullanıcının tanımı) ve/veya daha geniş bir gecikme ızgarası. Izgarayı genişletmek, ikinci kümenin τ2 aralığına bakılarak yapılmış olur. Bu yüzden üçüncü kümede daha geniş ve farklı bir termal yapı olmalı (ADR-012).
- **Puanlama:** Arıza başlangıcını içeren blok arızaya dahil edilmeli (22D).
- Bunların hiçbiri bu kümeyle sınanamaz; üçüncü ayrılmış küme gerekiyor.

## 23. Sıcaklık kaynağı modeli için iki düzeltme: geliştirme koşusu (önceden ilan)

**Script:** [`matlab/g1/v11/g1_dev_tsrc_v11.m`](matlab/g1/v11/g1_dev_tsrc_v11.m) · **Model:** [`g1_tsrc_v6.m`](matlab/g1/v6/g1_tsrc_v6.m) (yeni anahtar 4, varsayılan kapalı) · **Puanlama:** [`g1_truth_onset.m`](matlab/g1/g1_truth_onset.m)

Kullanıcı §22'den sonra H1 ve H2 için düzeltmelerin yazılmasına karar verdi. Bu bölüm, varyantları ve seçim kuralını sonuçlardan önce ilan ediyor.

**Düzeltmeler:**
- **H (geri giriş beklemesi, 22B için):** Model, ısınmadan sonra kapı dışında bir blok gördüğünde, ancak art arda m blok |zT| < zU kaldıktan sonra yeniden güncelleniyor (m'inci blok dahil). İlk reddedilen bloğa kadar hiçbir şey değişmiyor. m = ⌈3 · max(τ ızgarası) / B⌉: modelin temsil edebildiği en yavaş gecikmenin üç zaman sabiti. Bu sürede o gecikmeden geçen bir bozulma ~%5'e söner. Ayar değil, ızgaradan türetiliyor. v6 ızgarasıyla m = 15, geniş ızgarayla m = 30. `reentryHold = 0` iken model v6 ile işlem işlem aynı.
- **W (geniş gecikme ızgarası, 22C için):** τ ızgarası 0:20:300 yerine 0:20:600. **Dairesellik uyarısı:** Bu aralık, ikinci kümenin net gecikmesi (≤ ~600 s) görüldükten sonra seçildi. Bu yüzden W o kümede dairesel; üçüncü kümede daha yavaş ve yapısal olarak farklı BME yolları olmalı. Bellek notu: aday sayısı 16'dan 31'e çıkıyor (ATmega328P bütçesi için sonra bakılacak).
- **HW = ikisi birlikte (aday).**
- **Puanlama (22D):** Arıza başlangıcını içeren blok artık arızalı sayılıyor (`g1_truth_onset.m`). Bu değişiklik yalnız bu bölümden sonraki betiklerde geçerli; önceki sonuçlar eski etiketleriyle kalıyor.

**Veri:** Hepsi geliştirme verisi, beyaz gürültü. Model yalnız sıcaklıkları okuyor ve sıcaklıklar gürültüden bağımsız.
- dev: `g1_scenarios_v3`, tohum 0–9 (80 koşu)
- spent1: birinci kabul kümesi, tohum 100–119 (200 koşu)
- spent2: ikinci kabul kümesi, tohum 200–299 (100 koşu). Düzeltmeler bu kümeye bakılarak tasarlandı. Bu yüzden spent2, düzeltmelerin hedeflediği şeyi yapıp yapmadığını gösterir; genellenip genellenmediğini göstermez.

**Kontroller (sonuç okunmadan önce tutmalı):**
- C1: v6 varyantı, eski etiketlerle ve kabul testinin penceresiyle, spent2'nin 100 koşusunda `g1_acceptance2_runs.csv` (v10 / beyaz) ile birebir aynı.
- C2: v6 varyantı, eski etiketlerle, dev + spent1'in 280 koşusunda `g1_dev_tsrc_v6_results.csv`'deki L varyantıyla birebir aynı.

**Ölçütler (koşu başına, yeni etiketlerle):** olay dışı alarm (K3b), ısıtıcı penceresinde alarm payı (tuzağı T-src'nin görmesi), BME arızası blok kapsaması, BME arızasından sonraki ilk alarmın gecikmesi. Betimleyici olarak ayrıca en uzun kilit ve geri tutulan blok sayısı.

**Seçim kuralı:**
- Gruplar: dev ve spent1'de senaryo, spent2'de aile. Her grup için ortalama olay dışı alarm, ortalama ısıtıcı payı, ortalama BME arızası kapsaması ve medyan gecikme hesaplanıyor.
- **Adım 1:** Aday HW. Ancak H ya da W, gruplar × ölçütler üzerinde hiçbir yerde kötü değil ve bir yerde iyiyse aday o olur.
- **Adım 2:** Aday, v6'nın yerine ancak üç kümenin **her birinde** şu koşulların hepsini sağlarsa geçer: ortalama olay dışı alarm v6'dan düşük (ya da ikisi de 0), ısıtıcı payı ≥ v6 − 0,01, BME arızası kapsaması ≥ v6 − 0,01, medyan gecikme ≤ v6 + 1 dk. Aksi hâlde v6 kalır ve başarısız kalemler raporlanır, ayarla kapatılmaz.
- K3b hedefi (koşu başına ortalama ≤ 1) her küme için raporlanıyor.

**Sonraki adım (bu koşudan sonra):** Seçilen sıcaklık kaynağı modeliyle v11 = v10 + yeni model. T-src çıktısı hareket kanallarının referans seçimini de etkilediği için (`usable`) tam dedektörün geliştirme koşusu gerekiyor. Ardından üçüncü ayrılmış küme ilan edilecek.

### 23 (sonuç)

**Çıktı:** [`g1_dev_tsrc_v11_output.txt`](matlab/g1/v11/g1_dev_tsrc_v11_output.txt) · **Ham sonuçlar:** [`g1_dev_tsrc_v11_results.csv`](matlab/g1/v11/g1_dev_tsrc_v11_results.csv) · **Figür:** [`g1_dev_tsrc_v11.png`](matlab/figures/g1_dev_tsrc_v11.png)

Kullanıcı bir kez koştu. Betik değiştirilmedi. **C1 100/100, C2 280/280 birebir.**

**Kural sonucu: sıcaklık kaynağı modeli v6'da kalıyor.**
- Adım 1: aday HW. H, 8 hücrede kötü / 6'sında iyi; W, 9'da kötü / 6'sında iyi.
- Adım 2: dev ve spent1'de HW her kalemde v6 ile aynı (ikisinde de olay dışı alarm zaten 0). spent2'de olay dışı alarm 19,44 → 0,84 (K3b hedefi ≤ 1 tutuyor), BME arızası kapsaması 0,981 → 0,983, gecikme aynı. Ama **ısıtıcı payı 0,873 → 0,851**, tolerans 0,01 aşılıyor → FAIL.

**Bulgu 23A: Düzeltmeler hedeflediği şeyi yapıyor (spent2, dairesel).**
- H tek başına ısıtıcı kilitlerini kaldırıyor: two-faults 29,5 → 0, clean 28,9 → 0, bme-step 5,4 → 0. H2 koşularına (emi 31,7) dokunmuyor.
- W tek başına H2 koşularını kaldırıyor: emi 31,7 → 0, drift-ramp-270 150 → 0. Isıtıcı kilitlerine dokunmuyor.
- İkisi birlikte (HW) 1944 bloktan 84'ü kalıyor: drift-ramp-220 39 ve heaters-216 45. İkisinde de geri tutulan blok sayısı çok yüksek (145, 149): model uzun süre kapı çevresinde gidip geliyor. Mekanizma doğrulanmadı.
- Dev ve spent1'de hiçbir şey değişmiyor. Yani düzeltmeler önceki kümelerin hiçbir koşusunu bozmuyor; ama o kümelerde sınanacak bir şey de yoktu.

**Bulgu 23B (sonuç sonrası okuma): Isıtıcı payındaki düşüşün tamamı, v6'nın kilitlendiği 11 koşudan geliyor. Bu koşularda v6'nın "ısıtıcı tespitinin" bir kısmı ters işaretli kilit alarmı.**
- v6'nın olay dışı alarm verdiği 11 koşu: ısıtıcı payı v6 0,858, HW 0,657. Kalan 89 koşu: v6 0,874, HW 0,874 (HW 3 koşuda 1 puandan fazla kötü, 5 koşuda iyi).
- Figürde step-242, two-faults-264 ve bme-step-269'da v6'nın zT'si ısıtıcı penceresinin içinde **negatif** işarete geçiyor (−20 civarı). Isıtıcı BME'yi yalnız ısıtır, yani gerçek bir ısıtıcı izi pozitif eT verir. Negatif alarmlar 22B'deki bozucu güncellemenin ürünü: kilit, ısıtıcı penceresi bitmeden başlıyor ve pencerenin kalanında "ısıtıcı tespiti" diye sayılıyor.
- HW'de ise zT ısıtıcıda pozitif tepe yapıp kuyrukta 0'a dönüyor. Kuyrukta kaçırılan bloklar gerçek ama küçük bir kalıntı (donmuş modelin sT'si büyüdükçe z eşiğin altına iniyor).
- Yani ölçüt, kilidin ısıtıcı penceresine taşan kısmını ödüllendiriyor. Bu bir ölçüt tanımı açığı: "ısıtıcı tespiti" yönden bağımsız tanımlanmış. Bu okuma sonuçlar görüldükten sonra yapıldı. İlan edilen kural geriye dönük değiştirilmiyor; karar kullanıcının.

**Bulgu 23C (betimleyici):** Koşu sonunda seçilen gecikme ikinci derece yolda medyan 280–300 s (gerçek net gecikme medyanı 447 s). Geniş ızgara koşu sonunda nadiren kullanılıyor; W'nin etkisi rampa sonrası oturma evresinde.

**Seçenekler (karar kullanıcının):**
1. **Kurala uy:** v6 kalır, v11 sıcaklık kaynağı düzeltmesi olmadan devam eder. K3b üçüncü kümede de büyük olasılıkla kalır.
2. **Ölçüt düzeltmesini ilan et, sonra yeniden puanla:** Isıtıcı tespiti yalnız pozitif yönlü alarmları (zT > +eşik) saysın. Bu tanım, sonucu görmeden önce ilan edilmiş olsaydı doğal olandı; ama şimdi sonuç sonrası olduğu için öyle etiketlenir. Kural aynen kalır, yalnız ölçüt değişir. Yeniden koşu ~35 dk.
3. Her iki durumda da asıl karar üçüncü ayrılmış kümede verilecek. Bu koşu yalnız geliştirme seçimi.

### 23b. İşaretli ısıtıcı ölçütüyle yeniden koşu (sonuç sonrası karar, önceden ilan)

**Script:** [`matlab/g1/v11/g1_dev_tsrc_v11b.m`](matlab/g1/v11/g1_dev_tsrc_v11b.m)

**Karar:** Kullanıcı 2. seçeneği seçti. **Bu karar §23'ün sonuçları görüldükten sonra verildi** ve öyle etiketleniyor.

**Tek değişiklik, ısıtıcı ölçütü:** Isıtıcı payı artık yalnız zT > 0 olan ısıtıcı penceresi alarmlarını sayıyor. Isıtıcı yalnız BME688'i ısıtır, yani gerçek bir ısıtıcı izi pozitif hata verir. §23'teki ölçüt, ısıtıcı penceresinde bozulan bir modelin (22B) ters işaretli alarmlarını da sayıyordu, yani kilidi ödüllendiriyordu. Eski ölçüt `heatDetAll` adıyla betimleyici olarak duruyor.

**Değişmeyenler:** Varyantlar, veri, diğer ölçütler, seçim kuralının iki adımı ve toleranslar §23'teki ilanla aynı.

**Kontroller:** C1 ve C2 aynen. Yeni **C3**: her varyant ve her koşu için olay dışı alarm, `heatDetAll`, BME arızası kapsaması ve gecikme, §23'ün CSV'si ile aynı olmalı (aynı kod, aynı veri).

### 23b (sonuç)

**Çıktı:** [`g1_dev_tsrc_v11b_output.txt`](matlab/g1/v11/g1_dev_tsrc_v11b_output.txt) · **Ham sonuçlar:** [`g1_dev_tsrc_v11b_results.csv`](matlab/g1/v11/g1_dev_tsrc_v11b_results.csv) · **Figür:** [`g1_dev_tsrc_v11b.png`](matlab/figures/g1_dev_tsrc_v11b.png)

Kullanıcı bir kez koştu. **C1 100/100, C2 280/280, C3 1520/1520 birebir.** Yani ölçüt dışında hiçbir şey değişmedi.

**Kural sonucu: v11'in sıcaklık kaynağı modeli HW** (geri giriş beklemesi m = 30 + gecikme ızgarası 0:20:600).
- Adım 1: aday HW. H, 8 hücrede kötü / 6'sında iyi; W, 11'de kötü / 2'sinde iyi.
- Adım 2, her kümede geçti:
  - dev ve spent1: v6 ile her kalemde aynı.
  - spent2: olay dışı alarm 19,44 → 0,84, ısıtıcı payı (işaretli) 0,822 → 0,824, BME arızası kapsaması 0,981 → 0,983, gecikme 0,6 → 0,6.
- Bilgi: §23'teki işaretsiz ölçütle 0,873 → 0,851. Kararı bu ölçüt değişikliği çevirdi. Değişiklik sonuç sonrası verildi (§23b başı).

**Bulgu 23D: İşaretli ölçütün bir sınırı var: ısıtıcı penceresi BME arızasıyla çakışınca gerçek arıza alarmlarını saymıyor.** v6'nın kilitlenmediği koşularda iki ölçüt arasındaki fark ortalama 3 puan. 5 puanı aşan 8 koşunun hepsi bme-step / bme-drift. Bu koşularda ısıtıcı penceresi negatif işaretli bir BME arızasıyla çakışıyor ve doğru arıza alarmları ısıtıcı payından düşüyor. Etki v6'da ve HW'de aynı (8'er koşu, ortalama fark 0,030 / 0,027), yani karar yönünü değiştirmiyor. Sonraki ilanlarda ısıtıcı payı, BME arızası bloklarını dışarıda bırakarak tanımlanmalı.

**Genel değerlendirme:**
- Geliştirme verisinde K3b'nin iki mekanizması çözüldü: spent2'de 19,4'ten 0,84'e. Geriye drift-ramp-220 (39 blok) ve heaters-216 (45 blok) kalıyor.
- W'nin aralığı spent2 görülerek seçildi. Bu yüzden üçüncü kümede daha yavaş (net gecikme > 600 s) ve yapısal olarak farklı BME yolları olmalı.
- Bellek: 31 gecikme adayı. ATmega328P bütçesinde ayrıca bakılacak.
- **Sonraki adım:** v11 = v10 + HW sıcaklık kaynağı modeli. T-src çıktısı hareket kanallarının referans seçimini (`usable`) etkilediği için tam dedektörün geliştirme koşusu gerekiyor (v10'a karşı).

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
- [x] ~~**G1 v6, sıcaklık kaynağı modeli:** sT'ye model hatası payı, donmuşken (a, b) kovaryansının büyümesi, uyarım olmadan eğime güvenmemek; T8 için iki gecikmeli model ya da hıza bağlı sT (14B–14D)~~ → Bulgu 15, aday L (lead-lag); ızgara payı ve donmuşken büyüme gereksiz/zararlı
- [x] ~~Yeni ayrılmış kümede BME için simülatörden **farklı** bir termal yapı (ikinci derece yol, farklı ortam); L'nin yapısı simülatörle aynı (15A, ADR-012)~~ → §21 (ilan edildi)
- [x] ~~Yeni ayrılmış kümeyi önceden ilan edilmiş aralıklardan otomatik üretmek: profil, ısıtıcı, termal yapı, histerezis, tohum 200+ (15E, §15 kararları)~~ → §21 (ilan edildi)
- [ ] τ_B / τ_I'nin ayrı ayrı 20–25 s kaymasının kaynağı (ayrık gecikme filtresi?, 15D); net gecikme doğru
- [ ] T5'te yalnız tohum 108 ve 118'in kilitlenme nedenini doğrulamak (ısıtıcı anında b yakınsamış mı? 14B)
- [x] ~~Yeni sürüm için **yeni** bir ayrılmış küme (tohum 200+, yeni senaryolar); §13'teki küme artık görülmüş sayılıyor~~ → §21 (ilan edildi)
- [x] ~~Basamak arızasında doğru davranış: kalıcı ofset "arıza" mı, "yeni normal" mi? (12B)~~ → Karar (§15): arıza değil, üçüncü durum "ofset olayı: tespit edildi, raporlandı, yeniden kalibre edildi". Formel tanıma yazılacak.
- [x] ~~Artık öz-ilişkisini "model güvenilmez" durumu için kullanmayı değerlendirmek (12E, ADR-010)~~ → C2 olarak denendi; etkisiz (16C) ve iki eşzamanlı arızada zararlı (19E), v9'da kapatıldı (20A)
- [x] ~~Tanı: E'nin bırakamadığı yanlış alarmlar (H2: dMin donmuş modelin tahmin hatasını içermiyor, 20B)~~ → 20D–20E: tanımlanmadan dondurulmuş kanallar (10F) ve renkli gürültüde iyimser se; E bu hâliyle bırakılıyor
- [ ] Rampada kaymayı ofset sanma (19F), E olmadan yine açık: sıcaklık katsayısı belirsizliğini ve artık ilişkisini hesaba katan bir "kayma yok" testi, yeni bir geliştirme kümesinde
- [ ] Baştan kilitlenme (10F) büyüme testiyle bırakılıyor ama tetiği duruyor: model tanımlanmadan dondurmamak
- [ ] Tanı (21C): sıcaklık kaynağı modelinin ikinci ayrılmış kümedeki olay dışı alarmları (12 senaryo, gürültüden bağımsız; tek tohumla incelenebilir)
- [ ] Tanı (21B): K1b kuyruğu: ızgara dışı uzun τ gevşemede D1'in bedeli (19G) ve play biçimindeki ısıtıcılı iki koşu (heaters-236, heaters-216)
- [ ] Üçüncü ayrılmış küme: tanıdan çıkacak bir sürüm ancak yeni bir kümeyle sınanabilir; ikinci küme (§21) kullanıldı
- [ ] Seçim kuralının 1. adımını simetrik yapmak (ablasyon tam sürüme karşı 2. adımın testiyle), bir sonraki koşudan önce (20C)
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
- **[R15]** D. J. Schuirmann, "A comparison of the two one-sided tests procedure and the power approach for assessing the equivalence of average bioavailability", *Journal of Pharmacokinetics and Biopharmaceutics*, 15(6), 657–680, 1987. İki tek yönlü test (TOST) ile eşdeğerlik. → §20 (E)

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
