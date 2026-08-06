class_name SupabaseConfig
extends RefCounted

# supabase_config.gd — โหลด credentials จาก config/supabase.cfg

const CONFIG_PATH := "res://config/supabase.cfg"

static var url: String = ""
static var auth_url: String = ""
static var anon_key: String = ""
static var _loaded: bool = false


static func ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	var cfg := ConfigFile.new()
	if cfg.load(CONFIG_PATH) == OK:
		url = str(cfg.get_value("supabase", "url", "")).strip_edges()
		auth_url = str(cfg.get_value("supabase", "auth_url", "")).strip_edges()
		anon_key = str(cfg.get_value("supabase", "anon_key", "")).strip_edges()
	if url == "":
		push_warning("SupabaseConfig: missing config/supabase.cfg — using embedded defaults")
		url = "https://hfewlpkkflvahpcqoubr.supabase.co/rest/v1/"
		auth_url = "https://hfewlpkkflvahpcqoubr.supabase.co/auth/v1/"
		anon_key = "sb_publishable_x5EiaU-iJBPw7JpKF-0gyw_tCVp33lP"


static func host() -> String:
	ensure_loaded()
	return url.replace("https://", "").trim_suffix("/rest/v1/").trim_suffix("/")
