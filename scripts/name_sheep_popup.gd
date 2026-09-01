extends CanvasLayer

signal sheep_named(sheep_id: int, sheep_name: String)

@export var sheep_scene: PackedScene = preload("res://scenes/sheep/Sheep1.tscn")
@export var preview_scale: Vector2 = Vector2(0.45, 0.45)

@export var default_names: Array[String] = [
	"Ronnie", "Sir Ritchfield", "Cloud", "Zora", "Mopple", 
	"Wool-Eyes", "Sebastian", "Lily", "Daisy", "Oliver", 
	"Pickles", "The Winter Lamb", "Shaun", "Shirley", "Timmy", 
	"Mareep", "Dawn", "Lambie", "Dolly", "Dee", 
	"Dennis", "Mac", "Charlie", "Frank", "Dua Sheepa", 
	"Fluffy", "Billy", "Cardigan", "Marcie", "Opal", 
	"Betty", "Sheep", "Mochi", "Moon", "Fiona", 
	"Marshmallow", "Rowan", "Haven", "Lakely", "Ume"
]

var name_line_edit: LineEdit
var confirm_button: Button
var preview_slot: Control
var preview_sheep_instance: Node2D = null

var target_sheep_id: int = -1
var pending_sheep_queue: Array = []
var js_text_callback: JavaScriptObject = null


func _ready() -> void:
	visible = false

	name_line_edit = _find_first_child_of_type(self, "LineEdit")
	confirm_button = _find_first_child_of_type(self, "Button")
	preview_slot = _find_child_by_name(self, "SheepPreviewSlot")

	if is_instance_valid(confirm_button):
		confirm_button.pressed.connect(_on_confirm_pressed)

	if is_instance_valid(name_line_edit):
		name_line_edit.text_submitted.connect(func(_text): _on_confirm_pressed())

	if OS.has_feature("web"):
		_init_web_overlay()


func _init_web_overlay() -> void:
	js_text_callback = JavaScriptBridge.create_callback(_on_web_text_input)
	var window = JavaScriptBridge.get_interface("window")
	if window:
		window.godot_input_bridge = js_text_callback

	# Inject a responsive HTML overlay input
	var js_init = """
		(function() {
			var el = document.getElementById('godot_mobile_input');
			if (!el) {
				el = document.createElement('input');
				el.id = 'godot_mobile_input';
				el.type = 'text';
				el.autocapitalize = 'words';
				el.autocomplete = 'off';
				el.spellcheck = false;
				el.style.position = 'absolute';
				el.style.display = 'none';
				el.style.boxSizing = 'border-box';
				el.style.textAlign = 'center';
				el.style.border = '2px solid #888';
				el.style.borderRadius = '6px';
				el.style.backgroundColor = '#ffffff';
				el.style.color = '#111111';
				el.style.fontFamily = 'sans-serif';
				el.style.zIndex = '99999';
				document.body.appendChild(el);
			}

			el.oninput = function() {
				if (window.godot_input_bridge) {
					window.godot_input_bridge(el.value);
				}
			};
		})();
	"""
	JavaScriptBridge.eval(js_init)


func _on_web_text_input(args: Array) -> void:
	if args.size() > 0 and is_instance_valid(name_line_edit):
		name_line_edit.text = str(args[0])


func open_for_sheep_queue(sheep_ids: Array) -> void:
	pending_sheep_queue = sheep_ids.duplicate()
	_process_next_in_queue()


func _process_next_in_queue() -> void:
	if pending_sheep_queue.is_empty():
		visible = false
		_hide_web_input()
		return

	var next_id = int(pending_sheep_queue.pop_front())
	open_for_sheep(next_id)


func open_for_sheep(sheep_id: int, forced_name: String = "") -> void:
	target_sheep_id = sheep_id

	var suggested_name: String = forced_name
	if suggested_name == "":
		suggested_name = default_names.pick_random() if not default_names.is_empty() else "Ronnie"

	if is_instance_valid(name_line_edit):
		name_line_edit.text = suggested_name
		name_line_edit.placeholder_text = suggested_name
		name_line_edit.deselect()

	var saved_sheep_list: Array = SaveSystem.save_data.get("sheep", [])
	var sheep_color_hex: String = "ffffff"
	for s in saved_sheep_list:
		if s.get("id") == sheep_id:
			sheep_color_hex = s.get("color", "ffffff")
			break

	_spawn_preview_sheep(sheep_color_hex)
	visible = true

	if OS.has_feature("web"):
		_position_and_show_web_input(suggested_name)
	elif OS.has_feature("mobile"):
		await get_tree().process_frame
		if is_instance_valid(name_line_edit):
			name_line_edit.grab_focus()
			if DisplayServer.has_feature(DisplayServer.FEATURE_VIRTUAL_KEYBOARD):
				DisplayServer.virtual_keyboard_show(name_line_edit.text)


func _position_and_show_web_input(initial_text: String) -> void:
	if not is_instance_valid(name_line_edit):
		return

	await get_tree().process_frame
	
	# Compute actual browser pixel coordinates using canvas scaling
	var js_calc = """
		(function() {
			var canvas = document.getElementById('canvas');
			var input = document.getElementById('godot_mobile_input');
			if (!canvas || !input) return;

			var rect = canvas.getBoundingClientRect();
			var scaleX = rect.width / %f;
			var scaleY = rect.height / %f;

			var left = rect.left + (%f * scaleX);
			var top = rect.top + (%f * scaleY);
			var width = %f * scaleX;
			var height = %f * scaleY;

			input.value = '%s';
			input.style.left = left + 'px';
			input.style.top = top + 'px';
			input.style.width = width + 'px';
			input.style.height = height + 'px';
			input.style.fontSize = Math.max(16, Math.floor(height * 0.45)) + 'px';
			input.style.display = 'block';
		})();
	""" % [
		get_viewport().size.x,
		get_viewport().size.y,
		name_line_edit.global_position.x,
		name_line_edit.global_position.y,
		name_line_edit.size.x,
		name_line_edit.size.y,
		initial_text.c_escape()
	]
	JavaScriptBridge.eval(js_calc)


func _hide_web_input() -> void:
	if OS.has_feature("web"):
		JavaScriptBridge.eval("""
			var el = document.getElementById('godot_mobile_input');
			if (el) {
				el.style.display = 'none';
				el.blur();
			}
		""")


func _spawn_preview_sheep(color_hex: String) -> void:
	if is_instance_valid(preview_sheep_instance):
		preview_sheep_instance.queue_free()

	if not sheep_scene:
		return

	preview_sheep_instance = sheep_scene.instantiate() as Node2D
	if preview_sheep_instance.has_method("set_as_preview"):
		preview_sheep_instance.set_as_preview()

	preview_sheep_instance.scale = preview_scale

	if is_instance_valid(preview_slot):
		preview_slot.add_child(preview_sheep_instance)
		await get_tree().process_frame
		if is_instance_valid(preview_sheep_instance) and is_instance_valid(preview_slot):
			preview_sheep_instance.position = Vector2(preview_slot.size.x * 0.5, preview_slot.size.y * 0.5 + 20.0)
	else:
		add_child(preview_sheep_instance)
		preview_sheep_instance.position = Vector2(get_viewport().size) * 0.5 - Vector2(0, 80)

	if is_instance_valid(preview_sheep_instance) and preview_sheep_instance.has_method("init_sheep"):
		preview_sheep_instance.init_sheep(target_sheep_id, "", color_hex)

	if is_instance_valid(preview_sheep_instance):
		var anim_player: AnimationPlayer = preview_sheep_instance.get_node_or_null("AnimationPlayer")
		if is_instance_valid(anim_player) and anim_player.has_animation("idle"):
			anim_player.play("idle")


func _on_confirm_pressed() -> void:
	var chosen_name: String = ""

	if OS.has_feature("web"):
		var web_val = JavaScriptBridge.eval("var el = document.getElementById('godot_mobile_input'); el ? el.value : '';")
		if web_val != null and typeof(web_val) == TYPE_STRING:
			chosen_name = str(web_val).strip_edges()
		_hide_web_input()
	elif is_instance_valid(name_line_edit):
		chosen_name = name_line_edit.text.strip_edges()
		name_line_edit.release_focus()

	if DisplayServer.has_feature(DisplayServer.FEATURE_VIRTUAL_KEYBOARD):
		DisplayServer.virtual_keyboard_hide()

	if chosen_name == "":
		chosen_name = name_line_edit.placeholder_text if (is_instance_valid(name_line_edit) and name_line_edit.placeholder_text != "") else ("Sheep #" + str(target_sheep_id + 1))

	SaveSystem.update_sheep_name(target_sheep_id, chosen_name)
	sheep_named.emit(target_sheep_id, chosen_name)

	var all_sheep = get_tree().get_nodes_in_group("sheep")
	for s in all_sheep:
		if is_instance_valid(s) and "sheep_id" in s and s.sheep_id == target_sheep_id:
			s.sheep_name = chosen_name
			if is_instance_valid(s.name_tag):
				s.name_tag.text = chosen_name

	if is_instance_valid(preview_sheep_instance):
		preview_sheep_instance.queue_free()

	if not pending_sheep_queue.is_empty():
		_process_next_in_queue()
	else:
		visible = false


func _find_first_child_of_type(node: Node, type_name: String) -> Node:
	for child in node.get_children():
		if child.is_class(type_name):
			return child
		var found = _find_first_child_of_type(child, type_name)
		if found != null:
			return found
	return null


func _find_child_by_name(node: Node, target_name: String) -> Node:
	for child in node.get_children():
		if child.name == target_name:
			return child
		var found = _find_child_by_name(child, target_name)
		if found != null:
			return found
	return null