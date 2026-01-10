extends PanelContainer
class_name InputNavbar

signal request_close
signal open_chat_requested
signal open_cmd_requested

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	hide()

func close() -> void:
	hide()
	request_close.emit()


func _on_chat_butt_pressed() -> void:
	print("test - poszedł sygnał")
	open_chat_requested.emit()

func _on_cmd_butt_pressed() -> void:
	print("test - poszedł sygnał")
	open_cmd_requested.emit()
