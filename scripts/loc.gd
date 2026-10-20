class_name Loc
extends RefCounted
## UI text. Each key maps to [Turkish, English]. The language comes from Save.settings.

const TEXT := {
	"tagline": ["Boğaz’ın üstünde, simit peşinde bir martı koşusu", "A seagull run over the Bosphorus, hunting simit"],
	"how_steer": ["Yön: ok tuşları / WASD, fare ya da parmak", "Steer: arrow keys / WASD, or move the mouse or your finger"],
	"how_dive": ["Dalış: Boşluk, fare tıkla ya da dokun (balık için)", "Dive: hold Space, click or tap (for fish)"],
	"how_simit": ["Simit kap: enerjin dolsun, kombo kur, rüzgârı yakala", "Snatch simit: refill your stamina, build a combo, catch a tailwind"],
	"how_avoid": ["Kaçın: köprü, gemi direkleri ve uçurtmalar. Rakip sürü simit çalar", "Avoid: bridge, ship masts and kites. The rival flock steals your simit"],
	"start": ["Başla", "Start"],
	"settings": ["Ayarlar", "Settings"],
	"back": ["Geri", "Back"],
	"retry": ["Tekrar dene", "Retry"],
	"resume": ["Devam et", "Resume"],
	"menu": ["Ana menü", "Main menu"],
	"paused": ["Duraklatıldı", "Paused"],
	"over": ["Koşu bitti", "Run over"],
	"score": ["Skor", "Score"],
	"best": ["En iyi", "Best"],
	"dist": ["Mesafe", "Distance"],
	"simit": ["Simit", "Simit"],
	"combo": ["Kombo", "Combo"],
	"stamina": ["Enerji", "Stamina"],
	"missions": ["Günlük görevler", "Daily missions"],
	"highs": ["Yüksek skorlar", "High scores"],
	"hint": ["P duraklat · M müzik · X ses · L English", "P pause · M music · X sound · L Türkçe"],
	"new_best": ["Yeni rekor!", "New record!"],
	"steal": ["Sürü simitini çaldı!", "The flock stole your simit!"],
	"shield": ["Kalkan tüyü! Bir çarpmayı emer", "Shield feather! Blocks one hit"],
	"shield_used": ["Kalkan çarpmayı emdi!", "The shield absorbed a hit!"],
	"hit": ["Çarpıştın!", "Hit!"],
	"tail": ["Kuyruk rüzgârı! Hız ve skor x1.5", "Tailwind! Speed and score x1.5"],
	"gold": ["Altın simit! Skor x2", "Golden simit! Score x2"],
	"mission_done": ["Görev tamam", "Mission complete"],
	"fly": ["İyi uçuşlar!", "Have a good flight!"],
	"crash": ["Çarpıştın", "Crashed"],
	"energy": ["Enerjin bitti", "Out of stamina"],
	"music": ["Müzik", "Music"],
	"sfx": ["Ses efekti", "Sound effects"],
	"master": ["Genel ses", "Master volume"],
	"language": ["Dil", "Language"],
	"quality": ["Kalite", "Quality"],
	"quality_low": ["Düşük", "Low"],
	"quality_high": ["Yüksek", "High"],
	"fullscreen": ["Tam ekran", "Fullscreen"],
	"on": ["Açık", "On"],
	"off": ["Kapalı", "Off"],
	"pause_btn": ["Duraklat", "Pause"],
	"music_btn": ["Müzik", "Music"],
	"sfx_btn": ["Ses", "SFX"],
	"meters": ["m", "m"],
	"km": ["km", "km"],
	"left": ["kaldı", "left"],
	"lives": ["Can", "Lives"],
	"chip_tail": ["Kuyruk rüzgârı", "Tailwind"],
	"chip_gold": ["Altın simit x2", "Golden x2"],
	"chip_shield": ["Kalkan hazır", "Shield ready"],
	"reason_crash": ["Çarptı", "Crashed"],
	"reason_energy": ["Enerji bitti", "Out of energy"],
}


static func lang() -> String:
	return Save.settings.get("language", "tr")


static func t(key: String) -> String:
	var pair: Array = TEXT.get(key, [key, key])
	return pair[1] if lang() == "en" else pair[0]


static func other_lang_button() -> String:
	return "TR" if lang() == "en" else "EN"


static func format_distance(meters: float) -> String:
	if meters >= 1000.0:
		return "%.2f %s" % [meters / 1000.0, t("km")]
	return "%d %s" % [roundi(meters), t("meters")]
