# Netsim Yedekleme

Netsim Otomasyon Sistemi'nin veritabani dosyalarini (`.fdb`) her gun belirlediginiz saatte otomatik olarak yedekleyen, sistem tepsisinde (saatin yaninda) yasayan bir masaustu uygulamasi.

## Nasil calisir

1. Uygulamayi acarsiniz (bkz. asagidaki "Ilk calistirma"), acilan pencereden ayarlari girip **Kaydet**'e basarsiniz.
2. Pencereyi kapatma (X) tusuna bastiginizda uygulama kapanmaz, sistem tepsisine (saatin yanina) kucultup arka planda calismaya devam eder.
3. Belirlediginiz saatte otomatik olarak:
   - Program calisiyorsa once duzgunce (gerekirse zorla) kapatilir.
   - Veri klasoru zip'lenir.
   - Program otomatik yeniden acilir (istege bagli, ayarlardan kapatilabilir).
   - Zip, secilen hedeflere gonderilir: Google Drive (opsiyonel) ve/veya belirttiginiz yerel klasor(ler)/ag yollari (opsiyonel). Hangisini kullanacaginiz tamamen size baglidir; sadece ag yoluna kopyalamak isterseniz Google Drive'i hic ayarlamaniza gerek yok.
   - Her hedefte son **N** yedek tutulur, daha eskisi otomatik silinir.
4. Uygulama, tepsi simgesine **sag tiklayip "Cikis"** demediginiz surece calismaya devam eder. Windows'a her giriste otomatik baslamasini isterseniz pencere icindeki "Windows'a giriste otomatik baslat" kutusunu isaretlemeniz yeterli.
5. Pencereyi her actiginizda, GitHub'daki depoda yeni bir surum olup olmadigi kontrol edilir; varsa ekranda sari bir uyari seridi cikar.

## Klasor yapisi

```
netsimYedek/
  Netsim-Yedekleme-Baslat.vbs   -> uygulamayi konsol penceresi acmadan baslatan kisayol
  VERSION.txt                    -> surum numarasi (guncelleme kontrolu icin)
  Scripts/
    TrayApp.ps1                  -> ana uygulama: pencere + sistem tepsisi + zamanlayici
    Common.ps1                   -> ortak fonksiyonlar (log, config, Google Drive API cagrilari)
    Backup-Engine.ps1            -> tek seferlik yedekleme mantigi
    Connect-GoogleDrive.ps1      -> Google hesabi ile bir kerelik yetkilendirme (tarayici acar)
  Config/
    config.json                  -> ayarlar (uygulama tarafindan olusturulur)
    refresh_token.dat             -> Google Drive baglantisi (sifreli, makineye bagli)
  Logs/                          -> gunluk yedekleme kayitlari
  Staging/                       -> yerelde olusturulan zip dosyalari
```

## Ilk calistirma

1. Bu klasoru Windows makinesine kopyalayin (bkz. asagida "Guncelleme").
2. `Netsim-Yedekleme-Baslat.vbs` dosyasina cift tiklayin. Herhangi bir konsol penceresi acilmaz; sistem tepsisinde mavi "N" simgesi belirir ve ayni anda ayar penceresi acilir (ilk calistirmada config olmadigi icin otomatik acilir).
3. Ayar penceresinde:
   - **Veri klasoru**: "Goz At..." ile `E:\Ofisnet\Data` gibi yedeklenecek klasoru secin.
   - **Ofisnet.exe yolu**: "Goz At..." ile programin exe dosyasini secin.
   - **Firebird servis adi**: bkz. asagida "Onemli not: veritabani dosyasi kilidi".
   - **Zamanlama**: gunluk yedekleme saati, yedekten sonra otomatik yeniden baslatma, saklanacak yedek sayisi.
   - **Google Drive (opsiyonel)**: kullanmak isterseniz kutuyu isaretleyip Client ID/Secret girin (bkz. asagida), istemiyorsaniz bos/isaretsiz birakabilirsiniz.
   - **Ek Yedekleme Konumlari (opsiyonel)**: yerel bir klasor veya `\\SUNUCU\Paylasim\Yedekler` gibi bir ag yolu ekleyip isaretleyebilirsiniz. Google Drive kullanmadan sadece bunu da kullanabilirsiniz.
   - En az bir hedef (Drive veya ek konum) secili olmadan kaydetmeye calisirsanız uygulama uyarir.
4. **Kaydet**'e basin. Pencereyi kapatirsaniz uygulama tepsiye kucultur, calismaya devam eder.
5. **Simdi Yedekle** butonu ile bir test yedeklemesi yapip `Logs` klasorunu ve hedef(ler)i kontrol edin.
6. "Windows'a giriste otomatik baslat" kutusunu isaretleyin — boylece bilgisayar her acildiginda uygulama sessizce tepsiden baslar, tekrar cift tiklamaniza gerek kalmaz.

## Google Drive kullanmak isterseniz

Google Drive API'ye erisim icin bir defaya mahsus bir OAuth istemcisi (Client ID / Client Secret) olusturmaniz gerekiyor:

1. https://console.cloud.google.com adresinde yeni bir proje olusturun.
2. **APIs & Services > Library** > "Google Drive API" > **Enable**.
3. **APIs & Services > OAuth consent screen**: User Type **External**, uygulama adi girin, **Test users** kismina yedekleyecek Google hesabinizi ekleyin.
4. **APIs & Services > Credentials > Create Credentials > OAuth client ID**: Application type **Desktop app**. Cikan **Client ID** ve **Client Secret** degerlerini not alin.
5. Ayar penceresinde Google Drive kutusunu isaretleyip bu degerleri girin, **Google Drive'a Bagla** ile tarayicidan izin verin, **Baglantiyi Test Et** ile dogrulayin.
6. Ileride farkli bir Google hesabina gecmek isterseniz **Hesabi Degistir** ile mevcut baglantiyi kaldirip yeniden baglanabilirsiniz.

## Onemli not: veritabani dosyasi kilidi

`.fdb` dosyalari Firebird veritabani motoru tarafindan kullanilir. Eger Netsim sadece kendi icine gomulu (embedded) Firebird kullaniyorsa, `Ofisnet.exe`'yi kapatmak dosya kilidini de kaldirir. Ama bazi kurulumlarda ayrica calisan bir **Firebird Server Windows servisi** olabilir; boyle durumlarda programi kapatmak yetmeyebilir.

Ilk test yedeklemesinden sonra zip icindeki dosyalarin saglikli oldugunu kontrol edin. Sorun varsa, "Hizmetler" (services.msc) ekraninda adinda "Firebird" gecen bir servis olup olmadigina bakip adini ayar penceresindeki **Firebird Windows servis adi** alanina yazin; yedekleme sirasinda bu servis de otomatik durdurulup sonra yeniden baslatilir.

## Guvenlik notlari

- Google Client Secret ve Drive refresh token, Windows DPAPI ile bu bilgisayara ozel sifrelenmis halde saklanir; baska bir bilgisayara kopyalandiginda cozulemez.
- Google Drive erisimi `drive.file` kapsamiyla sinirlidir: uygulama sadece kendi olusturdugu dosya/klasorlere erisebilir.

## Guncelleme

Bu proje https://github.com/hamzaalmali/netsim-yedek adresinde (private) tutuluyor. Guncelleme geldiginde ayar penceresinde sari bir serit cikar.

- **Git kuruluysa:** klasor icinde `git pull` calistirmaniz yeterli (uygulamayi tepsiden "Cikis" ile kapatip tekrar acmayi unutmayin).
- **Git yoksa:** repo sayfasinda **Code > Download ZIP** ile indirip acin; `Config\` klasorunuzu (ayarlariniz ve Google baglantiniz orada) yeni surumun uzerine kopyalarken **ezmeyin/silmeyin**, digital dosyalarin ustune yazabilirsiniz.

## Sorun giderme

- `Logs\backup_YYYY-MM-DD.log` her yedeklemenin adim adim kaydini tutar.
- Uygulamayi tamamen kapatmak icin tepsi simgesine sag tiklayip **Cikis** secin.
- "Baglantiyi Test Et" hata veriyorsa Client ID/Secret'i, Drive API'nin projede etkin oldugunu ve test kullanicisi olarak dogru hesabin eklendigini kontrol edin.
