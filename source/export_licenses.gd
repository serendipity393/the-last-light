extends SceneTree
func _init() -> void:
	var f:=FileAccess.open("res://../发布版/最后一盏灯/第三方许可.txt",FileAccess.WRITE)
	f.store_string("GODOT ENGINE 4.4.1\n\n"+Engine.get_license_text()+"\n\nTHIRD-PARTY COMPONENTS\n\n")
	for part in Engine.get_copyright_info(): f.store_string(JSON.stringify(part,"\t")+"\n\n")
	for name in Engine.get_license_info(): f.store_string(name+"\n"+str(Engine.get_license_info()[name])+"\n\n")
	f.close()
	quit()
