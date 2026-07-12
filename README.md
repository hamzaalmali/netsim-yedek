# Netsim Yedekleme Servisi

Netsim Otomasyon Sistemi'nin `E:\Ofisnet\Data` klasorundeki `.fdb` veritabani dosyalarini her gun belirlenen bir saatte otomatik olarak yedekler:

1. Program calisiyorsa once duzgunce (gerekirse zorla) kapatir.
2. Data klasorunu zip'ler.
3. Programi otomatik yeniden acar (istege bagli, ayarlardan kapatilabilir).
4. Yedegi Google Drive'a yukler ve istege bagli ek klasor(ler)e (yerel disk veya ag paylasimi) kopyalar.
5. Her hedefte son **N** yedegi tutar, daha eskilerini otomatik siler (varsayilan 5).

Zamanlama, bir Windows Servisi olarak surekli arka planda calisan bir PowerShell dongusuyle yapilir (Task Scheduler degil) — bu sayede servis "Hizmetler" (services.msc) ekraninda gorunur, bilgisayar acilista otomatik baslar.

## Klasor yapisi

```
netsimYedek/
  Scripts/
    Common.ps1              -> ortak fonksiyonlar (log, config, Google Drive API cagrilari)
    Backup-Engine.ps1        -> tek seferlik yedekleme mantigi
    Service-Loop.ps1          -> servis olarak calisan surekli dongu
    Settings-UI.ps1           -> ayar ekrani (GUI)
    Connect-GoogleDrive.ps1   -> Google hesabi ile bir kerelik yetkilendirme (tarayici acar)
    Install-Service.ps1       -> servisi kurar (NSSM ile)
    Uninstall-Service.ps1     -> servisi kaldirir
  Config/
    config.json               -> ayarlar (Settings-UI tarafindan olusturulur)
    refresh_token.dat          -> Google Drive baglantisi (sifreli, makineye bagli)
  Logs/                        -> gunluk yedekleme kayitlari
  Staging/                     -> yerelde olusturulan zip dosyalari
  Tools/
    nssm.exe                   -> siz indirip buraya koyacaksiniz
```

## Kurulum adimlari

### 1) Dosyalari Windows makinesine kopyala

Bu klasoru oldugu gibi (ornegin) `C:\NetsimYedek` altina kopyalayin.

### 2) Google Cloud Console'da OAuth istemcisi olusturun

Google Drive API'ye erisim icin bir defaya mahsus bir "istemci kimligi" (Client ID / Client Secret) olusturmaniz gerekiyor. Bunlar sizin kendi Google Cloud projenize aittir, program sadece bunlari kullanarak kendi Drive hesabiniza baglanir.

1. https://console.cloud.google.com adresine gidin, ust menuden yeni bir proje olusturun (ornek isim: "Netsim Yedekleme").
2. Sol menu > **APIs & Services > Library** > "Google Drive API" aratip **Enable** deyin.
3. Sol menu > **APIs & Services > OAuth consent screen**:
   - User Type: **External**
   - Uygulama adi: "Netsim Yedekleme" gibi bir isim, destek e-postasi olarak kendi mailinizi girin.
   - **Test users** kismina yedekleyecek Google hesabinizi ekleyin (ornek: `pronethamza@gmail.com`).
   - Scopes ekraninda bir sey eklemenize gerek yok, kaydedip gecin.
4. Sol menu > **APIs & Services > Credentials** > **Create Credentials > OAuth client ID**:
   - Application type: **Desktop app**
   - Bir isim verin, **Create** deyin.
   - Cikan ekrandaki **Client ID** ve **Client Secret** degerlerini not alin (bunlari birazdan program arayuzune gireceksiniz).

Not: Uygulama "Testing" modunda kaldigi surece sadece yukarida test kullanicisi olarak eklediginiz hesap(lar) giris yapabilir, bu sizin tek kisilik kullaniminiz icin yeterlidir ve Google'in ayrica "dogrulama" surecine girmenize gerek yoktur.

### 3) Ayarlari girin

`Scripts\Settings-UI.ps1` dosyasina sag tik > **PowerShell ile Calistir** (veya bir PowerShell penceresinde `powershell -ExecutionPolicy Bypass -File Settings-UI.ps1`).

Acilan ekranda:
- **Veri klasoru**: `E:\Ofisnet\Data`
- **Ofisnet.exe yolu**: `E:\Ofisnet\Bin\Ofisnet.exe`
- **Firebird servis adi**: Eger "Hizmetler" ekraninda Firebird ile ilgili ayri bir servis goruyorsaniz (ornek: `FirebirdServerDefaultInstance`) adini buraya yazin; yoksa bos birakin (bkz. asagida "Onemli Not").
- **Yedekleme saati**: istediginiz saat, ornek `23:30`
- **Saklanacak yedek sayisi**: `5` (istediginiz gibi degistirebilirsiniz)
- **Google Drive Client ID / Client Secret**: 2. adimda aldiginiz degerler
- **Drive klasor adi**: yedeklerin gidecegi Drive klasorunun adi (yoksa otomatik olusturulur)
- Istege bagli: **Ek yedekleme konumlari** listesine yerel klasor veya `\\SUNUCU\Paylasim\Yedekler` gibi bir ag yolu ekleyebilirsiniz.

**Kaydet**'e basin, sonra **Google Drive'a Bagla**'ya tiklayin — bir tarayici penceresi acilacak, Google hesabinizla giris yapip izin verin. Ardindan **Baglantiyi Test Et** ile baglantinin gercekten calistigini (klasorun olusturulup olusturulamadigini) dogrulayin.

### 4) Elle bir test yedeklemesi yapin

**Simdi Yedekle (Test)** butonuna basin. Islem bitince `Logs` klasorundeki gunluk dosyaya ve Google Drive'daki ilgili klasore bakip zip dosyasinin gercekten olustugunu dogrulayin.

### 5) NSSM indirin

NSSM, herhangi bir programi/scripti gercek bir Windows Servisi haline getiren, yaygin kullanilan ve guvenilir bir arac. https://nssm.cc/download adresinden indirin, icindeki `win64\nssm.exe` dosyasini bu projenin `Tools\nssm.exe` yoluna kopyalayin.

### 6) Servisi kurun

Bir PowerShell penceresini **Yonetici olarak** acin, `Scripts\Install-Service.ps1` dosyasini calistirin:

```
powershell -ExecutionPolicy Bypass -File Install-Service.ps1
```

Sizden bir Windows kullanici hesabi (kullanici adi + sifre) isteyecek. **Onemli:** buraya bilgisayarda gercekten oturum acan, masaustune erisimi olan bir hesap girin (LocalSystem degil) — cunku servis, yedekten sonra Ofisnet.exe'yi otomatik yeniden acacaksa bunu ancak gercek bir kullanici oturumunda gorunur sekilde yapabilir.

Kurulum bitince "Hizmetler" (services.msc) ekraninda **Netsim Yedekleme Servisi** adiyla gorebilir, calisir durumda oldugunu kontrol edebilirsiniz.

Servisi kaldirmak isterseniz Yonetici olarak `Uninstall-Service.ps1` calistirin.

## Onemli not: veritabani dosyasi kilidi

`.fdb` dosyalari Firebird veritabani motoru tarafindan kullanilir. Eger Netsim sadece kendi icine gomulu (embedded) Firebird kullaniyorsa, `Ofisnet.exe`'yi kapatmak dosya kilidini de kaldirir ve zip guvenle alinir. Ama bazi kurulumlarda ayrica calisan bir **Firebird Server Windows servisi** de olabilir; boyle bir durumda sadece programi kapatmak yetmeyebilir, dosyalar hala kilitli kalabilir.

Ilk birkac test yedeklemesinden sonra:
- "Hizmetler" ekraninda adinda "Firebird" gecen bir servis olup olmadigina bakin.
- Varsa, adini Ayarlar ekranindaki **Firebird servis adi** alanina yazin — yedekleme sirasinda bu servis de otomatik durdurulup, yedek sonrasi yeniden baslatilir.
- Yoksa veya zip dosyasi duzgun aciliyorsa, bu alani bos birakmaya devam edin.

## Guvenlik notlari

- Google Client Secret ve Drive refresh token, Windows'un DPAPI mekanizmasiyla bu bilgisayara ozel olarak sifrelenmis halde `Config\refresh_token.dat` ve `config.json` icinde saklanir; baska bir bilgisayara kopyalandiginda cozulemez, yeniden baglanti gerekir.
- Google Drive erisimi `drive.file` kapsamiyla sinirlidir: program sadece kendi olusturdugu dosya ve klasorlere erisebilir, Drive'inizdaki diger dosyalara erisemez.
- Hesap degistirmek isterseniz Ayarlar ekranindan **Hesabi Degistir** butonuyla mevcut baglantiyi kaldirip **Google Drive'a Bagla** ile farkli bir hesapla yeniden baglanabilirsiniz.

## Sorun giderme

- `Logs\backup_YYYY-MM-DD.log` dosyasi her yedeklemenin adim adim kaydini tutar, hata olursa oradan bakin.
- Servis hic calismiyorsa `Logs\service-stderr.log` dosyasina bakin.
- "Baglantiyi Test Et" hata veriyorsa: Client ID/Secret dogru mu, Google Drive API projede etkin mi, test kullanicisi olarak dogru hesap eklenmis mi kontrol edin.
