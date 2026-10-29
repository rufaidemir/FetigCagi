# Fetih Çağı: projenin mantığı

Bu dosya oyunun **neden ve nasıl** çalıştığını anlatır. Kod yapısı için sondaki "Dosya haritası"na, devir için `../HANDOFF.md`'ye bak.

Tasarım artifact'ı (özel, sadece sahibi açar): https://claude.ai/artifact/DgpdypXCVncWZc5wV9jpWL
Önceki oyunun (ColorBurst) tasarım notları: `C:\Users\BUROSTATIK\AndroidStudioProjects\ColorBurst\docs\onceki-tasarim-notlari.md`

## 1. Oyun nedir
Tek oyunculu, gerçek zamanlı, 2.5B bir strateji oyunu (çalışma adı Fetih Çağı). Hedef kitle: telefon (dikey ekran). Eski ColorBurst'ün top ve karo mantığı **tamamen bırakıldı**.

Döngü: **keşfet → ekonomi kur → ordu yap → fethet → çağ atla**.

- Dünya 1024×1024 karo. Başta neredeyse hepsi bilinmiyor (sis).
- Oyuncu küçük bir şehir, 2 işçi ve 1 izciyle başlar.
- Dokuz yapay zekâ ulusu birbiriyle savaşta (şu an dört tanesi dekor olarak sahnede).
- Kazanma: haritanın %50'si veya tüm başkentleri düşürmek. Kaybetme: başkent kale düşerse.

## 2. Dünya
- **Tohumdan üretim.** Dünya kaydedilmez, `world_gen.gd` aynı tohumdan aynı araziyi verir. Sadece oyuncunun durumu ve keşif kaydedilecek (henüz yok).
- Yükseklik = FBM gürültü + sırt gürültüsü, kenarlara doğru batırılır (adalar). 0'ın altı deniz.
- Biyom = yükseklik + nem gürültüsü + enlem (kuzey soğuk): deniz, kumsal, ova, orman, çöl, kaya, kar.
- **Parça (chunk) sistemi:** 64×64 karoluk parçalar. Kameranın çevresindeki parçalar yüklenir, uzakları çıkarılır. Uzaktaki parçalar daha az ayrıntıyla (LOD: adım 1, 4, 8) üretilir. Parça kenarlarında "etek" (skirt) çatlakları gizler. Normaller komşu parçalarla uyumlu hesaplanır (dikiş yok).
- Üretim ana iş parçacığında, kare başına en fazla 7 ms (`BUILD_BUDGET_USEC`).

## 3. Kamera ve girdi
- Sabit eğik açı (52°), serbest dönme yok. Sürükle = kaydır, tekerlek / sıkıştır = yakınlaş.
- **Dokunma:** kısa ve hareketsiz dokunuş = "tık". Sürüklemeden ayrılır (14 px, 450 ms).
- **Arayüz düzeni:** üstte kaynak + çağ kutuları, hemen altında ipucu ve küçük hata ayıklama satırı, bildirim. Altta **sadece 4 sekme** (Şehir, Ordu, Keşif, Uluslar). Bir sekmeye dokununca kendi bağlamsal paneli alt çubuğun üstünde açılır, tekrar dokununca kapanır. Şehir: Mızraklı, Okçu, Kaleye git. Ordu: Hepsini seç, Kutu seç, Dur. Keşif: İzciyi seç, İzciye git. Uluslar: keşfedilenlerin listesi. Kullanıcı "her şey üst üste olmamalı, gerekli butonları grupla" dedi.
- **Seçim:** birliğe dokun = seç / bırak. Çift dokun = aynı türün hepsi. Ordu sekmesinde "Hepsini seç". **"Kutu seç" modu** (veya masaüstünde Shift) açıkken sürüklemek kutu çizer.
- **Emirler:** seçiliyken yere dokun = git. Düşmana dokun = saldır. "Dur" = emri iptal. Yeni emir eskisini iptal eder. Yoldaki birlik de seçilebilir.
- Hedef göstergesi (çizgi + halka + ok) **emir verildiğinde bir kez** oynar ve söner. Koyu renk, ince çizgi (kullanıcı tercihi). Hareket mavi, saldırı kırmızı.

## 4. Sis (keşif)
- Dünya 4×4 karoluk hücrelere bölünür (256×256). Hücre durumu: 0 bilinmeyen, 128 keşfedilmiş, 255 görünür.
- Her birlik ve yapı kendi **görüş yarıçapıyla** (`sight`) etrafını açar. Güncelleme 5 Hz.
- Sis bir L8 dokusu olarak `terrain.gdshader` ve `water.gdshader` tarafından okunur: bilinmeyen kapkaranlık, keşfedilmiş soluk gri, görünür canlı.
- Rakip yapı, bulunduğu hücre keşfedildiyse görünür (son bilinen hâl). Rakip birlik sadece **şu an görünür** hücredeyse görünür.
- İlk kez görülen ulus için "Yeni ulus keşfedildi" bildirimi çıkar.

## 5. Çağlar ve birimler
Çağ, ordunun hangi birimleri kullanabileceğini belirler. Üstte "Çağ I · Kılıç ve Ok" gösterilir.

| Çağ | Ad | Birimler |
|---|---|---|
| I | Kılıç ve Ok | işçi, izci, mızraklı, okçu |
| II | Barut | (tasarlanacak: tüfekli, top, süvari) |
| III | Sanayi | tank (kodda var), araba, motorlu birlik, komando, roketli |
| IV | Modern | füze, deniz birimleri |
| V | Atom | nükleer silah |

Kodda `units_data.gd` içindeki `ERAS` ve `KINDS` bu bilgiyi tutar. Her birimin `era` alanı vardır; **henüz çağ geçişi ve üretim yok**, çağ sabit I ve sadece test için `--era=3` ile tank açılır.

Birim istatistikleri (başlangıç tahmini):

| Birim | Hız | Görüş | Can | Menzil | Hasar | Bekleme |
|---|---|---|---|---|---|---|
| işçi | 6 | 14 | 30 | – | – | – |
| izci | 14 | 48 | 40 | – | – | – |
| mızraklı | 7 | 16 | 70 | 3,5 | 9 | 0,9 sn |
| okçu | 7 | 18 | 45 | 24 | 6 | 1,5 sn |
| tank | 9 | 26 | 220 | 32 | 35 | 2,6 sn |
| kale | – | 60 | 800 | 34 | 7 | 1,8 sn |
| kule | – | 40 | 300 | 28 | 5 | 1,6 sn |

## 6. Savaş
- **Varlık (Ent):** hem birlik hem yapı için tek sınıf (`main.gd` içinde `class Ent`). Takım `player` ya da `enemy`.
- **Otomatik ateş:** menzilinde düşman olan herkes en yakınına ateş eder. Oyuncu tarafı sadece **görünür** rakibe ateş eder (sis hile yaptırmaz).
- **Komutlu saldırı:** `attack` hedefi ayarlanırsa birlik menzilin %85'ine kadar yaklaşır, durur, ateş eder. Hedef ölünce emir düşer.
- **Yakın dövüş** (mızraklı): hasar anında uygulanır. **Menzilli** (ok, mermi): mermi hedefi takip eder, yaya uçar, varınca hasar verir.
- **Can çubuğu:** her varlığın üstünde, kameraya dönük (`health_bar.gdshader`, örnek başına uniform). Bizimki yeşil→sarı→turuncu, rakip hep kırmızı. Yakınlık 420'yi aşınca gizlenir.
- Ölen varlık listelerden, can çubuğu ve sahneden kaldırılır. Kale yıkılınca bildirim çıkar. Rakipler şimdilik sadece menzildekilere ateş eder, yürüyüp kovalamaz.

## 6b. Animasyonlar (savaş ve seçim geri bildirimi)
- **Seçim:** seçilen birliğin halkası büyüyerek belirir.
- **Saldırı hedefi:** saldırılan rakibin altında kırmızı, nabız atan halka (oyuncu birlikleri ona saldırdığı sürece).
- **Saldırı hareketi:** mızraklı öne eğilir (yakın dövüş), okçu geriye sekiyor.
- **Vuruş:** hedef kısa süre büyüyüp küçülür, uçan hasar yazısı (`Label3D`) ve kıvılcım (`CPUParticles3D`) çıkar. Yakınlık 320'den uzaksa ve ekranda 30'dan fazla efekt varsa atlanır.
- **Ölüm:** birlik yere yıkılıp küçülür, yapı çöker.
- **Emir göstergesi:** çizgi, halka ve ok bir kez oynar (bkz. bölüm 3).

## 7. Ekonomi (KISMEN KODLANDI)
- **Çalışan kısım:** 3 kaynak gerçekten tutuluyor (`_res` in main.gd), HUD'a bağlı. Gelir şimdilik **sabit hızda** akıyor (48 yiyecek, 20 altın, 4 gümüş /dk), işçilere bağlı değil. Kaleden mızraklı (50Y 30A) ve okçu (40Y 50A) **anında** üretilir (Şehir sekmesi). Çağ kontrolü var (`era`).
- **Yok:** işçi ataması, bina, üretim süresi, kışla.
- Başlangıç: 248 yiyecek, 175 altın, 12 gümüş.
- Kaynaklar: yiyecek (tarla, balık çiftliği), altın (altın ocağı), gümüş (gümüş ocağı).
- Her üretim binasında 5 işçi yeri. İşçi başına üretim: tarla 6 yiyecek/dk, balık 8, altın ocağı 10 altın/dk, gümüş ocağı 4 gümüş/dk.
- İlk işçi 50 altın + 20 yiyecek, sonrakiler her biri %12 pahalı. Başlangıçta 2 işçi var.
- Uygulama kapalıyken üretim 8 saate kadar birikir.
- Ayrıntı ve tüm ekonomi tabloları tasarım artifact'ında.

## 8. Grafik mimarisi (2.5B)
- Godot 4.7, **Mobile** renderer. ACES tonlama, sis, güneş + gölge, prosedürel gökyüzü.
- Arazi: vertex renkli mesh + `terrain.gdshader`: sRGB→lineer, **tekrarlayan gürültü dokusundan renk çeşitliliği ve yüzey kabartması** (normal haritası dünya uzayında), **dik yamaçlar kayaya döner**, sis dokusu.
- Deniz: tek büyük düzlem, kamerayı izler, `water.gdshader`: iki katman kayan **dalga normali**, **derinliğe göre renk** (depth texture), **kıyı köpüğü**, Fresnel gökyüzü yansıması, sis.
- Bitki örtüsü (`vegetation.gdshader`, `Models.pine_mesh/broad_mesh/grass_mesh`, `WorldGen.vegetation`): her parça için **MultiMesh**. Çam (kuzey/kar), geniş yapraklı ağaç (güney), çimen tutamları. Rüzgâr sallanması vertex rengi alfasından. Düzeyler: yakın 3×3 parça = ağaç + çimen (+ ağaç gölgesi), 7×7'ye kadar sadece ağaç, ötesi yok. Kale çevresi (44 karo) ağaçtan temizlenir. Keşfedilmemiş bölgede bitki hiç çizilmez.
- Modeller şu an **kodla üretilen düşük poligonlu yer tutucular** (`models.gd`): kale, kule, mızraklı, okçu, işçi, izci (atlı), tank, gemi, tarla. Gerçek `glb` modellere ve dokulara geçiş planlı ("iyileştire iyileştire gidelim" kararı).
- Hedef: orta seviye telefonda 30 fps. Masaüstünde (RTX 4070 laptop) 120–240 fps ölçüldü; gerçek telefonda **henüz denenmedi**.

## 9. Dosya haritası
| Dosya | Görev |
|---|---|
| `project.godot` | Dikey 720×1280, Mobile renderer, dokunmadan fare emülasyonu kapalı |
| `scenes/main.tscn` | Tek düğümlü sahne, tüm kurulum `main.gd`'de kodla |
| `scripts/main.gd` | Sahne kurulumu, parçalar, varlıklar, seçim, emirler, hareket, savaş, göstergeler, girdi |
| `scripts/world_gen.gd` | Arazi üretimi, parça mesh'i, spawn arama |
| `scripts/fog.gd` | Sis hücreleri ve dokusu |
| `scripts/rts_camera.gd` | Eğik kamera, kaydırma, yakınlaştırma |
| `scripts/models.gd` | Kodla üretilen modeller |
| `scripts/units_data.gd` | Çağlar ve birim istatistikleri |
| `scripts/hud.gd` | Kaynak/çağ çubuğu, 4 sekmeli alt çubuk + bağlamsal paneller, ipucu, bildirim, kutu seçim çerçevesi. Tek `action(id)` sinyali |
| `shaders/*.gdshader` | Arazi, deniz, bitki örtüsü, can çubuğu |

## 9b. Uygulananlar (bu oturumun sonu)
- **Çağ sistemi:** `UnitsData.ERAS/TRAIN/KINDS`. Çağ başlığı üstte bir düğme; **dokununca geliştirici paneli** açılır (Çağ I–V seç, +1000 kaynak). Çağ değişince Şehir sekmesindeki üretim listesi o çağın birimleriyle yenilenir, petrol kaynağı Çağ III'te açılır.
  - Çağ I: işçi, mızraklı, okçu. Çağ II: işçi, tüfekli, süvari, top, **kadırga (gemi)**. Çağ III+: işçi, tüfekçi, tank, **muhrip (gemi)**. Çağ IV/V şimdilik Çağ III ile aynı (tasarlanacak).
  - Eski çağın birimleri artık üretilmez, var olanlar kalır.
- **Gemiler:** seçilir, sadece suda hareket eder (`naval`), kıyıdaki doğma noktasından üretilir (`_dock`), savaşır.
- **Kaynaklar:** yiyecek, odun, altın, gümüş, petrol. **Sabit gelir kaldırıldı**; sadece işçilerin kaynak noktalarında topladığı kadar artar.
- **İşçi görevleri:** işçileri seç, bir kaynak noktasına (tarla, odun kampı, altın/gümüş madeni, petrol kulesi) dokun. İşçi yürür ve toplar. Her noktada 5 işçi yeri, etiket "Tarla 2/5". Başka emir verilirse görevden çıkar. Üstteki kutularda net gelir /dk görünür. Oranlar (işçi başına /sn): tarla 0,30, odun 0,28, altın 0,20, gümüş 0,08, petrol 0,10.
- **Maliyetler** artık odun ve petrol içerebilir (örn. mızraklı 50Y 20O 20A, tank 220A 80G 40P). İşçi her yeni işçide %12 pahalanır. Kule/kale yükseltmesi odun ister.
- **Taş-kâğıt-makas:** `UnitsData.CLS` ve `MULT`. Ağır piyade süvariye ölümcül, hafif piyade ağır piyadeyi eritir, hafif süvari işçi ve kuşatmayı avlar, ağır süvari/tank hafif piyadeyi ezer, kuşatma yapıya 3× vurur. Hasar `_launch` içinde çarpanla hesaplanır.
- **Menzil halkası:** seçilen birlik/yapının saldırı menzili yerde ince halka olarak görünür.
- **Yapı yükseltme:** kule/kale seçilip para ile seviye 5'e kadar güçlendirilir (can +%30, hasar +%25, menzil +%6).

## 9b2. Uygulananlar (RoN referansı turu): ekonomi, arayüz, yapılar, arazi, efekt
Hedef tasarımın (9c, 9d) büyük kısmı bu turda kodlandı. Dosyalar: `fx.gd`, `minimap.gd`, `ui_menu.gd`, `ui_library.gd` (yeni), `hud.gd` (yeniden), `main.gd`, `models.gd`, `units_data.gd`, `world_gen.gd`.

- **Ana menü** (`ui_menu.gd`): Fetih senaryosu (devre dışı, yakında), Hızlı oyun (harita tipi: Kıtalar/Takımadalar/Dağlık; kural: Normal/Göçebe; barış süresi: yok/5/15 dk; mimari: Batı/Doğu/Orta Doğu/Mezoamerika), Ayarlar (oyun hızı 1×/1,5×/2×, kaydırma hızı). Test bayrakları menüyü atlar (`--menu` ile göster).
- **Göçebe:** kalesiz, 3 işçiyle başlanır, Kale inşa edilir. **Barış süresi:** süre dolana kadar kimse ateş etmez ve saldırı emri verilemez. **Harita tipleri:** `WorldGen` profili (deniz eğilimi, dağ şiddeti).
- **Üst panel:** 5 kaynak, her birinde toplam + net gelir/**ticaret sınırı** ("+24/150", net eksiyse kırmızı); **nüfus** "3/10" (dolunca kırmızı); çağ düğmesi; **boşta işçi** ikonu (yanıp söner, dokununca o işçiye gider). **Bakım:** askerler dakikada 1,2 yiyecek yer (işçi yemez). Ticaret sınırı çağa göre (150, 260, 420, 650, 950) ve Ticaret teknolojisiyle +%25/seviye.
- **Mini harita** (sağ üst): arazi, sis, birlik/yapı noktaları (bizimki mavi, görünür rakip kırmızı), ulusal sınırlar, kamera çerçevesi; dokununca kamera gider.
- **Ulusal sınır:** oyuncu kalesinin etrafında mavi, keşfedilmiş rakiplerde kırmızı kesikli, **dalga gibi kıpırdayan** halka. Sivil teknoloji oyuncu sınırını +%12/seviye büyütür. Düşman sınırı bir kaynak noktasını yutarsa o noktada üretim durur.
- **Komut kartı (yapı seçilince):** üretim ikonları (dokun = kuyruğa ekle, kuyruk düğmesine dokun = iptal ve iade), **üretim süresi** ve kuyruk, **toplanma noktası** (yeni birimler bayrağa yürür), yükseltme (kule/kale). Üretim yapıya göre: Kale (işçi, izci), Kışla (mızraklı, okçu, tüfekli, tüfekçi), Ahır (süvari, tank), Kuşatma fabrikası (top), Liman (gemiler).
- **Ordu kartı (Ordu sekmesi):** duruş **Saldırgan** (görüş alanındakini kovalar) / **Savunma** (bölgesini korur, işi bitince yerine döner) / **Sabit**; diziliş **Çizgi / Sütun / Kare / Dağınık**.
- **Bina inşası (İnşa sekmesi):** Ev (+5 nüfus), Kışla, Ahır, Kuşatma fabrikası, Liman (kıyıya yakın), Gözetleme kulesi (görüş 85), Kale. Bina seç → yere dokun → işçi gelir, inşaat alanı büyür ("İnşaat %40"), işçi sayısı hızlandırır, bitince gerçek yapı olur. Çağa göre açılır (Ahır, Kuşatma, Liman Çağ II'den).
- **Kütüphane** (L tuşu veya Şehir sekmesi): 4 sütun × 5 seviye (Askeri +10 nüfus, Sivil +%12 sınır, Ticaret +%25 toplama sınırı, Bilim −%10 araştırma/çağ maliyeti). **Gerçek çağ atlama:** en az iki sütun Seviye (çağ+1) olunca "Çağ atla" açılır, bedel ödenir, 20 sn ilerleme çubuğu dolar.
- **Çağa göre bina evrimi:** çağ atlayınca yapılar anında dönüşür: Çağ I ahşap/saman, II taş, III sanayi (beton, düz çatı, baca), IV+ modern (cam/çelik, yüksek). **Kültürel mimari:** Batı (konik çatı), Doğu (pagoda), Orta Doğu (kubbe), Mezoamerika (basamaklı piramit). Dört yapay zekâ ulusu dört farklı stilde.
- **Birim görünümü:** tahta mızrak/yay çağla çeliğe, metal parçalar parlayarak güncellenir (sadece işaretli parçalar; tam zırh/kıyafet değişimi yok).
- **Arazi mekaniği:** **yüksek zemin** (yukarıdaki menzilli birim +%25'e kadar menzil, +%30'a kadar hasar), **orman** (tank, ağır süvari, top %35 hıza düşer; piyade ormanda 10 karodan uzaktan görünmez = pusu), **sığlık** (kıyı şeridi, derin suya girilmez ama sığda yürünür, yarı hız), **uçurum** (çok dik yamaç geçit vermez). Nehir üretimi yok; geçitler kıyı sığlıklarından ibaret.
- **Fog of war:** gözetleme kulesi eklendi (görüş 85). Keşfedilmiş ama görünmeyen yerde düşman birimi görünmez (zaten vardı).
- **Görsel efektler (`fx.gd`):** namlu alevi + barut dumanı (tüfek, top, gemi), top mermisinde duman izi, çarpmada toz/toprak, hasarlı yapıda **yangın** (<%55 hafif, <%25 şiddetli), yıkılınca **enkaz** (40 sn durur), birlik ölünce toz. **Nükleer:** `Geliştirici paneli > Nükleer test`: ekran beyaz parlar, mantar bulutu, şok dalgası, 60 karo içindeki her şey yok olur, zemin kalıcı yanar (Decal) ve ağaçlar kaybolur.
- **Geliştirici paneli (çağ düğmesi):** çağ I–V, +1000 kaynak, Tüm binalar, Nükleer test.

### Kısmen yapıldı / yapılmadı (bu tura ait)
- **Bilgi kaynağı yok** (RoN'daki Bilgi): kütüphane mevcut 5 kaynakla çalışıyor. Üniversite/bilgin yok.
- **Harikalar sekmesi, tapınak, pazar, kervan, ticaret gemisi yok.**
- **Nadir kaynaklar ve tüccar yok.** **Ulus pasifleri ve özel birimler yok.**
- **Nükleer sadece geliştirici panelinden;** silo binası ve füze birimi yok. Kıyamet saati yok.
- **İkmal arabası/yıpranma, general, casus, hava birimleri, denizaltı, uçak gemisi yok.**
- **Nehirler ve belirgin sığ geçitler:** arazi üretiminde nehir yok.
- **Yapı sınırı/şehir sayısı** (Sivil teknolojiyle) uygulanmadı, sadece sınır halkası büyüyor. Ek şehir kurma yok.
- **Unpack (top kurulumu), siper, formasyona göre savaş bonusu yok.**
- Rakip yapay zekâ hâlâ hareketsiz (sadece menzildekine ateş eder).

## 9c. HEDEF TASARIM: Rise of Nations referansı (kullanıcının verdiği mantık)
Kullanıcı oyunun mantığının Rise of Nations'a benzemesini istedi. Aşağısı **hedef**; kodlanmadı (yukarıdaki "Uygulananlar" hariç).

### Ulusların kimliği (18+ ulus, her birinin pasifi ve özel birimi)
Örnekler: Türkler (kuşatma ucuz/uzun menzilli; Yeniçeri, Büyük Top), İngilizler (ekonomi/ticaret, okçu menzili; Uzun Yaylı Okçu), Moğollar (ahır ucuz ve hızlı, yıpranma almaz; atlı okçu), Ruslar (kendi topraklarında yıpranma 2×, petrol bonusu; Kazak, T-80), Romalılar (kışla ucuz, her yeni şehir altın; Lejyoner). Bizdeki 9 yapay zekâ ulusuna bu yapıda pasif + özel birim verilecek.

### Temel kaynaklar (RoN'daki karşılıklar)
Yiyecek (çiftlik, balıkçı), Odun (oduncu kampı), **Metal** (maden, Klasik Çağ'dan), **Servet/Altın** (kervan, pazar, ticaret; Klasik Çağ'dan), **Bilgi** (üniversite/bilgin; Orta Çağ'dan; çağ atlamak için zorunlu), **Petrol** (rafineri; Endüstri Çağı'ndan). Her çağda toplama hızının üst sınırı vardır (Commerce Cap). Bizdeki karşılık: yiyecek, odun, altın, gümüş (metal gibi düşün), petrol. **Bilgi** ve **ticaret/kervan** henüz yok.

### Nadir kaynaklar (haritada tek simge, tüccar gönderilip kamp kurulur; küresel pasif bonus)
- Antik/Klasik: Baharat (gıda limiti, kervan altını +%20), İpek (sınır genişler, ticari araştırma ucuz), Şeker (işçi/kervan hızı), Gümüş (pazar limiti), Mermer (harika/kale inşa hızı ve can), Obsidiyen (ilk çağ birimlerinin görüş ve zırhı).
- Orta Çağ/Barut: Pamuk (birim maliyeti düşer), Kürk (sınır koruması, yıpranma), Bakır (maden kapasitesi, kışla ucuz), Kutsal emanet (vergi, bilgi).
- Endüstri/Modern: Kömür (fabrika hızı, bina maliyeti), **Titanyum (tank/uçak petrol maliyeti −%25)**, Uranyum (nükleer yarı sürede, araştırma hızı), Alüminyum (uçak üretim hızı/can), Kauçuk (kara araç hızı).

### Birim ağacı (çağlara göre isimler)
- **Hafif piyade / menzilli:** Sapancı → Okçu → Arbaletli → Tüfekli → Tüfekçi → Piyade → Taarruz piyadesi. Ağır piyadeyi eritir, süvariye zayıf.
- **Ağır piyade (yakın dövüş):** Hoplit → Falanks → Uzun mızraklı → Fusilier → Tanksavar → Bazukalı → Güdümlü roketli. Süvariyi durdurur, menzilliye zayıf; sanayi çağından sonra tankın baş düşmanı.
- **Hafif süvari / keşif aracı:** Hafif atlı → Göçebe → Mızraklı süvari → Hussar → Zırhlı araç → Keşif arabası → Komando aracı. Kuşatma, ikmal arabası, general ve işçiye büyük bonus; ekonomiyi felç eder.
- **Ağır süvari / tank:** Ağır atlı → Şövalye → Cuirassier → Tank → Ağır tank → Ana muharebe tankı. Hafif piyadeyi ezer, ağır piyadeye zayıf.
- **Kuşatma:** Katapult → Mancınık → Top → Obüs → Howitzer → Roketatar. Binaya devasa hasar, savunmasız, çok yavaş, ateşlemeden önce kurulum (unpack) gerekir.
- **Hava savunma** (Endüstri'den): uçaksavar topu → AA bataryası → mobil füze savunması. Sadece uçağa vurur.
- **Lojistik/taktik:** **İkmal arabası** (düşman topraklarında yıpranmayı engeller, yavaş iyileştirir), **General** (hız ve zırh bonusu, Pusu ve Zorunlu yürüyüş yeteneği), **Casus** (rüşvetle birim çeker, suikast, bina içini görür; görünmez).
- **Deniz (Liman):** Hafif gemiler (Trireme → Sloop → Destroyer; denizaltıya karşı), ağır gemiler (War Galley → Frigate → Dreadnought → Battleship; kıyıyı bombalar), denizaltı (modern, görünmez, ağır gemiyi avlar, destroyer tespit eder), uçak gemisi.
- **Hava (Hava üssü, Endüstri'den):** Avcı (Fighter → Jet → Stealth; sadece hava), Bombardıman (Bomber → Strategic → Stealth; kara hedefi), Helikopter (modern; tanka karşı bonus).
- **Stratejik silah (Füze silosu, Bilgi çağı):** V-2/Seyir füzesi (tek bina/küme), **Nükleer füze** (bölgedeki her şeyi yok eder, kalıcı radyasyon bulutu). **Kıyamet saati kuralı:** çok fazla nükleer patlarsa herkes yenilir, maç berabere biter.

### Çağ içi bina evrimi
Çiftlik → Değirmen (+%20-40 gıda), Oduncu kampı → Kereste fabrikası, Maden → Dökümhane. Çağ atladıkça sivil binalar seviye atlar.

### Kütüphane teknoloji dörtlüsü
- **Askeri:** nüfus limiti, yeni birim seviyeleri (mızraklı → uzun mızraklı).
- **Sivil:** şehir sayısı limiti, sınır genişleme.
- **Ticaret:** toplama hızı üst sınırı, kervan geliri.
- **Bilim:** her şeyin maliyeti −%10-20, gizli kaynakları (metal, petrol) gösterir. Önceden bilimi yapmak uzun vadede kazandırır.

### Bu hedefe göre mevcut koddaki eşleşmeler
mızraklı = ağır piyade, okçu/tüfekli/tüfekçi = hafif piyade, süvari = hafif süvari, tank = ağır süvari, top = kuşatma, kadırga/muhrip = deniz. Eksik: ikmal arabası/yıpranma, general, casus, hava, denizaltı, uçak gemisi, silo, bilgi kaynağı, kütüphane, nadir kaynaklar, ulus pasifleri.

## 9d. HEDEF TASARIM: arayüz ve yönetim akışı (Rise of Nations referansı)
Kullanıcının verdiği ikinci referans. **Hedef; kodlanmadı** (mevcut arayüzün karşılığı sağda).

### Ana menü
- **Fetih senaryosu (sıra tabanlı dünya haritası):** ülkelerin üstünde "Ordu gücü" sayısı, orduyu düşman toprağına sürükleyince **gerçek zamanlı savaş haritasına** geçilir. (Bizim büyük dünya haritasıyla birleştirilebilir.)
- **Hızlı oyun:** Harita tipi (Orman yoğun / Takımadalar ve deniz savaşı / Dağlık geçitsiz). Kurallar: **Göçebe** (şehirsiz, 3 işçiyle başla), **Barış süresi** (ilk 15 dk saldırı yok).
- **Ayarlar:** oyun hızı, kaydırma hızı, kısayollar.
- Şu an: menü yok, oyun doğrudan açılıyor.

### Üst panel (ekonomi izleme)
Sırayla: Gıda, Odun, Metal, Altın, Bilgi, Petrol, **Ticaret sınırı**, **Nüfus**. Her kaynakta toplam ve dakikalık gelir (yeşil artı; **kırmızıysa bakım maliyeti geliri aşıyor**). Kilitli kaynaklar gri ve kilit simgeli (Bilgi Orta Çağ'dan, Petrol Endüstri'den), çağ atlayınca açılır. **Ticaret sınırı**: "+150 / 220" gibi, o çağda dakikada toplanabilecek azami miktar; dolunca işçi eklemek işe yaramaz, Kütüphane'nin Ticaret kolunu araştırmak gerekir. **Nüfus**: "45/100", üst sınır evler + askeri teknoloji; dolunca üretim durur.
- Şu an: 5 kaynak kutusu + çağ düğmesi var. Gelir /dk yazıyor. **Yok:** Ticaret sınırı, nüfus sayacı, kilitli kaynak simgesi, bakım maliyeti (kırmızı gelir).

### Sol alt (stratejik kontrol)
- **Mini harita** (kendi rengimiz parlak, müttefik mavi/yeşil, düşman kırmızı) ve **ulusal sınırlar** (renkli çizgi; şehir kurdukça ve Sivil teknolojiyle genişler; düşman sınırı kaynağı yutarsa oradaki işçiler çalışmayı durdurur).
- **Boşta kalan işçi** ikonu (yanıp söner, tıklayınca kamera o işçiye gider) ve **boşta bilgin** ikonu.
- Şu an: hiçbiri yok. İşçiler görevsizse haber verilmiyor.

### Sağ alt (komut kartı, seçime göre değişir)
- **İşçi seçili:** üç sekmeli inşaat klasörü: Ekonomik (çiftlik, oduncu, maden, pazar, tapınak, üniversite), Askeri (kışla, ahır, kuşatma fabrikası, liman, kale), Harikalar (çağa uygun anıtlar; başkası yapmaya başladıysa "İnşa ediliyor").
- **Askeri bina seçili:** üretim ikonları. **Sol tık = kuyruğa ekle, sağ tık = iptal.** **Yükseltme oku** (örn. "Tüfekliye yükselt": haritadaki tüm eski okçular otomatik tüfekliye döner). **Toplanma noktası**: binayı seçip yere sağ tık, yeni askerler bayrağa yürür.
- **Ordu seçili:** **formasyon** (Çizgi, Sütun, Kare) ve **saldırı modu**: Saldırgan (görünce haritanın ucuna kadar kovalar), Savunma (bölgesini korur), Sabit (yerinden kıpırdamaz, sadece menzildekine ateş eder).
- Şu an: üretim kaleden anında, kuyruk ve toplanma noktası yok, formasyon ve saldırı modu yok, yapı inşa etme yok (bina yerleşimi ön tanımlı). Birlikler menzildekine otomatik ateş eder (Savunma/Sabit karışımı).

### Kütüphane (L tuşu): 4 sütun × 8 satır
- **Askeri (kırmızı):** nüfus sınırı artar; 1. seviyede kışla, 3. seviyede kale limiti, son seviyede füze siloları.
- **Sivil (mavi):** şehir sayısı sınırı, sınırlar rakip topraklara baskı yapar.
- **Ticaret (sarı):** toplama sınırı ve kervan sayısı.
- **Bilim (beyaz):** diğer araştırmaların ve çağ atlamanın maliyeti her seviyede %10-15 düşer; gizli ham maddeleri gösterir.
- **Çağ atlama:** çağın gerektirdiği kadar araştırma yapılınca (örn. Klasik'e geçmek için iki sütunu 1. seviye) "Çağ Atla" düğmesi aktifleşir, üstte ilerleme çubuğu dolar.
- Şu an: Kütüphane yok, çağ sadece geliştirici panelinden değişiyor.

### Önerilen uygulama sırası (kullanıcı karar verecek)
1. **Nüfus sınırı + ev + kırmızı gelir uyarısı** (üst panel tamamlanır, ekonomiyi anlamlı sınırlar).
2. **Boşta işçi ikonu + mini harita + sınır çizgisi** (sol alt).
3. **Komut kartı:** üretim kuyruğu, toplanma noktası, ordu saldırı modu ve formasyon.
4. **Bina inşa etme** (işçiyle yerleştirme) + kışla/liman/ahır ayrımı.
5. **Kütüphane + gerçek çağ atlama.**
6. **Ana menü, harita tipleri, kurallar (Göçebe, Barış süresi).**

## 10. Kararlar ve nedenleri
- **Godot 4 (Compose değil):** 3B ve çok sayıda birim için oyun motoru gerekir.
- **Prosedürel dünya:** 1M karoyu saklamak yerine tohumdan üretmek kaydı küçük tutar.
- **2.5B (eğik sabit kamera):** tam 3B telefonda ağır, 2B ise "gerçekçi" isteğine uymaz.
- **Tek `Ent` sınıfı:** birlik ve yapı aynı savaş koduyla çalışır. Sözlük yerine sınıf kullanıldı çünkü sözlükler birbirine referans verince karşılaştırma sorun çıkarıyordu.
- **Çağlar:** kullanıcı, ilk çağlarda tank/motorlu araç olmamasını, mızraklı ve okçu olmasını istedi. Bu yüzden eski taslaktaki "Çağ I = piyade, komando, roketli" **geçersiz**, yukarıdaki tablo güncel.
- **Rakipler hâlâ dekor:** savaş altyapısı hazır, yapay zekâ davranışı (yürüyüş, saldırı, üretim) sonraki aşama.
