extends Control

export(String, FILE, "*.tscn") var next_scene



func _on_Start_button_up():
	TransitionMgr.transitionTo(next_scene)
