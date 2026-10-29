# Devir notu (sonraki yapay zekâ için)

Bu projeyi devralıyorsun. Önce bu dosyayı, sonra `docs/PROJE_MANTIGI.md`'yi oku. İkisi birlikte her şeyi anlatır.

## Kullanıcı
- **Türkçe** konuşur. Cevapları Türkçe, kısa ve düz yaz. Gereksiz tablo ve emoji kullanma.
- Mobil strateji oyunu geliştiriyor (Rise of Kingdoms benzeri, tek oyunculu). Android Studio kullanıyor ama bu proje Godot.
- Hızlı görmek ister: her değişiklikten sonra **oyunu açıp ona göstermeni** bekler (aşağıya bak).
- Karar bekleyen soruları sorarsan, öneriyle birlikte ve kısa sor.

## Durum (bu oturumun sonunda)
Çalışan dikey dilim. Masaüstünde Godot 4.7.2 ile hatasız çalışıyor.

**Var:** 1024×1024 prosedürel dünya (parça/LOD), eğik kamera, keşif sisi, çağ göstergesi (Çağ I), 2 işçi + 1 izci ile başlangıç, çoklu seçim (kutu, çift dokunma, Ordu sekmesi), hareket ve saldırı emirleri, emir göstergesi (bir kez oynar), otomatik ve komutlu savaş (ok/mermi), savaş animasyonları (hedef halkası, hasar yazısı, kıvılcım, ölüm), can çubukları, rakip karakol, **kaleden asker üretimi** (Şehir sekmesi, kaynaklar sabit hızda akıyor), sekmeli arayüz, **gerçekçi arazi** (doku, kayalı yamaçlar, ağaç, çimen, derinlikli ve köpüklü su).

**Ayrıca bu oturumun sonunda eklendi:** çağ sistemi + geliştirici paneli (çağ düğmesine dokun: Çağ I–V ve +1000 kaynak), çağa göre üretim listesi (Çağ I mızraklı/okçu, II tüfekli/süvari/top/kadırga, III tüfekçi/tank/muhrip), **gemiler** (suda hareket, savaş), **işçi görevleri** (işçi seç → kaynak noktasına dokun; tarla, odun, altın, gümüş, petrol), 5 kaynak (sabit gelir kaldırıldı), maliyetlerde odun/petrol, taş-kâğıt-makas hasar çarpanları, menzil halkası, kule/kale yükseltme. Ayrıntı `docs/PROJE_MANTIGI.md` bölüm 9b. **Hedef tasarım (Rise of Nations referansı) bölüm 9c'de**, kullanıcı mantığın böyle olmasını istedi.

**SON TUR (RoN arayüz + yönetim + yapılar + arazi + efekt):** ana menü, nüfus/bakım/ticaret sınırı, mini harita, sınır halkaları, boşta işçi, üretim kuyruğu/toplanma noktası, duruşlar/dizilişler, bina inşası, kütüphane + gerçek çağ atlama, çağa göre bina evrimi ve 4 mimari stil, arazi mekaniği (yüksek zemin, orman, sığlık, uçurum, pusu), görsel efektler (barut dumanı, yangın, enkaz, nükleer). **Tam liste ve eksikler: `docs/PROJE_MANTIGI.md` bölüm 9b2.** Aşağıdaki "Yok" listesinin 1, 2 ve 5. maddeleri büyük ölçüde YAPILDI (ayrıntı 9b2'de); eksik kalanlar 9b2'nin sonunda.
Test bayrakları (ek): `--menu` (menüyü göster), `--nomenu`, `--map=archipelago|mountains`, `--nomad`, `--peace=saniye`, `--style=west|east|mideast|meso`, `--lib` (kütüphaneyi aç), `--taptest` artık sistem testi yapar (`SYS ...` satırları: kuyruk, inşaat, nüfus, kütüphane, çağ atlama, duruş, nükleer).
Yeni dosyalar: `scripts/fx.gd`, `minimap.gd`, `ui_menu.gd`, `ui_library.gd`.

**Yok (sırayla yapılacaklar):**
1. **Ekonomi derinliği:** üretim süresi ve kışla/liman/hava üssü binaları (şu an üretim anında ve kaleden), Bilgi kaynağı, ticaret/kervan, her çağın toplama üst sınırı (Commerce Cap), bina evrimi (değirmen, kereste fabrikası), nadir kaynaklar ve tüccar.
2. **Çağ atlama:** şu an çağ sadece geliştirici panelinden değişiyor. Gerçek çağ atlama bilgi + altın + gümüşle olmalı. Kütüphane (askeri/sivil/ticaret/bilim). Çağa göre yapı/model görünümü (kale ve kule hâlâ aynı model).
3. **Eksik birimler (bölüm 9c):** ikmal arabası + yıpranma, general, casus, hava birimleri, denizaltı, uçak gemisi, silo ve nükleer. Çağ IV ve V içerikleri tasarlanmadı.
4. **Ulus kimliği:** her yapay zekâ ulusuna pasif + özel birim.
5. **Arayüz ve yönetim akışı (RoN referansı, `docs/PROJE_MANTIGI.md` bölüm 9d):** nüfus sınırı ve ticaret sınırı, boşta işçi ikonu, mini harita ve sınırlar, üretim kuyruğu ve toplanma noktası, ordu formasyonu ve saldırı modları, bina inşa etme, Kütüphane ve gerçek çağ atlama, ana menü ve oyun kuralları (Göçebe, Barış süresi). Bölüm 9d'nin sonunda önerilen sıra var; kullanıcıdan onay al.
3. **Rakip yapay zekâ:** şu an rakipler yerinde duruyor, sadece menzildekilere ateş ediyor. Yürüme, saldırma, üretim ve ulus kişilikleri (tasarımda: Kızıl saldırgan, Zümrüt tüccar, vb.) lazım.
4. **Yol bulma:** birlikler düz çizgide gidiyor, suya girince duruyor. Parça bazlı hiyerarşik A* planlı.
5. **Donanma ve gemiler:** tasarımda var (tersane, nakliye, muhrip, denizaltı...), kodda yok. Gemi şu an sadece dekor.
6. **Kayıt/yükleme:** tohum + oyuncu durumu + keşif hücreleri.
7. **Görsel iyileştirme:** kullanıcı "iyileştire iyileştire gidelim" dedi. Gerçek `glb` model ve doku, gerçekçi karakterler. Şu an hepsi koddan üretilen basit şekiller.
8. **Gerçek telefonda test** ve parça üretimini ayrı iş parçacığına alma (hızlı kaydırmada küçük takılma olabilir).

## Çalıştırma ve test
Godot winget ile kurulu: `GodotEngine.GodotEngine` 4.7.2. Yolu:
```
C:\Users\BUROSTATIK\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7.2-stable_win64.exe        (pencereli)
...\Godot_v4.7.2-stable_win64_console.exe                                                                                                              (konsol, çıktıyı görmek için)
```
Proje: `C:\Users\BUROSTATIK\GodotProjects\FetihCagi`

- **Hata kontrolü (pencere açmadan):** `console.exe --headless --path <proje> --quit-after 200`. Çıktı boşsa betik hatası yok. (Gölgelendirici hataları headless'ta görünmez, pencereli çalıştır.)
- **Oyunu kullanıcıya aç:** `Start-Process <pencereli exe> -ArgumentList '--path','<proje>'`. Önce açık Godot'u kapat (`Get-Process Godot* | Stop-Process`).
- **Ekran görüntüsü alıp kendin bak** (çok işe yarıyor): `console.exe --path <proje> -- --shot=C:\...\x.png --zoom=110 --wait=4`, sonra PNG'yi Read ile aç.
- Test argümanları (`--` sonrası): `--shot=yol.png`, `--wait=saniye` (varsayılan 4), `--zoom=N`, `--look=dx,dz` (kamera kaydır), `--army` (mızraklı + okçu ile başla), `--era=N` (N≥3 tank açar), `--move=dx,dz` (tümü oraya gitsin), `--atk` (tümü rakip kaleye saldırsın; `--wait=17` ile), `--tab=Şehir|Ordu|Keşif|Uluslar` (sekmeyi açık başlat), `--taptest` (gerçek dokunma yolunu ve üretimi sınar, konsola `TAPTEST`/`TRAINTEST` yazar). Telefon boyutunda ekran görüntüsü için Godot'a `--resolution 450x800` ver (`--`'dan ÖNCE). Test çalışırken oyun çıkışında "RID leaked" hataları normaldir.
- Test klavyesi: **H** seçili birliklere %25 hasar verir. **Shift + sürükle** kutu seçer.

## Kod kuralları ve tuzaklar (bunlara takıldım)
- **`class_name` kullanma.** Betikler `const X = preload("res://...")` ile yükleniyor. Düzenleyici açılmadan global sınıf önbelleği oluşmuyor.
- Düğüm adlarıyla çakışan değişken adları (`show`, `name`) hata veriyor. `show` değişken adı yüzünden betik yüklenmedi.
- **Sözlükleri birbirine referans verir hâle getirme** (döngüsel). `Array.erase()` ve `==` sorun çıkarır. Bu yüzden varlıklar `Ent` sınıfı (nesne referansı) ile tutuluyor. Sözlükte kimlik karşılaştırması gerekirse `is_same()`.
- Vertex renkleri sRGB: `terrain.gdshader` içinde elle lineere çevriliyor. StandardMaterial3D kullanırsan `vertex_color_is_srgb = true`.
- `emulate_mouse_from_touch=false` (project.godot): dokunma hem fare hem dokunma olayı üretip ikiye bölünmesin diye. Kamera ve `main.gd` hem fare hem `InputEventScreenTouch/Drag` dinliyor.
- Alt çubuk ve köşe yazısı **sabit offset** ile yerleştirilmiş. `PRESET_MODE_MINSIZE` ile ekran dışına taşmıştı.
- Can çubukları ve emir çizgisi `no_depth_test`/`depth_test_disabled` ile çiziliyor, tepelerin arkasında da görünsün diye.
- Yeni birim eklerken: `units_data.gd` `KINDS`, `models.gd` modeli, `main.gd` `_place_world`/üretim. Savaş ve can çubuğu otomatik çalışır.

## Kullanıcının verdiği tasarım kararları (bozma)
- Oyun artık **top oyunu değil**, gerçek zamanlı strateji. Süreli maç yok.
- Dünya 1024×1024, 2.5B (eğik sabit kamera), **Godot**.
- Başlangıçta **2 işçi** yeter (asker/tank yok). Oyunda "köle" değil "işçi" deniyor.
- Çağa göre birim: ilk çağlarda **mızraklı ve okçu**, tank/motorlu araç yok. Çağ üstte gösterilir.
- Emir göstergesi: çizgi ve animasyon **sadece emir verildiğinde bir kez** gösterilir, ince ve koyu renkli.
- Rakibe dokunmak saldırı emridir. Birlikler menzil dahilinde ateş eder, menzil çağa/birime göre değişir.
- Can çubuğu iki tarafta da görünür.
- Birlikleri çoklu seçebilmeli, yoldaki birliği seçip emri değiştirebilmeli.
- Karakterleri ve grafikleri **adım adım iyileştirme** tercih ediliyor.

## Kaynaklar
- Tasarım artifact'ı (senaryo, dünya haritası, çağ/birim ağacı, şehir ekonomisi, telefon arayüzü): https://claude.ai/artifact/DgpdypXCVncWZc5wV9jpWL (özel, sadece kullanıcı açar). **Not:** artifact'taki Çağ I = "piyade, komando, roketli" ve "araba/motorlu/tank" bölümleri eski taslak; güncel çağ tablosu `docs/PROJE_MANTIGI.md` bölüm 5.
- Eski oyunun notları (ColorBurst, terk edildi): `C:\Users\BUROSTATIK\AndroidStudioProjects\ColorBurst\docs\onceki-tasarim-notlari.md`.

## Doğrulanmadı
- Gerçek telefonda dokunma, kutu seçim ve performans.
- Kutu seçimi, çift dokunma ve hedef animasyonu fare ile elle denenmedi (kod ve ekran görüntüleriyle doğrulandı).
- Çağ II ve sonrası birimlerin modeli/istatistiği tasarım aşamasında.
