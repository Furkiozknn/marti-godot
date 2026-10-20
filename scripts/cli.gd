class_name Cli
extends RefCounted
## Reads the user arguments given after "--", e.g. godot ... -- --auto --no-save --t0=120

static func has_flag(flag: String) -> bool:
	return OS.get_cmdline_user_args().has(flag)


static func value_of(key: String, fallback: String) -> String:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with(key + "="):
			return arg.substr(key.length() + 1)
	return fallback
