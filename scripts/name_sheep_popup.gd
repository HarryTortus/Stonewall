extends CanvasLayer

signal sheep_named(sheep_id: int, sheep_name: String)

@export var sheep_scene: PackedScene = preload("res://scenes/sheep/Sheep1.tscn")
@export var preview_scale: Vector2 = Vector2(0.45, 0.45)

## Random names suggested to the player
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

	# Initialize transparent HTML DOM input overlay for mobile browsers
	if OS.has_feature("web"):
		_init_web_overlay()


func _init_web_overlay() -> void:
	# Create a JS callback that routes real DOM typing events directly into Godot's LineEdit
	js_text_callback = JavaScriptBridge.create_callback(_on_web_text_input)
	
	# Inject a transparent off-screen/overlay input box into the page DOM
	var js_init = """
		(function() {
			if (document.getElementById('godot_mobile_input')) return;
			var input = document.createElement('input');
			input.id = 'godot_mobile_input';
			input.type = 'text';
			input.style.position = 'fixed';
			input.style.opacity = '0';
			input.style.pointerEvents = 'none';
			input.style.left = '0px';
			input.style.top = '0px';
			input.style.width = '100px';
			input.style.height = '40px';
			input.style.fontSize = '16px'; // Prevents auto-zoom on iOS Safari
			input.style.zIndex = '1000';
			document.body.appendChild(input);
		})();
	"""
	JavaScriptBridge.eval(js_init)


func _on_web_text_input(args: Array) -> void:
	if args.size() > 0 and is_instance_valid(name_line_edit):
		name_line_edit.text = str(args[0])


## Call this to handle single sheep or a batch queue of sheep
func open_for_sheep_queue(sheep_ids: Array) -> void:
	pending_sheep_queue = sheep_ids.duplicate()
	_process_next_in_queue()


func _process_next_in_queue() -> void:
	if pending_sheep_queue.is_empty():
		visible = false
		return

	var next_id = int(pending_sheep_queue.pop_front())
	open_for_sheep(next_id)


func open_for_sheep(sheep_id: int, forced_name: String = "") -> void:
	target_sheep_id = sheep_id

	# 1. Pick random suggested name
	var suggested_name: String = forced_name
	if suggested_name == "":
		suggested_name = default_names.pick_random() if not default_names.is_empty() else "Ronnie"

	if is_instance_valid(name_line_edit):
		name_line_edit.text = suggested_name
		name_line_edit.placeholder_text = suggested_name
		name_line_edit.deselect()
		name_line_edit.caret_column = suggested_name.length()

	# 2. Retrieve wool color
	var saved_sheep_list: Array = SaveSystem.save_data.get("sheep", [])
	var sheep_color_hex: String = "ffffff"
	for s in saved_sheep_list:
		if s.get("id") == sheep_id:
			sheep_color_hex = s.get("color", "ffffff")
			break

	# 3. Spawn visual preview
	_spawn_preview_sheep(sheep_color_hex)
	visible = true

	# 4. Keyboard Hook
	if OS.has_feature("web"):
		_setup_web_line_edit_handler()
	elif OS.has_feature("mobile"):
		await get_tree().process_frame
		if is_instance_valid(name_line_edit):
			name_line_edit.grab_focus()
			if DisplayServer.has_feature(DisplayServer.FEATURE_VIRTUAL_KEYBOARD):
				DisplayServer.virtual_keyboard_show(name_line_edit.text)


func _setup_web_line_edit_handler() -> void:
	if not is_instance_valid(name_line_edit):
		return
		
	# Disable canvas text eating while retaining mouse events
	name_line_edit.editable = false
	name_line_edit.focus_mode = Control.FOCUS_NONE

	if name_line_edit.gui_input.is_connected(_on_web_line_edit_gui_input):
		name_line_edit.gui_input.disconnect(_on_web_line_edit_gui_input)
		
	name_line_edit.gui_input.connect(_on_web_line_edit_gui_input)


func _on_web_line_edit_gui_input(event: InputEvent) -> void:
	if not OS.has_feature("web"):
		return

	var is_tap = (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT) or (event is InputEventScreenTouch and event.pressed)
	if is_tap:
		name_line_edit.accept_event()
		var current_val = name_line_edit.text if name_line_edit.text != "" else name_line_edit.placeholder_text
		
		# Bind the input element to forward keystrokes directly to Godot
		var window = JavaScriptBridge.get_interface("window")
		window.godot_input_bridge = js_text_callback

		var js_focus = """
			(function() {
				var el = document.getElementById('godot_mobile_input');
				if (el) {
					el.value = '%s';
					el.oninput = function() {
						if (window.godot_input_bridge) {
							window.godot_input_bridge(el.value);
						}
					};
					el.focus();
					el.setSelectionRange(el.value.length, el.value.length);
				}
			})();
		""" % current_val.c_escape()
		JavaScriptBridge.eval(js_focus)


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
	if is_instance_valid(name_line_edit):
		chosen_name = name_line_edit.text.strip_edges()
		name_line_edit.release_focus()

	# Defocus & dismiss mobile keyboard cleanly
	if OS.has_feature("web"):
		JavaScriptBridge.eval("var el = document.getElementById('godot_mobile_input'); if (el) { el.blur(); }")
	elif DisplayServer.has_feature(DisplayServer.FEATURE_VIRTUAL_KEYBOARD):
		DisplayServer.virtual_keyboard_hide()

	if chosen_name == "":
		chosen_name = name_line_edit.placeholder_text if name_line_edit.placeholder_text != "" else ("Sheep #" + str(target_sheep_id + 1))

	# 1. Update JSON save data
	SaveSystem.update_sheep_name(target_sheep_id, chosen_name)
	sheep_named.emit(target_sheep_id, chosen_name)

	# 2. Update live sheep in pasture
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