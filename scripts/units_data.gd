extends RefCounted
## Çağlar, kaynaklar ve birim istatistikleri. Sayılar başlangıç değeridir, dengeleme testiyle değişecek.

const ERAS := [
	{"roman": "I", "name": "Kılıç ve Ok"},
	{"roman": "II", "name": "Barut"},
	{"roman": "III", "name": "Sanayi"},
	{"roman": "IV", "name": "Modern"},
	{"roman": "V", "name": "Atom"},
]

const RES_KEYS := ["food", "wood", "gold", "silver", "oil"]
const RES_TITLES := {"food": "Yiyecek", "wood": "Odun", "gold": "Altın", "silver": "Gümüş", "oil": "Petrol"}
const RES_SHORT := {"food": "Y", "wood": "O", "gold": "A", "silver": "G", "oil": "P"}
const OIL_ERA := 2  # petrol kaynağı ve kulesi Çağ III'ten (indeks 2) itibaren açılır

# Çağa göre üretilebilen birimler. Eski çağın birimleri artık üretilmez, mevcutlar kalır.
# Çağ IV ve V şimdilik Çağ III ile aynı (tasarlanacak).
const TRAIN := [
	["worker", "scout", "spearman", "archer"],
	["worker", "scout", "musketeer", "cavalry", "cannon", "galleon"],
	["worker", "scout", "rifleman", "tank", "destroyer"],
	["worker", "scout", "rifleman", "tank", "destroyer"],
	["worker", "scout", "rifleman", "tank", "destroyer"],
]

# era: birliğin açıldığı çağ (0 = Çağ I). proj: "" yakın dövüş, "arrow", "bullet", "shell".
# sight: görüş yarıçapı (karo). range: saldırı menzili (karo). naval: sadece suda hareket eder.
const KINDS := {
	"worker": {"era": 0, "speed": 6.0, "sight": 14.0, "hp": 30.0, "range": 0.0, "dmg": 0.0, "cd": 1.0,
		"proj": "", "bar_off": 3.0, "bar_size": 0.7, "ring": 0.5, "title": "İşçi",
		"cost": {"food": 20, "gold": 50}},
	"scout": {"era": 0, "speed": 14.0, "sight": 48.0, "hp": 40.0, "range": 0.0, "dmg": 0.0, "cd": 1.0,
		"proj": "", "bar_off": 4.6, "bar_size": 0.8, "ring": 0.9, "title": "İzci",
		"cost": {"food": 30, "gold": 30}},
	"spearman": {"era": 0, "speed": 7.0, "sight": 16.0, "hp": 70.0, "range": 3.5, "dmg": 9.0, "cd": 0.9,
		"proj": "", "bar_off": 3.2, "bar_size": 0.7, "ring": 0.5, "title": "Mızraklı",
		"cost": {"food": 50, "wood": 20, "gold": 20}},
	"archer": {"era": 0, "speed": 7.0, "sight": 18.0, "hp": 45.0, "range": 24.0, "dmg": 6.0, "cd": 1.5,
		"proj": "arrow", "bar_off": 3.2, "bar_size": 0.7, "ring": 0.5, "title": "Okçu",
		"cost": {"food": 40, "wood": 35, "gold": 30}},
	"musketeer": {"era": 1, "speed": 6.5, "sight": 18.0, "hp": 60.0, "range": 20.0, "dmg": 16.0, "cd": 2.4,
		"proj": "bullet", "bar_off": 3.2, "bar_size": 0.7, "ring": 0.5, "title": "Tüfekli",
		"cost": {"food": 60, "wood": 10, "gold": 50, "silver": 10}},
	"cavalry": {"era": 1, "speed": 12.0, "sight": 22.0, "hp": 90.0, "range": 3.5, "dmg": 14.0, "cd": 1.0,
		"proj": "", "bar_off": 4.8, "bar_size": 0.9, "ring": 0.9, "title": "Süvari",
		"cost": {"food": 80, "wood": 20, "gold": 60}},
	"cannon": {"era": 1, "speed": 4.0, "sight": 20.0, "hp": 80.0, "range": 42.0, "dmg": 45.0, "cd": 5.0,
		"proj": "shell", "bar_off": 3.4, "bar_size": 0.9, "ring": 1.0, "title": "Top",
		"cost": {"wood": 60, "gold": 120, "silver": 30}},
	"rifleman": {"era": 2, "speed": 7.0, "sight": 20.0, "hp": 80.0, "range": 26.0, "dmg": 14.0, "cd": 1.2,
		"proj": "bullet", "bar_off": 3.2, "bar_size": 0.7, "ring": 0.5, "title": "Tüfekçi",
		"cost": {"food": 70, "gold": 60, "silver": 15}},
	"tank": {"era": 2, "speed": 9.0, "sight": 26.0, "hp": 220.0, "range": 32.0, "dmg": 35.0, "cd": 2.6,
		"proj": "shell", "bar_off": 3.4, "bar_size": 1.0, "ring": 1.2, "title": "Tank",
		"cost": {"gold": 220, "silver": 80, "oil": 40}},
	"galleon": {"era": 1, "naval": true, "speed": 8.0, "sight": 30.0, "hp": 260.0, "range": 30.0, "dmg": 22.0,
		"cd": 3.0, "proj": "shell", "bar_off": 8.0, "bar_size": 1.6, "ring": 3.2, "title": "Kadırga",
		"cost": {"wood": 120, "gold": 100, "silver": 20}},
	"destroyer": {"era": 2, "naval": true, "speed": 12.0, "sight": 36.0, "hp": 420.0, "range": 40.0, "dmg": 30.0,
		"cd": 2.2, "proj": "shell", "bar_off": 8.0, "bar_size": 1.8, "ring": 3.4, "title": "Muhrip",
		"cost": {"gold": 200, "silver": 100, "oil": 60}},
	# Yapılar. trains: üretebildiği birimler (çağ filtresi TRAIN ile). btime: inşaat süresi (sn). pop: nüfus sınırına katkı.
	"castle": {"era": 0, "speed": 0.0, "sight": 60.0, "hp": 800.0, "range": 34.0, "dmg": 7.0, "cd": 1.8,
		"proj": "arrow", "bar_off": 13.0, "bar_size": 3.4, "ring": 0.0, "body_r": 7.0, "title": "Kale",
		"trains": ["worker", "scout"], "pop": 10, "btime": 25.0, "cost": {"wood": 250, "gold": 200}},
	"lookout": {"era": 0, "speed": 0.0, "sight": 85.0, "hp": 160.0, "range": 0.0, "dmg": 0.0, "cd": 1.0,
		"proj": "", "bar_off": 11.5, "bar_size": 1.0, "ring": 0.0, "body_r": 1.8, "title": "Gözetleme kulesi",
		"btime": 6.0, "cost": {"wood": 60}},
	"house": {"era": 0, "speed": 0.0, "sight": 14.0, "hp": 150.0, "range": 0.0, "dmg": 0.0, "cd": 1.0,
		"proj": "", "bar_off": 6.0, "bar_size": 1.1, "ring": 0.0, "body_r": 3.0, "title": "Ev",
		"pop": 5, "btime": 6.0, "cost": {"wood": 60}},
	"barracks": {"era": 0, "speed": 0.0, "sight": 22.0, "hp": 420.0, "range": 0.0, "dmg": 0.0, "cd": 1.0,
		"proj": "", "bar_off": 8.0, "bar_size": 1.7, "ring": 0.0, "body_r": 5.0, "title": "Kışla",
		"trains": ["spearman", "archer", "musketeer", "rifleman"], "btime": 12.0,
		"cost": {"wood": 100, "gold": 40}},
	"stable": {"era": 1, "speed": 0.0, "sight": 22.0, "hp": 420.0, "range": 0.0, "dmg": 0.0, "cd": 1.0,
		"proj": "", "bar_off": 8.0, "bar_size": 1.7, "ring": 0.0, "body_r": 5.0, "title": "Ahır",
		"trains": ["cavalry", "tank"], "btime": 12.0, "cost": {"wood": 120, "gold": 60}},
	"siege": {"era": 1, "speed": 0.0, "sight": 22.0, "hp": 450.0, "range": 0.0, "dmg": 0.0, "cd": 1.0,
		"proj": "", "bar_off": 8.0, "bar_size": 1.7, "ring": 0.0, "body_r": 5.0, "title": "Kuşatma fabrikası",
		"trains": ["cannon"], "btime": 14.0, "cost": {"wood": 150, "gold": 100, "silver": 30}},
	"dock": {"era": 1, "speed": 0.0, "sight": 26.0, "hp": 380.0, "range": 0.0, "dmg": 0.0, "cd": 1.0,
		"proj": "", "bar_off": 7.0, "bar_size": 1.7, "ring": 0.0, "body_r": 5.0, "title": "Liman",
		"trains": ["galleon", "destroyer"], "btime": 14.0, "cost": {"wood": 180, "gold": 80}},
	"tower": {"era": 0, "speed": 0.0, "sight": 40.0, "hp": 300.0, "range": 28.0, "dmg": 5.0, "cd": 1.6,
		"proj": "arrow", "bar_off": 9.2, "bar_size": 1.6, "ring": 0.0, "body_r": 2.5},
}

# Sınıflar (Rise of Nations tarzı taş-kâğıt-makas):
#   heavy_inf  ağır piyade (mızraklı): süvariye ölümcül, menzilliye zayıf
#   light_inf  hafif piyade / menzilli (okçu, tüfekli): ağır piyadeyi eritir, süvariye zayıf
#   light_cav  hafif süvari: kuşatmayı ve işçiyi avlar, ağır piyadeye zayıf
#   heavy_cav  ağır süvari / tank: hafif piyadeyi ezer, ağır piyadeye zayıf
#   siege      kuşatma (top): yapılara büyük hasar, savunmasız
#   naval      donanma
# Üretim süresi (sn); yoksa 8.
const TTIME := {"worker": 5.0, "scout": 6.0, "spearman": 7.0, "archer": 8.0, "musketeer": 9.0, "cavalry": 9.0,
	"cannon": 14.0, "rifleman": 9.0, "tank": 16.0, "galleon": 14.0, "destroyer": 18.0}

# İnşa sekmesindeki bina sırası
const BUILD_LIST := ["house", "barracks", "stable", "siege", "dock", "lookout", "castle"]

# Kütüphane: 4 sütun x 5 satır. Her seviye bir öncekinin açılmasını ister.
const LIB_COLS := [
	{"id": "mil", "title": "Askeri", "color": Color("e05252"), "desc": "+10 nüfus"},
	{"id": "civ", "title": "Sivil", "color": Color("4a86e8"), "desc": "+%12 sınır"},
	{"id": "com", "title": "Ticaret", "color": Color("f0c64a"), "desc": "+%25 toplama sınırı"},
	{"id": "sci", "title": "Bilim", "color": Color("e8ecfa"), "desc": "-%10 araştırma maliyeti"},
]
const LIB_ROWS := 5
const LIB_COST := [
	{"food": 60, "gold": 40},
	{"food": 120, "wood": 80, "gold": 90},
	{"food": 220, "wood": 150, "gold": 170, "silver": 20},
	{"food": 380, "wood": 260, "gold": 300, "silver": 60},
	{"food": 600, "wood": 420, "gold": 520, "silver": 120},
]
# Çağ atlama bedeli (mevcut çağdan sonrakine) ve süresi (sn).
const AGE_COST := [
	{"food": 300, "wood": 200, "gold": 250, "silver": 30},
	{"food": 500, "wood": 350, "gold": 450, "silver": 80},
	{"food": 800, "wood": 500, "gold": 700, "silver": 150, "oil": 60},
	{"food": 1200, "wood": 800, "gold": 1100, "silver": 300, "oil": 150},
]
const AGE_TIME := 20.0
# Çağlara göre dakikalık toplama üst sınırı (Ticaret teknolojisiyle artar).
const COM_CAP := [150.0, 260.0, 420.0, 650.0, 950.0]
const BASE_POP := 10

const CLS := {
	"worker": "civil", "scout": "civil",
	"spearman": "heavy_inf", "archer": "light_inf", "musketeer": "light_inf", "rifleman": "light_inf",
	"cavalry": "light_cav", "tank": "heavy_cav", "cannon": "siege",
	"galleon": "naval", "destroyer": "naval",
	"castle": "structure", "tower": "structure", "house": "structure", "barracks": "structure",
	"stable": "structure", "siege": "structure", "dock": "structure", "lookout": "structure",
}

# MULT[saldıran][hedef] = hasar çarpanı (yoksa 1.0)
const MULT := {
	"heavy_inf": {"light_cav": 2.0, "heavy_cav": 1.6, "light_inf": 0.6, "siege": 1.2, "structure": 0.4},
	"light_inf": {"heavy_inf": 1.8, "light_cav": 0.6, "heavy_cav": 0.7, "structure": 0.3},
	"light_cav": {"siege": 2.0, "civil": 2.0, "light_inf": 1.5, "heavy_inf": 0.5, "heavy_cav": 0.7, "structure": 0.3},
	"heavy_cav": {"light_inf": 2.0, "light_cav": 1.3, "heavy_inf": 0.5, "siege": 1.5, "structure": 0.6},
	"siege": {"structure": 3.0, "light_inf": 1.2, "heavy_inf": 1.2, "light_cav": 0.6, "heavy_cav": 0.8},
	"naval": {"structure": 1.5, "civil": 1.2},
	"structure": {"siege": 1.2},
}


static func multiplier(attacker_kind: String, target_kind: String) -> float:
	var a: String = CLS.get(attacker_kind, "")
	var t: String = CLS.get(target_kind, "")
	if MULT.has(a):
		return float((MULT[a] as Dictionary).get(t, 1.0))
	return 1.0
