class_name HumanFearModifier
extends SkeletonModifier3D

## A pleading upper-body animation layered over the civilian crouch clips.
var actor: HumanController
var blend := 0.0
var phase := 0.0

func _process_modification_with_delta(delta: float) -> void:
	if actor == null or actor.is_guard() or actor.is_in_group("corpses"):
		blend = 0.0
		return
	blend = move_toward(blend, 1.0 if actor.civilian_crouching else 0.0, delta * 4.0)
	if blend <= 0.0:
		return
	phase += delta
	var skeleton := get_skeleton()
	var head := skeleton.find_bone("Head")
	if head < 0:
		return
	var forward := -actor.global_basis.z.normalized()
	var right := actor.global_basis.x.normalized()
	var head_pose := _pose(skeleton, head)
	# Small repeated nods and uneven trembling keep the gesture alive.
	var gaze := (forward + Vector3.DOWN * (0.3 + 0.08 * sin(phase * 3.2))).normalized()
	_rotate(skeleton, head, Quaternion(head_pose.basis.z.normalized(), gaze))
	var tremble := sin(phase * 19.0) * 0.009 + sin(phase * 27.0) * 0.004
	var center := head_pose.origin + forward * (0.27 + 0.025 * sin(phase * 3.2)) + Vector3.DOWN * 0.15
	for side: float in [-1.0, 1.0]:
		var suffix := "l" if side < 0.0 else "r"
		var target := center + right * (side * 0.075 + tremble) + Vector3.UP * tremble
		_arm(skeleton, suffix, target, (Vector3.DOWN + right * side * 0.45 - forward * 0.2).normalized())

func _pose(skeleton: Skeleton3D, bone: int) -> Transform3D:
	return skeleton.global_transform * skeleton.get_bone_global_pose(bone)

func _rotate(skeleton: Skeleton3D, bone: int, rotation: Quaternion) -> void:
	var desired := Basis(Quaternion.IDENTITY.slerp(rotation, blend)) * _pose(skeleton, bone).basis.orthonormalized()
	var parent := skeleton.get_bone_parent(bone)
	var parent_basis := skeleton.global_basis if parent < 0 else _pose(skeleton, parent).basis
	skeleton.set_bone_pose_rotation(bone, (parent_basis.orthonormalized().inverse() * desired).get_rotation_quaternion())

func _arm(skeleton: Skeleton3D, suffix: String, target: Vector3, bend_direction: Vector3) -> void:
	var upper := skeleton.find_bone("upperarm_" + suffix)
	var lower := skeleton.find_bone("lowerarm_" + suffix)
	var hand := skeleton.find_bone("hand_" + suffix)
	if upper < 0 or lower < 0 or hand < 0:
		return
	var shoulder := _pose(skeleton, upper).origin
	var elbow := _pose(skeleton, lower).origin
	var wrist := _pose(skeleton, hand).origin
	var a := shoulder.distance_to(elbow)
	var b := elbow.distance_to(wrist)
	var axis := (target - shoulder).normalized()
	var reach := clampf(shoulder.distance_to(target), absf(a - b) + 0.001, a + b - 0.001)
	var along := (a * a + reach * reach - b * b) / (2.0 * reach)
	var bend := bend_direction.slide(axis).normalized()
	var desired_elbow := shoulder + axis * along + bend * sqrt(maxf(a * a - along * along, 0.0))
	_rotate(skeleton, upper, Quaternion((elbow - shoulder).normalized(), (desired_elbow - shoulder).normalized()))
	elbow = _pose(skeleton, lower).origin
	wrist = _pose(skeleton, hand).origin
	_rotate(skeleton, lower, Quaternion((wrist - elbow).normalized(), (shoulder + axis * reach - elbow).normalized()))
	# Upright fingers make the joined hands read as pleading, not holding a weapon.
	var middle := skeleton.find_bone("middle_01_" + suffix)
	if middle >= 0:
		var fingers := (_pose(skeleton, middle).origin - _pose(skeleton, hand).origin).normalized()
		_rotate(skeleton, hand, Quaternion(fingers, Vector3.UP))
