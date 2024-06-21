extends AudioStreamPlayer

func _ready():
	# warning-ignore:return_value_discarded
	connect("finished", Callable(self, "queue_free"))
