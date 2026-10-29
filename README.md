# Fetih Çağı (çalışma adı)

2.5B gerçek zamanlı strateji. Bu ilk **dikey dilim**: 1024×1024 karoluk dünyadan parça parça arazi, eğik kamera, yer tutucu modeller ve arayüz.

Tasarım ve haritalar: https://claude.ai/artifact/DgpdypXCVncWZc5wV9jpWL

Projeyi devralıyorsan önce `HANDOFF.md`, sonra `docs/PROJE_MANTIGI.md` oku.

## Çalıştırma
1. Godot **4.3 veya üstü** (standart sürüm) indir: https://godotengine.org/download
2. Godot'u aç, **Import** → bu klasördeki `project.godot`.
3. `F5` ile çalıştır. Pencere telefon oranında (dikey) açılır.

## Kontroller
- Sürükle: haritayı kaydır
- Fare tekerleği / iki parmak sıkıştır: yakınlaş-uzaklaş
- İzciye dokun: seç. Sonra haritada bir yere dokun: oraya gider ve sisi açar.
- Alt çubuk: Şehir (kaleye git), Keşif (izciyi seç ve kamerayı ona götür)

## Yapı
- `scripts/world_gen.gd`: tohumdan arazi (yükseklik, biyom), parça mesh üretimi, LOD
- `scripts/rts_camera.gd`: eğik kamera, kaydırma, yakınlaştırma
- `scripts/models.gd`: kodla üretilen düşük poligonlu modeller (yer tutucu)
- `scripts/hud.gd`: kaynak çubuğu ve gezinme çubuğu (yer tutucu değerler)
- `scripts/main.gd`: sahne kurulumu, parça yükleme/boşaltma, gösterim sahnesi

## Bilinen sınırlar
- Godot 4.7.2'de hatasız açılıp çalıştırıldı (NVIDIA RTX 4070 Laptop, Vulkan Mobile). Gerçek bir telefonda henüz denenmedi.
- Ekran görüntüsü almak için: `godot --path . -- --shot=yol.png --zoom=110`
- Parça üretimi GDScript ile ana iş parçacığında; ileride ayrı iş parçacığına alınacak.
- Sis (keşif), ekonomi, birlikler ve ulus yapay zekâsı yok.
