# Netsim Yedekleme

Netsim Otomasyon Sistemi'nin veritabani dosyalarini (`.fdb`) her gun belirlediginiz saatte otomatik olarak yedekleyen bir Windows masaustu uygulamasi. Electron ile yazilmistir: gercek bir `.exe` kurulum dosyasi (installer) uretir, sistem tepsisinde (saatin yaninda) yasar, arka planda gorunur bir konsol/terminal penceresi olmadan calisir.

## Nasil calisir

1. Kurulum dosyasini calistirip programi kurarsiniz (Baslat Menusu ve masaustu kisayolu olusur).
2. Uygulama acilir, ayarlari girip **Kaydet**'e basarsiniz.
3. Pencereyi kapatma (X) tusuna bastiginizda uygulama kapanmaz, sistem tepsisine kucultup arka planda calismaya devam eder.
4. Belirlediginiz saatte otomatik olarak:
   - Sectiginiz program (calisan uygulamalar listesinden veya elle) once duzgunce (gerekirse zorla) kapatilir.
   - Veri klasoru zip'lenir.
   - Program otomatik yeniden acilir (istege bagli).
   - Zip, secilen hedeflere gonderilir: Google Drive (opsiyonel) ve/veya belirttiginiz yerel klasor(ler)/ag yollari (opsiyonel).
   - Basarili/basarisiz oldugunda istege bagli olarak e-posta bildirimi gonderilir.
   - Her hedefte son **N** yedek tutulur, daha eskisi otomatik silinir.
5. Uygulama, tepsi simgesine **sag tiklayip "Cikis"** demediginiz surece calismaya devam eder. Windows'a her giriste otomatik baslamasini isterseniz ayarlar ekranindaki "Windows'a giriste otomatik baslat" anahtarini acmaniz yeterli (Electron'un kendi `openAtLogin` mekanizmasini kullanir, ek bir kisayol/script gerekmez).
6. Pencereyi her actiginizda, GitHub'daki en son surumle karsilastirilir; yeni bir surum varsa sari bir bildirim seridi cikar.

## Proje yapisi

```
netsimYedek/
  package.json
  build/                  -> uygulama ikonlari (icon.ico, icon.png, tray.png)
  src/
    main.js                -> Electron ana sureci: pencere, tepsi simgesi, zamanlayici, IPC
    preload.js              -> renderer'a guvenli API koprusu
    config.js                -> ayarlarin okunmasi/yazilmasi, sifreli sir saklama (Electron safeStorage)
    backup.js                 -> yedekleme mantigi (sureci kapat/ac, zip, kopyala, rotasyon, e-posta)
    googleDrive.js             -> Google OAuth ve Drive REST API cagrilari
    processes.js                -> calisan uygulamalari listeleme (Yenile butonu icin)
    email.js                     -> e-posta bildirimi (nodemailer, Gmail)
  renderer/
    index.html, styles.css, renderer.js  -> ayar ekrani arayuzu
```

Kullanici ayarlari ve loglar uygulamanin kendi veri klasorunde tutulur (`%APPDATA%\netsim-yedekleme\`), kurulum klasorunden bagimsizdir.

## Gelistirme / kaynak koddan calistirma

```
npm install
npm start
```

## Kurulum dosyasi (.exe) uretme

```
npm run dist
```

Bu komut `electron-builder` ile `release\Netsim Yedekleme Setup <surum>.exe` adinda gercek bir NSIS kurulum dosyasi uretir (Baslat Menusu + masaustu kisayolu olusturur, kaldirma araciyla birlikte gelir). Kod imzalama sertifikasi olmadigi icin ilk calistirmada Windows SmartScreen "Bilinmeyen yayimci" uyarisi gosterebilir — "Yine de calistir" ile devam edilebilir; bu, internal/kisisel kullanim icin normal bir durumdur.

## Ilk calistirma / ayarlar

1. Kurulum dosyasini calistirin, uygulama acilsin.
2. **Program ve Veri**: "Goz At..." ile veri klasorunu (`E:\Ofisnet\Data`) secin. Kapatilacak programi ya calisan uygulamalar listesinden secin (Yenile ile listeyi tazeleyebilirsiniz) ya da "Goz At..." ile elle secin.
3. **Zamanlama**: gunluk saat, yedekten sonra otomatik yeniden baslatma, saklanacak yedek sayisi.
4. **Google Drive (opsiyonel)**: kullanmak isterseniz anahtari acip Client ID/Secret girin (bkz. asagida), istemiyorsaniz kapali birakin.
5. **E-posta Bildirimleri (opsiyonel)**: Gmail adresiniz ve bir "Uygulama Sifresi" (App Password) ile yedekleme sonucu hakkinda bildirim alabilirsiniz.
6. **Ek Yedekleme Konumlari (opsiyonel)**: yerel bir klasor veya `\\SUNUCU\Paylasim\Yedekler` gibi bir ag yolu ekleyebilirsiniz.
7. En az bir hedef (Google Drive veya ek konum) secili olmadan kaydetmeye calisirsaniz uygulama uyarir.
8. **Kaydet**, ardindan **Simdi Yedekle** ile bir test yapip sonucu kontrol edin.

## Google Drive kullanmak isterseniz

1. https://console.cloud.google.com adresinde yeni bir proje olusturun.
2. **APIs & Services > Library** > "Google Drive API" > **Enable**.
3. **APIs & Services > OAuth consent screen**: User Type **External**, uygulama adi girin, **Test users** kismina yedekleyecek Google hesabinizi ekleyin.
4. **APIs & Services > Credentials > Create Credentials > OAuth client ID**: Application type **Desktop app**. Cikan **Client ID** ve **Client Secret** degerlerini not alin.
5. Ayarlar ekraninda bu degerleri girip **Google Drive'a Bagla** ile tarayicidan izin verin, **Baglantiyi Test Et** ile dogrulayin.
6. Ileride farkli bir Google hesabina gecmek isterseniz **Hesabi Degistir** ile mevcut baglantiyi kaldirip yeniden baglanabilirsiniz.

## E-posta bildirimleri icin

Gmail hesabinizda 2 adimli dogrulamayi acip https://myaccount.google.com/apppasswords adresinden bir "Uygulama Sifresi" olusturun (normal Gmail sifreniz calismaz). Bu 16 haneli sifreyi ayarlar ekranindaki "Uygulama Sifresi" alanina girin.

## Onemli not: veritabani dosyasi kilidi

`.fdb` dosyalari Firebird veritabani motoru tarafindan kullanilir. Eger Netsim sadece kendi icine gomulu (embedded) Firebird kullaniyorsa, programi kapatmak dosya kilidini de kaldirir. Bazi kurulumlarda ayrica calisan bir **Firebird Server Windows servisi** olabilir; boyle durumlarda programi kapatmak yetmeyebilir. Ilk test yedeklemesinden sonra zip icindeki dosyalarin saglikli oldugunu kontrol edin; sorun varsa "Hizmetler" (services.msc) ekraninda ilgili servisin adini ayarlardaki **Firebird Windows servis adi** alanina yazin.

## Guvenlik notlari

- Google Client Secret, Drive refresh token ve e-posta uygulama sifresi Electron'un `safeStorage` API'siyle (Windows'ta DPAPI kullanir) bu bilgisayara ozel sifrelenmis halde saklanir.
- Google Drive erisimi `drive.file` kapsamiyla sinirlidir: uygulama sadece kendi olusturdugu dosya/klasorlere erisebilir.

## Guncelleme

Bu proje https://github.com/hamzaalmali/netsim-yedek adresinde tutuluyor. Yeni bir surum yayinlandiginda (GitHub Releases) ayarlar ekraninda sari bir bildirim seridi cikar; "GitHub'da Ac" ile indirme sayfasina gidip yeni kurulum dosyasini calistirmaniz yeterlidir (eski surumun uzerine kurulabilir, ayarlar `%APPDATA%` altinda tutuldugu icin silinmez).

## Sorun giderme

- Loglar: `%APPDATA%\netsim-yedekleme\Logs\backup_YYYY-MM-DD.log`
- Uygulamayi tamamen kapatmak icin tepsi simgesine sag tiklayip **Cikis** secin.
- "Baglantiyi Test Et" hata veriyorsa Client ID/Secret'i, Drive API'nin projede etkin oldugunu ve test kullanicisi olarak dogru hesabin eklendigini kontrol edin.
