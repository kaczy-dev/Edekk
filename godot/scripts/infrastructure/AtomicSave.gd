class_name AtomicSave
extends RefCounted
## Shared write-json-atomically helper for the autosave stores
## (ProgressStore.gd, SettingsStore.gd). Both used to `FileAccess.open(path,
## WRITE)` and write straight into the real file — a crash/power-loss
## mid-write (autosave fires on every single state change, so the write
## window is hit often) truncates the file to 0 bytes or a half-written JSON
## object, and the loader silently falls back to defaults, discarding
## whatever was saved. Writing to `path + ".tmp"` then renaming over `path`
## makes the swap a single filesystem operation the OS can't leave half-done.

static func write_json(path: String, data: Dictionary) -> void:
	var tmp_path := path + ".tmp"
	var file := FileAccess.open(tmp_path, FileAccess.WRITE)
	if file == null:
		push_warning("AtomicSave: could not open %s for writing" % tmp_path)
		return
	file.store_string(JSON.stringify(data))
	file.close()

	var dir := DirAccess.open("user://")
	if dir == null:
		push_warning("AtomicSave: could not open user:// to finalize %s" % path)
		return
	var err := dir.rename(tmp_path, path)
	if err != OK:
		push_warning("AtomicSave: rename %s -> %s failed (%d)" % [tmp_path, path, err])
