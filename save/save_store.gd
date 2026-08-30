class_name SaveStore
extends RefCounted
## Owns one JSON checkpoint and one known-good backup.

var main_path: String
var backup_path: String
var temp_path: String


func _init(base_path: String = "user://hollow_signal_save") -> void:
	main_path = base_path + ".json"
	backup_path = base_path + ".backup.json"
	temp_path = base_path + ".tmp"


func inspect() -> Dictionary:
	return {"main": _inspect_path(main_path), "backup": _inspect_path(backup_path)}


func load_campaign(use_backup: bool = false) -> Dictionary:
	var path: String = backup_path if use_backup else main_path
	var result: Dictionary = _read(path)
	if result.ok:
		result["source"] = "backup" if use_backup else "main"
	return result


func save_campaign(campaign: CampaignState, allow_replace_invalid: bool = false) -> Dictionary:
	if campaign == null: return _error("There is no campaign to save.")
	var existing: Dictionary = _inspect_path(main_path)
	if existing.code in [&"corrupt", &"unsupported"] and not allow_replace_invalid:
		return _error("The existing save is %s and was not overwritten. Start a confirmed New Game or recover the backup." % String(existing.code), existing.code)
	var document: Dictionary = SaveCodec.encode(campaign)
	var validation: Dictionary = SaveCodec.decode(document)
	if not validation.ok: return validation
	var text: String = JSON.stringify(document, "  ")
	var written: Dictionary = _write_verified(temp_path, text)
	if not written.ok: return written
	if existing.ok:
		var backup_written: Dictionary = _write_verified(backup_path + ".tmp", FileAccess.get_file_as_string(main_path))
		if not backup_written.ok: return backup_written
		var backup_replace: Dictionary = _replace(backup_path + ".tmp", backup_path)
		if not backup_replace.ok: return backup_replace
	var replace: Dictionary = _replace(temp_path, main_path)
	if not replace.ok: return replace
	return {"ok": true, "code": &"ok", "message": "Campaign checkpoint saved."}


func delete_all() -> void:
	for path: String in [main_path, backup_path, temp_path, backup_path + ".tmp"]:
		if FileAccess.file_exists(path): DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _inspect_path(path: String) -> Dictionary:
	if not FileAccess.file_exists(path): return {"ok": false, "code": &"missing", "message": "No save found."}
	var result: Dictionary = _read(path)
	result.erase("state")
	return result


func _read(path: String) -> Dictionary:
	if not FileAccess.file_exists(path): return {"ok": false, "code": &"missing", "message": "No save found."}
	var text: String = FileAccess.get_file_as_string(path)
	var json: JSON = JSON.new()
	var parse_error: Error = json.parse(text)
	if parse_error != OK:
		return _error("Save JSON is damaged at line %d: %s" % [json.get_error_line(), json.get_error_message()], &"corrupt")
	return SaveCodec.decode(json.data)


func _write_verified(path: String, text: String) -> Dictionary:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null: return _error("Could not open the temporary save for writing.")
	file.store_string(text)
	file.flush()
	var error: Error = file.get_error()
	file.close()
	if error != OK: return _error("Writing the temporary save failed: %s" % error_string(error))
	var verification: Dictionary = _read(path)
	if not verification.ok:
		return _error("Temporary save verification failed: %s" % verification.message)
	return {"ok": true}


func _replace(source: String, destination: String) -> Dictionary:
	var source_absolute: String = ProjectSettings.globalize_path(source)
	var destination_absolute: String = ProjectSettings.globalize_path(destination)
	if FileAccess.file_exists(destination):
		var remove_error: Error = DirAccess.remove_absolute(destination_absolute)
		if remove_error != OK: return _error("Could not replace the old checkpoint: %s" % error_string(remove_error))
	var rename_error: Error = DirAccess.rename_absolute(source_absolute, destination_absolute)
	if rename_error != OK: return _error("Could not install the verified checkpoint: %s" % error_string(rename_error))
	return {"ok": true}


func _error(message: String, code: StringName = &"io_error") -> Dictionary:
	return {"ok": false, "code": code, "message": message}
