extends Reference
# Persistent source-state markers, independent of gameplay effects and RNG.
func cursed(visual, active: bool, kind: String, factory, elapsed: float):
	var marker=visual.get_node_or_null("CursedStatus3D")
	if marker==null and not active:return
	if marker==null:
		marker=Spatial.new()
		marker.name="CursedStatus3D"
		visual.add_child(marker)
		var radius=0.23 if kind=="weapon" else 0.44
		for i in range(4):
			var angle=TAU*i/4.0
			var crystal=factory.box(marker,Vector3(cos(angle)*radius,0.25,sin(angle)*radius),Vector3(0.08,0.15,0.08),Color("bb87df"))
			crystal.rotation_degrees.z=35
	marker.visible=active
	if active:marker.rotation.y=elapsed*0.7
	visual.set_meta("cursed_status_visible",active)

func recovering(visual, active: bool, factory, elapsed: float):
	var marker=visual.get_node_or_null("RecoveryStatus3D")
	if marker==null and not active:return
	if marker==null:
		marker=Spatial.new()
		marker.name="RecoveryStatus3D"
		visual.add_child(marker)
		for i in range(3):
			var cross=Spatial.new()
			cross.translation=Vector3((i-1)*0.32,0.8,0)
			marker.add_child(cross)
			factory.box(cross,Vector3.ZERO,Vector3(0.06,0.2,0.04),Color("70d9a8"))
			factory.box(cross,Vector3.ZERO,Vector3(0.16,0.06,0.04),Color("70d9a8"))
	marker.visible=active
	if active:marker.translation.y=0.07*sin(elapsed*4)
