# Kickoff Manager

FC kariyer modu sadeliğinde, kurgusal takımlarla oynanan bir iOS futbol menajerlik oyunu.
SwiftUI ile yazıldı; Mac gerekmeden bulutta derlenip TestFlight'a gönderilir.

## Neler var (v0.5)

- **5 kurgusal lig**: Hilal Lig (TR), Albion Premier (EN), Liga Ibérica (ES), Bundesklasse (DE), Serie Azzurra (IT). Her ligde 18 kulüp, kulüp başına 24 oyuncu.
- **Kadro ve diziliş**: 10 diziliş (4-3-3, 4-4-2, 4-2-3-1, 3-5-2, 5-3-2, 4-1-4-1, 4-3-1-2, 4-3-2-1, 3-4-3, 4-5-1). İlk 11, 7 yedek ve kadro dışı aynı ekranda; iki oyuncuya sırayla dokunarak yer değiştirilir. Otomatik diz butonu.
- **Oyuncu kartları**: genel güç, mevki, en iyi 3 özellik ve kondisyon çubuğu.
- **Kondisyon ve yorgunluk**: her maç kondisyon düşürür, hafta içinde toparlanır (sağlık merkezi hızlandırır). Yorgun oyuncu daha kötü oynar ve daha kolay sakatlanır. Maçta en yorgunlar 55–85. dakikalar arasında yedeklerle değişir.
- **Maç simülasyonu**: xG tabanlı skor, golcüler, asistler, oyuncu değişiklikleri, sakatlıklar, sarı/kırmızı kartlar (kırmızıda takım 10 kişi kalır), oyuncu puanları.
- **Cezalar**: kırmızı kart 1–3 maç, ikinci sarı 1 maç, sezonda her 5. sarı 1 maç. İlk 11'de sakat ya da cezalı oyuncu varken maça girilmez; önce kadro düzenlenmelidir.
- **Transfer pazarlığı**: önce kulüple bonservis (karşı teklif, sabır, çok düşük teklife sinirlenme), sonra oyuncuyla maaş ve süre. Büyük yıldızlar küçük kulübe gelmek istemez.
- **Satış**: oyuncuyu transfer listesine koyma, transfer döneminde "Kulüplere öner" ile anında teklif toplama, gelen tekliflere kabul, ret ya da pazarlık (karşı teklif).
- **Avrupa kupaları**: lig ilk 3'ü bir sonraki sezon Elit Kupa'ya, 4–6. sıralar Kıta Ligi'ne katılır (en güçlü ligde bir fazla). 4 grup, iki maçlı çeyrek ve yarı final, tarafsız sahada final. Hafta ortası oynanır; bilet geliri ve ödül parası lig maçlarından yüksektir.
- **Teknik direktör**: saygınlık puanı, yönetimin hedefi (şampiyonluk, ilk 3, üst sıralar, orta sıralar, ligde kalmak) ve yönetimin güveni. Kötü sonuçlarda önce uyarı gelir, güven dibe vurursa kovulursun ve yeni kulüp seçersin. İyi giden menajere devre arasında ve sezon sonunda daha büyük kulüplerden iş teklifi gelir.
- **Transfer dönemleri**: yaz (ilk 4 hafta) ve devre arası (4 hafta). Açılış ve kapanışta mesaj gelir, ana sayfada geri sayım görünür.
- **Sezon döngüsü**: ödül parası, itibar değişimi, emeklilikler, sözleşme bitişleri, altyapıdan genç oyuncular, yeni fikstür ve kupa kuraları.
- **Kulüp yönetimi**: antrenman, altyapı, sağlık tesisi yükseltmeleri; stadyum genişletme; bilet fiyatı; gelir ve giderler.
- **Serbest oyuncular**: sözleşmesi biten ya da serbest bırakılan oyuncular havuza düşer. Bonservis ödenmez, transfer dönemi dışında da imzalanabilir; karşılığında yaklaşık %40 daha yüksek maaş isterler. Yapay zekâ kulüpleri de bu havuzdan oyuncu alır.
- **Sözleşme takibi**: sözleşmesi bu sezon biten oyuncular için Sözleşmeler ekranı, ana sayfa ve kadro uyarısı, kartta simge, sezon içinde 4 kez hatırlatma mesajı.
- **Gol ve asist krallığı**: Lig › İstatistik sekmesinde her lig için ilk 20.
- **Bütçe aktarma**: transfer bütçesi ile haftalık maaş bütçesi arasında aktarma (haftalık €1 maaş = €40 transfer bütçesi).
- **Reklam ve satın alma**: her 5 oynanan haftada bir geçiş reklamı (AdMob). "Reklamları kaldır" tek seferlik satın alımı (StoreKit 2) ve geri yükleme.
- **Türkçe + İngilizce** arayüz, otomatik kayıt.

## Proje yapısı

```
Packages/GameEngine/   Oyunun tüm mantığı (saf Swift, arayüzden bağımsız) + testler
  Models/              Oyuncu, kulüp, lig, fikstür, gelen kutusu
  Generation/          Kurgusal kulüpler, isim havuzları, oyuncu üretimi
  Simulation/          Fikstür üretimi, maç motoru
  Career/              Sezon döngüsü, gelişim, transfer, tesisler
App/Sources/           SwiftUI ekranları ve tema
App/Resources/         Çeviriler (en, tr), uygulama ikonu
project.yml            XcodeGen proje tanımı (.xcodeproj bulutta bundan üretilir)
codemagic.yaml         Bulutta derleme + TestFlight
.github/workflows/     Motor testleri (Linux) ve uygulama derleme kontrolü (macOS)
```

Oyun dengesini ayarlamak için en önemli yerler:

| Ne | Nerede |
|---|---|
| Takım/lig isimleri, renkler, stadyumlar | `Generation/WorldData.swift` |
| Maçta gol beklentisi, ev sahibi avantajı, oyuncu değişikliği | `Simulation/MatchEngine.swift` |
| Kadro seçimi, kondisyonun performansa etkisi | `Simulation/Selection.swift` |
| Kondisyon kaybı ve toparlanma | `Career/Career+Season.swift` |
| Avrupa kontenjanları, ödüller, bilet çarpanı | `Career/Career+Europe.swift` |
| Pazarlık kuralları, gelen teklif sıklığı | `Career/Career+Transfers.swift` |
| Yönetim güveni, kovulma, iş teklifleri, transfer dönemleri | `Career/Career+Manager.swift` |
| Oyuncu gelişim hızı | `Career/Career+Development.swift` |
| Piyasa değeri, maaşlar | `Models/Player.swift` |
| Bütçeler, bilet fiyatı, ödül parası | `Career/Career+Generation.swift`, `Career+Season.swift` |
| Tesis yükseltme maliyetleri | `Career/Career+Facilities.swift` |

## Bulutta derleme (Mac olmadan)

Tek seferlik kurulum. Hepsi Windows'tan tarayıcıyla yapılır.

### 1. Bundle ID ve uygulama kaydı (Apple)

1. [developer.apple.com](https://developer.apple.com/account) → **Certificates, Identifiers & Profiles** → **Identifiers** → **+** → **App IDs** → **App**.
   Bundle ID olarak sana ait benzersiz bir değer gir, örneğin `com.adin.kickoffmanager`.
2. [App Store Connect](https://appstoreconnect.apple.com) → **Uygulamalarım** → **+** → **Yeni Uygulama**. Platform iOS, az önceki Bundle ID'yi seç.
3. Uygulamanın sayfasında **Uygulama Bilgileri** altındaki **Apple ID** numarasını not al (10 haneli sayı).

### 2. App Store Connect API anahtarı

1. App Store Connect → **Kullanıcılar ve Erişim** → **Entegrasyonlar** → **App Store Connect API** → **Ekip Anahtarları** → **+**.
2. İsim ver, erişim olarak **App Manager** seç, oluştur.
3. **Issuer ID** ve **Key ID**'yi not al, `.p8` dosyasını indir (yalnızca bir kez indirilebilir, güvenli sakla, kimseyle paylaşma).

### 3. Codemagic

1. [codemagic.io](https://codemagic.io) → GitHub ile giriş → **Add application** → bu repoyu seç → proje tipi olarak **codemagic.yaml** kullan.
2. **Team settings → Team integrations → Developer Portal → Connect** → API anahtarını ekle:
   isim alanına tam olarak `kickoff_asc` yaz, Issuer ID, Key ID ve `.p8` dosyasını gir.
3. **Team settings → Code signing identities**:
   - **iOS certificates** → **Generate certificate** → tür **Apple Distribution**, API anahtarı olarak `kickoff_asc`.
   - **iOS provisioning profiles** → **Fetch profiles**. Bundle ID'n için **App Store** profili yoksa önce developer.apple.com → **Profiles** → **+** → **App Store Connect** ile oluştur, sonra tekrar fetch et.
4. Repoda şu üç değeri kendi değerlerinle değiştir:
   - `project.yml` → `PRODUCT_BUNDLE_IDENTIFIER`
   - `codemagic.yaml` → `bundle_identifier`
   - `codemagic.yaml` → `APP_STORE_APPLE_ID`
5. `main` dalına her push'ta derleme başlar (Codemagic'te **Start new build** ile elle de başlatılabilir).

### 4. TestFlight

Derleme bittikten sonra App Store Connect işlemeyi 10–30 dakikada tamamlar.
App Store Connect → uygulama → **TestFlight** → **Dahili Test** grubuna kendini ekle.
iPhone'daki TestFlight uygulamasından oyunu yükle.

## GitHub Actions

- **Engine tests**: her push'ta oyun motorunu Linux'ta derleyip testleri çalıştırır.
- **App build check**: `main`'e her push'ta uygulamayı imzasız olarak simülatör için derler. Derleme hatalarını Codemagic'e gitmeden görmek için.

## Reklam ve satın alma kurulumu

Şu an Google'ın **test** reklam kimlikleri kullanılıyor (test reklamı gösterir, para kazandırmaz).

1. AdMob hesabı aç, iOS uygulamasını ekle. **Uygulama kimliğini** (`ca-app-pub-…~…`) `project.yml` içindeki `GADApplicationIdentifier` yerine, **geçiş reklamı birim kimliğini** (`ca-app-pub-…/…`) `App/Sources/Monetization/AdManager.swift` içindeki `interstitialUnitID` yerine yaz.
2. AdMob'da Gizlilik ve mesajlaşma bölümünden GDPR (AB) onay mesajını oluştur.
3. App Store Connect › Sözleşmeler: **Ücretli Uygulamalar** sözleşmesini, banka ve vergi bilgilerini tamamla.
4. App Store Connect › uygulama › Uygulama İçi Satın Almalar: **Tüketilemez** ürün, ürün kimliği `com.canakboyraz.kickoffmanager.removeads`.
5. App Store Connect › Uygulama Gizliliği: reklam için cihaz kimliği ve kullanım verisi toplandığını işaretle.

## Notlar

- Kulüp, lig ve oyuncu isimleri kurgusaldır. Gerçek kulüplere fazla yakın isim, logo veya renk kombinasyonları App Store incelemesinde sorun çıkarabilir.
- Kayıt dosyası cihazda `Documents/career.json` olarak tutulur.
