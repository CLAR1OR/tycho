extends RefCounted
class_name Telemetry
## Minimal JSONL telemetry writer. NOT an autoload (a static helper, like
## SettingsPanel.apply_window_mode) — game.gd calls Telemetry.append(...) directly
## at run-end points; TelemetryCore.build_record shapes the record, this class only
## owns the file.
##
## Writes to user://telemetry/runs.jsonl — DELIBERATELY OUTSIDE user://saves/. The
## design 2026-07-07 statistics invariant only constrains writes to the SLOT file
## mid-run (a counter earned after the last checkpoint must be re-earnable on
## resume); this is a diagnostics-only append-log nobody reads back into game
## state, so appending here mid-run — including on a run a Forfeit later rolls
## back — never violates it.

const DEFAULT_PATH := "user://telemetry/runs.jsonl"

## Redirect target for tests (the smoke sets this to a temp path so it never
## touches the human's real user:// telemetry). Empty string = the real path.
static var path_override: String = ""


## Append one record as a single JSON line. Creates the telemetry directory if
## missing. Never raises — a telemetry failure (e.g. a locked file) must not take
## a run down with it; it push_warnings and returns.
static func append(record: Dictionary) -> void:
	var path := _target_path()
	var dir := path.get_base_dir()
	if dir != "" and not DirAccess.dir_exists_absolute(dir):
		var err := DirAccess.make_dir_recursive_absolute(dir)
		if err != OK:
			push_warning("Telemetry: could not create directory %s (error %d)" % [dir, err])
			return
	var mode := FileAccess.READ_WRITE if FileAccess.file_exists(path) else FileAccess.WRITE
	var f := FileAccess.open(path, mode)
	if f == null:
		push_warning("Telemetry: could not open %s (error %d)" % [path, FileAccess.get_open_error()])
		return
	f.seek_end()
	f.store_line(TelemetryCore.to_line(record))
	f.close()


static func _target_path() -> String:
	return path_override if path_override != "" else DEFAULT_PATH
