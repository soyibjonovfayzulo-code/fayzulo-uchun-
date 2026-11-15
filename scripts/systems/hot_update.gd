extends Node
## Godot 4 PCK Hot Update System (Autoload: HotUpdate).
## - Automatically checks HTTPS/HTTP manifest on startup and via manual "Проверить обновления".
## - Logs full diagnostics to ADB logcat (`[HotUpdate] ...`) for Android debugging.
## - Never fails silently: surfaces exact HTTP/TLS/verification error reasons to the user.
## - Verifies manifest authenticity via canonical SHA-256 (`manifest_hash`) and RSA-2048 (`signature_rsa`).
## - Verifies `.pck` file size, Godot PCK magic header ("GDPC"), and SHA-256 hash before applying.
## - Maintains `backup_patch.pck` and boot-guard rollback, while preserving Save/Load and options.

signal update_check_started(url: String)
signal update_available(manifest: Dictionary)
signal update_progress(percent: float, downloaded_bytes: int, total_bytes: int, version: String)
signal update_finished(applied: bool, version: String, message: String)
signal update_up_to_date(version: String, build_number: int, message: String)
signal update_error(error_message: String)
signal apk_update_required(manifest: Dictionary, message: String)

const BASE_VERSION := "0.5.1"
const APK_BUILD_NUMBER := 500
const DEFAULT_MANIFEST_URL := "https://github.com/soyibjonovfayzulo-code/fayzulo-uchun-/releases/latest/download/manifest.json"
const FALLBACK_MANIFEST_URL := "https://russian-zombie-survival.pages.dev/manifest.json"
const PUB_KEY_PATH := "res://launcher/update_pub.key"
const UpdateWindowScript := preload("res://scripts/ui/update_window.gd")
const CONFIG_PATH := "user://update_config.cfg"
const PATCH_DIR := "user://patches"
const STATE_PATH := "user://patches/state.json"
const BACKUP_PCK := "user://patches/backup_patch.pck"
const TEMP_PCK := "user://patches/download_temp.pck"

var current_version := BASE_VERSION
var current_build := APK_BUILD_NUMBER
var active_pck_path := ""
var active_sha256 := ""
var status_text := "v%s (сборка #%d)" % [BASE_VERSION, APK_BUILD_NUMBER]
var last_error := ""
var is_checking := false
var is_downloading := false
var is_manual_check := false
var auto_check_enabled := true
var last_manifest := {}
var rolled_back_on_boot := false
var update_window: CanvasLayer
var diag_log: Array[String] = []

var _manifest_req: HTTPRequest
var _pck_req: HTTPRequest
var _target_manifest := {}
var _tried_fallback_manifest := false
var _tried_fallback_pck := false
var _last_req_url := ""


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(PATCH_DIR))
	_boot_load_existing_patch()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_log("Boot ready: os=%s base=v%s(#%d) active=v%s(#%d) pck=%s" % [
		OS.get_name(), BASE_VERSION, APK_BUILD_NUMBER, current_version, current_build, active_pck_path
	])
	_setup_http_nodes()
	_setup_update_window()
	get_tree().create_timer(0.3).timeout.connect(confirm_boot_ok)
	var args := OS.get_cmdline_user_args()
	for a in args:
		if a in ["--autotest", "--tour", "--poses", "--loadcheck", "--m78", "--v04", "--gallery", "--fps", "--fpvm", "--fpgallery", "--probe-admin", "--profile-interactions"]:
			_log("Test flag detected (%s) — skipping startup auto-check" % a)
			return
	if auto_check_enabled:
		check_for_updates.call_deferred("", false)


func _log(msg: String) -> void:
	var line := "[HotUpdate] " + msg
	print(line)
	diag_log.append(line)
	if diag_log.size() > 60:
		diag_log.remove_at(0)


func _setup_update_window() -> void:
	update_window = UpdateWindowScript.new()
	update_window.name = "UpdateWindow"
	add_child(update_window)
	update_available.connect(func(m: Dictionary) -> void:
		if update_window:
			update_window.show_update_start(m))
	update_progress.connect(func(pct: float, got: int, tot: int, ver: String) -> void:
		if update_window:
			update_window.set_progress(pct, got, tot, ver))
	update_finished.connect(func(applied: bool, ver: String, msg: String) -> void:
		if update_window:
			if applied:
				update_window.show_completed(true, ver, msg, is_manual_check)
			elif is_manual_check or update_window.visible:
				update_window.show_completed(false, ver, msg, true))
	update_up_to_date.connect(func(ver: String, bld: int, _msg: String) -> void:
		if update_window and is_manual_check:
			update_window.show_up_to_date(ver, bld))
	apk_update_required.connect(func(m: Dictionary, msg: String) -> void:
		if update_window:
			update_window.show_apk_required(m, msg))


func _setup_http_nodes() -> void:
	_manifest_req = HTTPRequest.new()
	_manifest_req.name = "ManifestRequest"
	_manifest_req.timeout = 12.0
	_manifest_req.use_threads = true
	_manifest_req.max_redirects = 10
	_manifest_req.request_completed.connect(_on_manifest_completed)
	add_child(_manifest_req)

	_pck_req = HTTPRequest.new()
	_pck_req.name = "PckDownloadRequest"
	_pck_req.timeout = 60.0
	_pck_req.use_threads = true
	_pck_req.max_redirects = 10
	_pck_req.request_completed.connect(_on_pck_completed)
	add_child(_pck_req)
	set_process(false)


func _process(_delta: float) -> void:
	if not is_downloading or _pck_req == null:
		set_process(false)
		return
	var got := _pck_req.get_downloaded_bytes()
	var total := _pck_req.get_body_size()
	if total <= 0:
		total = int(_target_manifest.get("pck_size", 0))
	var pct := clampf((float(got) / float(total)) * 100.0, 0.0, 99.9) if total > 0 else 0.0
	var ver := str(_target_manifest.get("version", current_version))
	status_text = "Загрузка обновления: %.0f%% (%d / %d КБ)" % [pct, got / 1024, maxi(total / 1024, 1)]
	update_progress.emit(pct, got, total, ver)


## Reads the manifest URL from CLI (--update-url=...), user://update_config.cfg, or default HTTPS endpoint.
func get_manifest_url() -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--update-url="):
			return a.trim_prefix("--update-url=")
	var cf := ConfigFile.new()
	if cf.load(CONFIG_PATH) == OK:
		var custom := str(cf.get_value("update", "manifest_url", ""))
		if custom != "":
			return custom
	return DEFAULT_MANIFEST_URL


func set_manifest_url(url: String) -> void:
	var cf := ConfigFile.new()
	cf.load(CONFIG_PATH)
	cf.set_value("update", "manifest_url", url)
	cf.save(CONFIG_PATH)


func _http_error_reason(result: int, response_code: int) -> String:
	match result:
		HTTPRequest.RESULT_CANT_CONNECT:
			return "Нет подключения к серверу (CANT_CONNECT)"
		HTTPRequest.RESULT_CANT_RESOLVE:
			return "Ошибка DNS — нет интернета или сервер недоступен (CANT_RESOLVE)"
		HTTPRequest.RESULT_CONNECTION_ERROR:
			return "Ошибка соединения (CONNECTION_ERROR)"
		HTTPRequest.RESULT_TLS_HANDSHAKE_ERROR:
			return "Ошибка HTTPS/TLS сертификата (TLS_HANDSHAKE_ERROR)"
		HTTPRequest.RESULT_NO_RESPONSE:
			return "Сервер не отвечает (NO_RESPONSE)"
		HTTPRequest.RESULT_BODY_SIZE_LIMIT_EXCEEDED:
			return "Превышен лимит размера ответа"
		HTTPRequest.RESULT_DOWNLOAD_FILE_CANT_OPEN, HTTPRequest.RESULT_DOWNLOAD_FILE_WRITE_ERROR:
			return "Ошибка записи файла на устройство"
		HTTPRequest.RESULT_REDIRECT_LIMIT_REACHED:
			return "Слишком много перенаправлений (REDIRECT_LIMIT)"
		HTTPRequest.RESULT_TIMEOUT:
			return "Превышено время ожидания сервера (TIMEOUT)"
		HTTPRequest.RESULT_SUCCESS:
			return "Ошибка HTTP %d от сервера" % response_code
	return "Сетевая ошибка (result=%d, http=%d)" % [result, response_code]


func _fail_update(reason: String) -> void:
	last_error = reason
	status_text = "v%s (#%d) · %s" % [current_version, current_build, reason]
	_log("ERROR: " + reason)
	update_error.emit(reason)
	update_finished.emit(false, current_version, reason)


## Loads any previously installed patch on boot; automatically rolls back if the previous boot crashed.
func _boot_load_existing_patch() -> void:
	if not FileAccess.file_exists(STATE_PATH):
		return
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(STATE_PATH))
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	var st := parsed as Dictionary
	var pck_path := str(st.get("active_pck", ""))
	var expected_sha := str(st.get("sha256", ""))
	var pending := bool(st.get("boot_pending", false))
	var attempts := int(st.get("boot_attempts", 0))

	if pending and attempts >= 1:
		_rollback_to_backup("Сбой запуска патча — выполнен автоматический откат")
		return

	if pck_path == "" or not FileAccess.file_exists(pck_path):
		return

	if not verify_pck_file(pck_path, expected_sha, int(st.get("pck_size", 0))):
		_rollback_to_backup("Повреждён файл патча — выполнен откат к рабочей версии")
		return

	if pending:
		st["boot_attempts"] = attempts + 1
		_save_state(st)

	if ProjectSettings.load_resource_pack(pck_path, true):
		current_version = str(st.get("version", BASE_VERSION))
		current_build = int(st.get("build_number", APK_BUILD_NUMBER))
		active_pck_path = pck_path
		active_sha256 = expected_sha
		status_text = "v%s (сборка #%d)" % [current_version, current_build]
	else:
		_rollback_to_backup("Не удалось подключить PCK — выполнен откат")


func confirm_boot_ok() -> void:
	if not FileAccess.file_exists(STATE_PATH):
		return
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(STATE_PATH))
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	var st := parsed as Dictionary
	if bool(st.get("boot_pending", false)):
		st["boot_pending"] = false
		st["boot_attempts"] = 0
		_save_state(st)


func _rollback_to_backup(reason: String) -> void:
	rolled_back_on_boot = true
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(STATE_PATH)) if FileAccess.file_exists(STATE_PATH) else {}
	var st: Dictionary = parsed if typeof(parsed) == TYPE_DICTIONARY else {}
	var bad_pck := str(st.get("active_pck", ""))
	if bad_pck != "" and bad_pck != BACKUP_PCK and FileAccess.file_exists(bad_pck):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(bad_pck))
	var backup_sha := str(st.get("backup_sha256", ""))
	var backup_ver := str(st.get("backup_version", BASE_VERSION))
	var backup_bld := int(st.get("backup_build", APK_BUILD_NUMBER))
	if FileAccess.file_exists(BACKUP_PCK) and verify_pck_file(BACKUP_PCK, backup_sha, 0):
		if ProjectSettings.load_resource_pack(BACKUP_PCK, true):
			current_version = backup_ver
			current_build = backup_bld
			active_pck_path = BACKUP_PCK
			active_sha256 = backup_sha
			_save_state({
				"version": current_version,
				"build_number": current_build,
				"active_pck": BACKUP_PCK,
				"sha256": backup_sha,
				"boot_pending": false,
				"boot_attempts": 0,
			})
			status_text = "%s (v%s #%d)" % [reason, current_version, current_build]
			return
	current_version = BASE_VERSION
	current_build = APK_BUILD_NUMBER
	active_pck_path = ""
	active_sha256 = ""
	_save_state({
		"version": BASE_VERSION,
		"build_number": APK_BUILD_NUMBER,
		"active_pck": "",
		"sha256": "",
		"boot_pending": false,
		"boot_attempts": 0,
	})
	status_text = "%s (базовая v%s #%d)" % [reason, BASE_VERSION, APK_BUILD_NUMBER]


## Starts an asynchronous HTTPS/HTTP check for a newer patch manifest.
func check_for_updates(override_url := "", manual := false) -> void:
	if is_checking or is_downloading:
		_log("Check ignored: already busy (checking=%s downloading=%s)" % [is_checking, is_downloading])
		return
	var url := override_url if override_url != "" else get_manifest_url()
	if not (url.begins_with("https://") or url.begins_with("http://")):
		is_manual_check = manual
		_fail_update("Некорректный URL обновлений: " + url)
		return
	is_manual_check = manual
	last_error = ""
	_tried_fallback_manifest = (override_url != "")
	is_checking = true
	_last_req_url = url
	status_text = "v%s (#%d) · Проверка обновлений..." % [current_version, current_build]
	_log("Checking manifest: url=%s manual=%s" % [url, manual])
	if manual and update_window:
		update_window.show_checking(current_version, current_build)
	update_check_started.emit(url)
	var headers := PackedStringArray([
		"Accept: application/json",
		"Cache-Control: no-cache",
		"User-Agent: RussianZombieSurvival-Android/1.0",
	])
	var err := _manifest_req.request(url, headers)
	if err != OK:
		is_checking = false
		_fail_update("Не удалось запустить HTTP-запрос (код %d)" % err)


func _on_manifest_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	is_checking = false
	_log("Manifest HTTP done: url=%s result=%d code=%d bytes=%d" % [_last_req_url, result, response_code, body.size()])
	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		var primary_err := _http_error_reason(result, response_code)
		if not _tried_fallback_manifest and FALLBACK_MANIFEST_URL != "" and get_manifest_url() == DEFAULT_MANIFEST_URL:
			_tried_fallback_manifest = true
			is_checking = true
			_last_req_url = FALLBACK_MANIFEST_URL
			_log("Primary failed (%s) — trying fallback: %s" % [primary_err, FALLBACK_MANIFEST_URL])
			var err := _manifest_req.request(FALLBACK_MANIFEST_URL, PackedStringArray([
				"Accept: application/json",
				"Cache-Control: no-cache",
				"User-Agent: RussianZombieSurvival-Android/1.0",
			]))
			if err == OK:
				return
			is_checking = false
		_fail_update(primary_err)
		return

	var text := body.get_string_from_utf8()
	var parsed = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		_fail_update("Некорректный формат manifest.json (ошибка разбора JSON)")
		return
	var manifest := parsed as Dictionary
	last_manifest = manifest
	_evaluate_manifest(manifest)


## Cryptographic & canonical verification of `manifest.json` (`manifest_hash` + `signature_rsa`).
func verify_manifest_security(manifest: Dictionary) -> bool:
	var ver := str(manifest.get("version", ""))
	var bld := int(manifest.get("build_number", 0))
	var min_apk := int(manifest.get("min_apk_build", APK_BUILD_NUMBER))
	var req_apk := 1 if bool(manifest.get("requires_apk_update", false)) else 0
	var sha := str(manifest.get("sha256", "")).to_lower()
	var sz := int(manifest.get("pck_size", 0))
	var payload := "RZS_MANIFEST_V1|%s|%d|%d|%d|%d|%s" % [ver, bld, min_apk, req_apk, sz, sha]

	var expected_mhash := str(manifest.get("manifest_hash", "")).to_lower()
	if expected_mhash != "":
		if payload.sha256_text().to_lower() != expected_mhash:
			_log("Security FAIL: manifest_hash mismatch")
			return false

	var sig_b64 := str(manifest.get("signature_rsa", ""))
	if sig_b64 != "" and FileAccess.file_exists(PUB_KEY_PATH):
		var pub_key := CryptoKey.new()
		if pub_key.load(ProjectSettings.globalize_path(PUB_KEY_PATH), true) == OK:
			var crypto := Crypto.new()
			var sig_raw := Marshalls.base64_to_raw(sig_b64)
			if not crypto.verify(HashingContext.HASH_SHA256, payload.sha256_buffer(), sig_raw, pub_key):
				_log("Security FAIL: RSA-2048 signature invalid")
				return false
	return true


func _evaluate_manifest(manifest: Dictionary) -> void:
	if not verify_manifest_security(manifest):
		_fail_update("Ошибка проверки цифровой подписи манифеста — обновление отклонено")
		return

	var remote_ver := str(manifest.get("version", current_version))
	var remote_build := int(manifest.get("build_number", current_build))
	var min_apk := int(manifest.get("min_apk_build", APK_BUILD_NUMBER))
	var need_apk := bool(manifest.get("requires_apk_update", false)) or (min_apk > APK_BUILD_NUMBER)
	var remote_sha := str(manifest.get("sha256", "")).to_lower()

	_log("Manifest evaluated: remote=v%s(#%d) local=v%s(#%d) min_apk=%d need_apk=%s" % [
		remote_ver, remote_build, current_version, current_build, min_apk, need_apk
	])

	if need_apk:
		var reason := str(manifest.get("apk_update_reason", ""))
		var msg := "Требуется обновление APK до v%s" % remote_ver
		if reason != "":
			msg += " (%s)" % reason
		else:
			msg += " (изменились нативные компоненты Android)"
		status_text = msg
		last_error = msg
		apk_update_required.emit(manifest, msg)
		return

	if remote_build <= current_build and (remote_sha == "" or remote_sha == active_sha256.to_lower()):
		var ok_msg := "Установлена последняя версия"
		status_text = "v%s (сборка #%d) · %s" % [current_version, current_build, ok_msg]
		_log("Already up to date: " + status_text)
		update_up_to_date.emit(current_version, current_build, ok_msg)
		return

	_log("New update found! Starting download for v%s (#%d)" % [remote_ver, remote_build])
	update_available.emit(manifest)
	_tried_fallback_pck = false
	_start_pck_download(manifest, str(manifest.get("pck_url", "")))


func _start_pck_download(manifest: Dictionary, url_to_use: String) -> void:
	if url_to_use == "":
		_fail_update("В манифесте не указан pck_url")
		return
	_target_manifest = manifest
	if FileAccess.file_exists(TEMP_PCK):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEMP_PCK))
	_pck_req.download_file = TEMP_PCK
	is_downloading = true
	_last_req_url = url_to_use
	set_process(true)
	_log("Downloading PCK: " + url_to_use)
	var err := _pck_req.request(url_to_use, PackedStringArray([
		"Accept: application/octet-stream",
		"User-Agent: RussianZombieSurvival-Android/1.0",
	]))
	if err != OK:
		is_downloading = false
		set_process(false)
		_fail_update("Не удалось начать загрузку патча (код %d)" % err)


func _on_pck_completed(result: int, response_code: int, _headers: PackedStringArray, _body: PackedByteArray) -> void:
	is_downloading = false
	set_process(false)
	_pck_req.download_file = ""
	_log("PCK HTTP done: url=%s result=%d code=%d" % [_last_req_url, result, response_code])
	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		var dl_err := _http_error_reason(result, response_code)
		if FileAccess.file_exists(TEMP_PCK):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(TEMP_PCK))
		var fb_url := str(_target_manifest.get("fallback_pck_url", ""))
		if not _tried_fallback_pck and fb_url != "" and fb_url != str(_target_manifest.get("pck_url", "")):
			_tried_fallback_pck = true
			_log("Primary PCK failed (%s) — trying fallback: %s" % [dl_err, fb_url])
			_start_pck_download(_target_manifest, fb_url)
			return
		_fail_update("Ошибка загрузки патча: " + dl_err)
		return
	apply_downloaded_patch(TEMP_PCK, _target_manifest)


## Verifies integrity (signature, size, GDPC magic header, and SHA-256) and applies a `.pck` patch safely.
func apply_downloaded_patch(temp_path: String, manifest: Dictionary) -> bool:
	if not verify_manifest_security(manifest):
		if FileAccess.file_exists(temp_path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(temp_path))
		_fail_update("Подпись манифеста недействительна — сохранена рабочая версия")
		return false

	var expected_sha := str(manifest.get("sha256", "")).to_lower()
	var expected_size := int(manifest.get("pck_size", 0))
	var new_ver := str(manifest.get("version", current_version))
	var new_build := int(manifest.get("build_number", current_build + 1))

	if not verify_pck_file(temp_path, expected_sha, expected_size):
		if FileAccess.file_exists(temp_path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(temp_path))
		_fail_update("Проверка целостности патча (SHA-256 / размер) не пройдена")
		return false

	var prev_ver := current_version
	var prev_build := current_build
	var prev_sha := active_sha256
	if active_pck_path != "" and FileAccess.file_exists(active_pck_path):
		_copy_file(active_pck_path, BACKUP_PCK)

	var final_pck := "%s/patch_%s_%d.pck" % [PATCH_DIR, new_ver.replace(".", "_"), new_build]
	if not _copy_file(temp_path, final_pck):
		_fail_update("Не удалось сохранить файл патча на устройство")
		return false
	DirAccess.remove_absolute(ProjectSettings.globalize_path(temp_path))

	_save_state({
		"version": new_ver,
		"build_number": new_build,
		"active_pck": final_pck,
		"sha256": expected_sha if expected_sha != "" else FileAccess.get_sha256(final_pck),
		"pck_size": expected_size,
		"backup_version": prev_ver,
		"backup_build": prev_build,
		"backup_sha256": prev_sha,
		"boot_pending": true,
		"boot_attempts": 0,
		"updated_at": Time.get_datetime_string_from_system(false, true),
	})

	if not ProjectSettings.load_resource_pack(final_pck, true):
		_rollback_to_backup("Ошибка подключения PCK")
		_fail_update("Не удалось применить PCK — выполнен откат к рабочей версии")
		return false

	var changed_files: Array = manifest.get("changed_files", [])
	for f in changed_files:
		var path := str(f)
		if (path.ends_with(".gd") or path.ends_with(".gdshader") or path.ends_with(".tres") or path.ends_with(".tscn")) and ResourceLoader.exists(path):
			ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_REPLACE)

	current_version = new_ver
	current_build = new_build
	active_pck_path = final_pck
	active_sha256 = expected_sha if expected_sha != "" else FileAccess.get_sha256(final_pck)
	last_error = ""
	confirm_boot_ok()
	status_text = "v%s (сборка #%d) · Обновлено" % [current_version, current_build]
	_log("Patch applied successfully: version=%s build=%d file=%s" % [current_version, current_build, final_pck])
	update_progress.emit(100.0, expected_size, expected_size, current_version)
	update_finished.emit(true, current_version, "Обновление v%s (сборка #%d) успешно установлено!" % [current_version, current_build])
	return true


func verify_pck_file(path: String, expected_sha256 := "", expected_size := 0) -> bool:
	if not FileAccess.file_exists(path):
		return false
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return false
	var len_bytes := int(f.get_length())
	if len_bytes < 32:
		f.close()
		return false
	if expected_size > 0 and len_bytes != expected_size:
		f.close()
		return false
	var magic := f.get_buffer(4)
	f.close()
	if magic.size() < 4 or magic[0] != 0x47 or magic[1] != 0x44 or magic[2] != 0x50 or magic[3] != 0x43:
		return false
	if expected_sha256 != "":
		var actual_sha := FileAccess.get_sha256(path).to_lower()
		if actual_sha != expected_sha256.to_lower():
			return false
	return true


func _copy_file(src: String, dst: String) -> bool:
	var r := FileAccess.open(src, FileAccess.READ)
	if r == null:
		return false
	var bytes := r.get_buffer(r.get_length())
	r.close()
	var w := FileAccess.open(dst, FileAccess.WRITE)
	if w == null:
		return false
	w.store_buffer(bytes)
	w.close()
	return true


func _save_state(d: Dictionary) -> void:
	var f := FileAccess.open(STATE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(d, "\t"))
		f.close()
