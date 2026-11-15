extends SceneTree
## Official Godot 4.7 Headless Delta PCK Builder, Dependency/Import Packer, Verifier & RSA Signer.
##
## Modes:
##   1. Build & Verify PCK:
##      godot --headless --path . -s res://tools/pck_builder.gd -- --out=res://updates/patch.pck --files=res://... [--sign-payload=...] [--priv-key=...]
##   2. Verify existing PCK:
##      godot --headless --path . -s res://tools/pck_builder.gd -- --verify-pck=res://updates/patch.pck --files=res://...
##   3. Generate RSA-2048 keypair (public key in res://launcher/update_pub.key, private key in user://update_priv.key):
##      godot --headless --path . -s res://tools/pck_builder.gd -- --gen-keys

const PUB_KEY_PATH := "res://launcher/update_pub.key"
const DEFAULT_PRIV_KEY_PATH := "user://update_priv.key"

var _exit_code := 0


func _process(_delta: float) -> bool:
	quit(_exit_code)
	return true


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if "--gen-keys" in args:
		_generate_keys()
		_exit_code = 0
		return

	var verify_only := ""
	var out_path := "res://updates/patch_latest.pck"
	var files := PackedStringArray()
	var sign_payload := ""
	var priv_key_path := DEFAULT_PRIV_KEY_PATH

	for a in args:
		if a.begins_with("--verify-pck="):
			verify_only = a.trim_prefix("--verify-pck=")
		elif a.begins_with("--out="):
			out_path = a.trim_prefix("--out=")
		elif a.begins_with("--files="):
			files = a.trim_prefix("--files=").split(",", false)
		elif a.begins_with("--sign-payload="):
			sign_payload = a.trim_prefix("--sign-payload=")
		elif a.begins_with("--priv-key="):
			priv_key_path = a.trim_prefix("--priv-key=")

	if verify_only != "":
		var ok := _verify_pck(verify_only, files)
		print("PCK_VERIFY_%s path=%s" % ["OK" if ok else "FAIL", verify_only])
		_exit_code = 0 if ok else 1
		return

	if files.is_empty():
		print("PCK_BUILDER ERROR: No --files specified")
		_exit_code = 1
		return

	var abs_out := _abs(out_path)
	DirAccess.make_dir_recursive_absolute(abs_out.get_base_dir())

	var packer := PCKPacker.new()
	var err := packer.pck_start(abs_out)
	if err != OK:
		print("PCK_BUILDER ERROR: pck_start failed with code ", err)
		_exit_code = 1
		return

	var packed_set := {}
	for f in files:
		var target := f if f.begins_with("res://") else ("res://" + f.trim_prefix("/"))
		_pack_with_imports(packer, target, packed_set)

	var flush_err := packer.flush(false)
	if flush_err != OK:
		print("PCK_BUILDER ERROR: flush failed with code ", flush_err)
		_exit_code = 1
		return

	if not _verify_pck(abs_out, files):
		print("PCK_BUILDER ERROR: Post-build verification failed for ", abs_out)
		_exit_code = 1
		return

	var sha := FileAccess.get_sha256(abs_out)
	var fcheck := FileAccess.open(abs_out, FileAccess.READ)
	var sz := fcheck.get_length() if fcheck else 0
	if fcheck:
		fcheck.close()

	var sig_b64 := ""
	if sign_payload != "":
		sig_b64 = _sign_string(sign_payload, priv_key_path)

	print("PCK_BUILDER_OK path=%s files=%d size=%d sha256=%s sig=%s" % [abs_out, packed_set.size(), sz, sha, sig_b64])
	_exit_code = 0


func _abs(p: String) -> String:
	if p.begins_with("res://") or p.begins_with("user://"):
		return ProjectSettings.globalize_path(p)
	return p


func _pack_file_once(packer: PCKPacker, target_res: String, packed_set: Dictionary) -> void:
	if packed_set.has(target_res):
		return
	var src := _abs(target_res)
	if not FileAccess.file_exists(src):
		return
	if packer.add_file(target_res, src) == OK:
		packed_set[target_res] = true


func _pack_with_imports(packer: PCKPacker, target_res: String, packed_set: Dictionary) -> void:
	_pack_file_once(packer, target_res, packed_set)
	var src := _abs(target_res)
	if FileAccess.file_exists(src + ".uid"):
		_pack_file_once(packer, target_res + ".uid", packed_set)
	var import_file := src + ".import"
	if FileAccess.file_exists(import_file):
		_pack_file_once(packer, target_res + ".import", packed_set)
		var cf := ConfigFile.new()
		if cf.load(import_file) == OK:
			if cf.has_section("remap"):
				for k in cf.get_section_keys("remap"):
					if k == "path" or k.begins_with("path."):
						var rpath := str(cf.get_value("remap", k, ""))
						if rpath.begins_with("res://"):
							_pack_file_once(packer, rpath, packed_set)
			if cf.has_section_key("deps", "dest_files"):
				var dests: PackedStringArray = cf.get_value("deps", "dest_files", PackedStringArray())
				for dp in dests:
					if dp.begins_with("res://"):
						_pack_file_once(packer, dp, packed_set)


func _verify_pck(pck_path: String, files: PackedStringArray) -> bool:
	var abs_p := _abs(pck_path)
	if not FileAccess.file_exists(abs_p):
		return false
	var f := FileAccess.open(abs_p, FileAccess.READ)
	if f == null or f.get_length() < 32:
		if f:
			f.close()
		return false
	var magic := f.get_buffer(4)
	f.close()
	if magic.size() < 4 or magic[0] != 0x47 or magic[1] != 0x44 or magic[2] != 0x50 or magic[3] != 0x43:
		return false
	if not ProjectSettings.load_resource_pack(abs_p, true):
		return false
	for item in files:
		var res_p := item if item.begins_with("res://") else ("res://" + item.trim_prefix("/"))
		if not FileAccess.file_exists(res_p) and not ResourceLoader.exists(res_p):
			return false
		if res_p.ends_with(".gd") or res_p.ends_with(".gdshader") or res_p.ends_with(".tres"):
			var loaded := ResourceLoader.load(res_p, "", ResourceLoader.CACHE_MODE_IGNORE)
			if loaded == null:
				return false
	return true


func _generate_keys() -> void:
	var crypto := Crypto.new()
	var key := crypto.generate_rsa(2048)
	var abs_pub := _abs(PUB_KEY_PATH)
	var abs_priv := _abs(DEFAULT_PRIV_KEY_PATH)
	DirAccess.make_dir_recursive_absolute(abs_pub.get_base_dir())
	DirAccess.make_dir_recursive_absolute(abs_priv.get_base_dir())
	key.save(abs_pub, true)   # Public key only
	key.save(abs_priv, false) # Full private key (stored in user:// outside repo)
	print("KEYS_GENERATED pub=%s priv=%s" % [abs_pub, abs_priv])


func _sign_string(payload: String, priv_key_path: String) -> String:
	var crypto := Crypto.new()
	var key := CryptoKey.new()
	var env_pem := OS.get_environment("HOT_UPDATE_PRIVATE_KEY")
	var err := ERR_UNAVAILABLE
	if env_pem != "":
		err = key.load_from_string(env_pem, false)
	elif FileAccess.file_exists(_abs(priv_key_path)):
		err = key.load(_abs(priv_key_path), false)
	elif not FileAccess.file_exists(_abs(PUB_KEY_PATH)):
		_generate_keys()
		err = key.load(_abs(DEFAULT_PRIV_KEY_PATH), false)
	if err != OK:
		return ""
	var digest := payload.sha256_buffer()
	var sig := crypto.sign(HashingContext.HASH_SHA256, digest, key)
	return Marshalls.raw_to_base64(sig)
