class_name HumanAimModifier
extends SkeletonModifier3D

var aim: HumanAimComponent

func _process_modification_with_delta(_delta: float) -> void:
	if aim == null or not aim.actor.is_guard() or aim.actor.is_in_group("corpses"):
		return
	var skeleton := get_skeleton()
	var spine := skeleton.find_bone("spine_02")
	var head := skeleton.find_bone("Head")
	var right_arm := skeleton.find_bone("upperarm_r")
	var right_hand := skeleton.find_bone("hand_r")
	var left_hand := skeleton.find_bone("hand_l")
	if spine < 0 or head < 0 or right_arm < 0 or right_hand < 0 or left_hand < 0:
		return
	var look_direction := -aim.perception.global_basis.z.normalized()
	var body_direction := -aim.actor.global_basis.z.normalized()
	var torso_rotation := Quaternion(body_direction, look_direction)
	# The torso contributes up to 30 degrees; the arms handle the remaining elevation.
	var weight := minf(0.45, deg_to_rad(30.0) / maxf(torso_rotation.get_angle(), 0.001))
	_rotate_world(skeleton, spine, Quaternion.IDENTITY.slerp(torso_rotation, weight))
	var hand_before := _world_pose(skeleton, right_hand)
	var support_offset := hand_before.affine_inverse() * _world_pose(skeleton, left_hand)
	if aim.weapon.weapon_instance != null:
		for iteration in 3:
			var gun_pose := _world_pose(skeleton, right_hand) * aim.weapon.weapon_instance.transform
			var muzzle_position := gun_pose * aim.weapon.muzzle_local_position
			var barrel_direction := (gun_pose.basis * Vector3.LEFT).normalized()
			var target_direction := (aim.aim_point - muzzle_position).normalized()
			if not target_direction.is_zero_approx():
				_rotate_world(skeleton, right_arm, Quaternion(barrel_direction, target_direction))
		var support_pose := _world_pose(skeleton, right_hand) * support_offset
		_aim_left_arm(skeleton, support_pose)
	var head_pose := _world_pose(skeleton, head)
	# UAL's face points along local +Z. Keep the visible face aligned with the sensor.
	_rotate_world(skeleton, head, Quaternion(head_pose.basis.z.normalized(), look_direction))

func _world_pose(skeleton: Skeleton3D, bone: int) -> Transform3D:
	return skeleton.global_transform * skeleton.get_bone_global_pose(bone)

func _rotate_world(skeleton: Skeleton3D, bone: int, rotation: Quaternion) -> void:
	var pose := _world_pose(skeleton, bone)
	var desired_basis := Basis(rotation) * pose.basis.orthonormalized()
	var parent := skeleton.get_bone_parent(bone)
	var parent_basis := skeleton.global_basis if parent < 0 else _world_pose(skeleton, parent).basis
	skeleton.set_bone_pose_rotation(bone, (parent_basis.orthonormalized().inverse() * desired_basis).get_rotation_quaternion())

func _aim_left_arm(skeleton: Skeleton3D, target: Transform3D) -> void:
	var upper := skeleton.find_bone("upperarm_l")
	var lower := skeleton.find_bone("lowerarm_l")
	var hand := skeleton.find_bone("hand_l")
	if upper < 0 or lower < 0 or hand < 0:
		return
	var shoulder := _world_pose(skeleton, upper).origin
	var elbow := _world_pose(skeleton, lower).origin
	var wrist := _world_pose(skeleton, hand).origin
	var upper_length := shoulder.distance_to(elbow)
	var lower_length := elbow.distance_to(wrist)
	var offset := target.origin - shoulder
	if offset.is_zero_approx() or minf(upper_length, lower_length) < 0.001:
		return
	var axis := offset.normalized()
	var reach := clampf(offset.length(), absf(upper_length - lower_length) + 0.001, upper_length + lower_length - 0.001)
	var bend := (elbow - shoulder).slide(axis).normalized()
	if bend.is_zero_approx():
		bend = aim.actor.global_basis.x.slide(axis).normalized()
	var along := (upper_length * upper_length + reach * reach - lower_length * lower_length) / (2.0 * reach)
	var height := sqrt(maxf(upper_length * upper_length - along * along, 0.0))
	var desired_elbow := shoulder + axis * along + bend * height
	_rotate_world(skeleton, upper, Quaternion((elbow - shoulder).normalized(), (desired_elbow - shoulder).normalized()))
	elbow = _world_pose(skeleton, lower).origin
	wrist = _world_pose(skeleton, hand).origin
	_rotate_world(skeleton, lower, Quaternion((wrist - elbow).normalized(), (shoulder + axis * reach - elbow).normalized()))
	var wrist_rotation := target.basis.orthonormalized() * _world_pose(skeleton, hand).basis.orthonormalized().inverse()
	_rotate_world(skeleton, hand, wrist_rotation.get_rotation_quaternion())
