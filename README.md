# Kickoff Manager

FC kariyer modu sadeliğinde, kurgusal takımlarla oynanan bir iOS futbol menajerlik oyunu.
SwiftUI ile yazıldı; Mac gerekmeden bulutta derlenip TestFlight'a gönderilir.

## Neler var (v0.1)

- **5 kurgusal lig**: Hilal Lig (TR), Albion Premier (EN), Liga Ibérica (ES), Bundesklasse (DE), Serie Azzurra (IT). Her ligde 18 kulüp, kulüp başına 24 oyuncu.
- **Maç simülasyonu**: en iyi 11 otomatik seçilir (4-3-3), takım gücünden beklenen gol (xG) hesaplanır, skor, golcüler, asistler, sakatlıklar ve oyuncu puanları üretilir.
- **Sezon döngüsü**: 34 hafta, ödül parası, itibar değişimi, emeklilikler, sözleşme bitişleri, altyapıdan genç oyuncular, yeni fikstür.
- **Oyuncu gelişimi**: yaş, potansiyel, oynama süresi ve antrenman tesisi seviyesine bağlı.
- **Transferler**: oyuncu arama ve filtreler, teklif verme (istenen bedel, maaş talebi), yaz ve devre arası transfer dönemleri, diğer kulüplerden gelen teklifler.
- **Kulüp yönetimi**: antrenman, altyapı, sağlık tesisi yükseltmeleri; stadyum genişletme; bilet fiyatı; gelir ve giderler.
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
| Maçta gol beklentisi, ev sahibi avantajı | `Simulation/MatchEngine.swift` |
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

## Notlar

- Kulüp, lig ve oyuncu isimleri kurgusaldır. Gerçek kulüplere fazla yakın isim, logo veya renk kombinasyonları App Store incelemesinde sorun çıkarabilir.
- Kayıt dosyası cihazda `Documents/career.json` olarak tutulur.
