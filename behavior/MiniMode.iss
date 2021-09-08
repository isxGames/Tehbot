objectdef obj_MiniMode inherits obj_StateQueue
{
	method Initialize()
	{
		This[parent]:Initialize
		DynamicAddBehavior("MiniMode", "MiniModes Only")
	}
}