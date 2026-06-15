--!strict

local BackpackScript = {} :: any

BackpackScript.Enabled = false
BackpackScript.IsOpen = false
BackpackScript.OpenClose = function()
	BackpackScript.IsOpen = not BackpackScript.IsOpen
	BackpackScript.StateChanged:Fire(BackpackScript.IsOpen)
end

BackpackScript.StateChanged = Instance.new("BindableEvent")
BackpackScript.BackpackEmpty = Instance.new("BindableEvent")
BackpackScript.BackpackItemAdded = Instance.new("BindableEvent")
BackpackScript.BackpackItemRemoved = Instance.new("BindableEvent")

BackpackScript.BackpackEmpty.Name = "BackpackEmpty"
BackpackScript.BackpackItemAdded.Name = "BackpackAdded"
BackpackScript.BackpackItemRemoved.Name = "BackpackRemoved"

BackpackScript.ModuleName = "Backpack"
BackpackScript.KeepVRTopbarOpen = true
BackpackScript.VRIsExclusive = true
BackpackScript.VRClosesNonExclusive = true
BackpackScript.HotbarFrame = nil

function BackpackScript.init()
end

function BackpackScript.setEnabled(enabled: boolean)
	BackpackScript.Enabled = enabled
	if not enabled and BackpackScript.IsOpen then
		BackpackScript.IsOpen = false
		BackpackScript.StateChanged:Fire(false)
	end
end

function BackpackScript.setVisible(visible: boolean)
	BackpackScript.setEnabled(visible)
end

function BackpackScript.openInventory(_isOpen: boolean, _inventoryObj: any)
end

function BackpackScript.refreshMenuVisibilityRule()
end

return BackpackScript
