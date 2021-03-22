objectdef obj_MiniMode inherits obj_State
{
	method Initialize()
	{
		This[parent]:Initialize
		DynamicAddBehavior("MiniMode", "MiniModes Only")
	}
}