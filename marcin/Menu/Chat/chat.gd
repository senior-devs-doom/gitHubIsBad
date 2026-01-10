extends Control

@export var user_bubble_scene: PackedScene
@export var gpt_bubble_scene: PackedScene

@export var messages_vbox_path: NodePath
@export var scroll_path: NodePath
@export var input_path: NodePath
@export var send_btn_path: NodePath
@export var switch_butt_path: NodePath

@export var commands_popup_path: NodePath
@export var commands_scroll_path: NodePath
@export var commands_list_path: NodePath

#tutaj dajesz ścieżke do skryptu z logiką dla komend
@export var command_runner_path: NodePath

@export var available_commands: PackedStringArray = [
	"/help",
	"/clear",
	"/ping",
	"/about",
	"/hello",
	"/history"
]

const MAX_VISIBLE_COMMANDS := 5
const COMMAND_ROW_HEIGHT := 28.0
const POPUP_MARGIN := 4.0

@onready var messages_vbox: VBoxContainer = _req(messages_vbox_path) as VBoxContainer
@onready var scroll: ScrollContainer = _req(scroll_path) as ScrollContainer
@onready var input: TextEdit = _req(input_path) as TextEdit
@onready var send_btn: Button = _req(send_btn_path) as Button
@onready var switch_butt: BaseButton = _req(switch_butt_path) as BaseButton

@onready var commands_popup: PanelContainer = _req(commands_popup_path) as PanelContainer
@onready var commands_scroll: ScrollContainer = _req(commands_scroll_path) as ScrollContainer
@onready var commands_list: VBoxContainer = _req(commands_list_path) as VBoxContainer

@onready var command_runner: Node = _req(command_runner_path)


func _ready() -> void:
	if commands_popup:
		commands_popup.hide()

	if commands_scroll:
		commands_scroll.custom_minimum_size.y = MAX_VISIBLE_COMMANDS * COMMAND_ROW_HEIGHT

	if send_btn:
		send_btn.focus_mode = Control.FOCUS_NONE
		send_btn.pressed.connect(_on_send_pressed)

	if input:
		input.text_changed.connect(_on_input_text_changed)
		input.grab_focus()

	if switch_butt:
		switch_butt.toggled.connect(_on_switch_butt_toggled)

	_refresh_commands("")


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:

		if event.keycode == KEY_ENTER:
			if event.shift_pressed:
				return
			if get_viewport().gui_get_focus_owner() != input:
				return
			get_viewport().set_input_as_handled()
			_send_message()

		if event.keycode == KEY_ESCAPE:
			if commands_popup and commands_popup.visible:
				commands_popup.hide()
				get_viewport().set_input_as_handled()
				return


func _on_send_pressed() -> void:
	_send_message()


func _send_message() -> void:
	if not input:
		return

	var text := input.text.strip_edges()
	if text.is_empty():
		return

	# komenda → przekaz do C#
	if text.begins_with("/"):
		_handle_command(text)
	else:
		_add_user_bubble(text)
		_add_gpt_bubble("hello world")

	input.text = ""
	input.grab_focus()


func _handle_command(text: String) -> void:
	if command_runner and command_runner.has_method("RunCommand"):
		command_runner.call("RunCommand", text)
	else:
		_add_user_bubble(text)
		_add_gpt_bubble("[No CommandRunner]")


func _on_input_text_changed() -> void:
	var prefix := _get_prefix()

	# toggle musi być włączony
	if not switch_butt or not switch_butt.button_pressed:
		commands_popup.hide()
		return

	# musi zaczynać się od "/"
	if prefix.is_empty() or not prefix.begins_with("/"):
		commands_popup.hide()
		return

	# odśwież i pokaż jeśli są wyniki
	_refresh_commands(prefix)
	_update_popup_visibility()


func _on_switch_butt_toggled(toggled_on: bool) -> void:
	if not toggled_on:
		commands_popup.hide()
		return

	# toggle ON → sprawdź czy input już nie ma prefixu
	var prefix := _get_prefix()
	if prefix.is_empty() or not prefix.begins_with("/"):
		return

	_refresh_commands(prefix)
	_update_popup_visibility()


func _get_prefix() -> String:
	if not input:
		return ""
	var txt := input.text.strip_edges()
	return txt


func _refresh_commands(prefix: String) -> void:
	if commands_list == null:
		return

	for c in commands_list.get_children():
		c.queue_free()

	var prefix_lc := prefix.to_lower()

	for cmd in available_commands:
		if not cmd.to_lower().begins_with(prefix_lc):
			continue

		var b := Button.new()
		b.text = cmd
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(_on_command_button_pressed.bind(cmd))
		commands_list.add_child(b)

	if commands_scroll:
		commands_scroll.custom_minimum_size.y = MAX_VISIBLE_COMMANDS * COMMAND_ROW_HEIGHT


func _update_popup_visibility() -> void:
	if not commands_popup:
		return
	if not switch_butt or not switch_butt.button_pressed:
		commands_popup.hide()
		return
	if commands_list.get_child_count() == 0:
		commands_popup.hide()
		return

	commands_popup.show()
	_position_commands_popup()


func _position_commands_popup() -> void:
	if not commands_popup or not input:
		return

	var vp_size := get_viewport_rect().size
	var popup_size := commands_popup.size

	if popup_size.y <= 0.0:
		popup_size.y = commands_scroll.custom_minimum_size.y

	var input_pos := input.get_global_position()
	var input_size := input.size

	var x := input_pos.x
	var y := input_pos.y - popup_size.y - POPUP_MARGIN

	if y < 0.0:
		y = input_pos.y + input_size.y + POPUP_MARGIN

	if x + popup_size.x > vp_size.x:
		x = vp_size.x - popup_size.x

	if x < 0.0:
		x = 0.0

	commands_popup.global_position = Vector2(x, y)


func _on_command_button_pressed(cmd: String) -> void:
	if not input:
		return

	input.text = cmd + " "
	input.caret_column = input.text.length()
	input.grab_focus()


func _add_user_bubble(text: String) -> void:
	if user_bubble_scene == null or messages_vbox == null:
		return

	var bubble: Node = user_bubble_scene.instantiate()
	messages_vbox.add_child(bubble)

	if bubble.has_method("set_text"):
		bubble.call("set_text", text)

	_scroll_to_bottom()


func _add_gpt_bubble(text: String) -> void:
	if gpt_bubble_scene == null or messages_vbox == null:
		return

	var bubble: Node = gpt_bubble_scene.instantiate()
	messages_vbox.add_child(bubble)

	if bubble.has_method("set_text"):
		bubble.call("set_text", text)

	_scroll_to_bottom()


func _scroll_to_bottom() -> void:
	if scroll == null:
		return
	await get_tree().process_frame
	scroll.scroll_vertical = int(scroll.get_v_scroll_bar().max_value)


func _req(path: NodePath) -> Node:
	if path == NodePath():
		return null
	return get_node_or_null(path)
