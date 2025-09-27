extends Node3D

var lifetime : float = 0.1
var startPosition : Vector3 = Vector3.ZERO
var endPosition : Vector3 = Vector3.ZERO

var curTime : float = 0.0

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	curTime += delta
	if curTime > lifetime:
		queue_free()
	else:
		global_position = startPosition
		global_basis = Basis.looking_at(endPosition - startPosition)
		$Origin.scale = Vector3(1,1,startPosition.distance_to(endPosition)*10)
		
