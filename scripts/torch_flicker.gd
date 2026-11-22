extends PointLight2D

var _time := 0.0
var _base := 1.0


func _ready() -> void:
	_base = energy
	_time = randf() * 10.0


func _process(delta: float) -> void:
	_time += delta
	energy = _base * (1.0 + sin(_time * 6.7) * 0.06 + sin(_time * 15.3) * 0.03)
