local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Button = require(ReplicatedStorage.ReplicatedCode.Framework.UI.Button)
local Keybind = require(ReplicatedStorage.ReplicatedCode.Framework.Input.Keybind)


local KeyCodeBindingInfo = {
	Close = {
		actionName = "ActivateCloseActionButton",
		keyCodes = {
			Keybind.GamepadBackAction,
			Keybind.KeyboardBackAction,
		},
	}:: Button.KeyCodeBindingInfo,
	
	Inventory = {
		actionName = "OpenInventory",
		keyCodes = {
			Keybind.GamepadButtonDPadUp,
			Keybind.KeyboardInventoryOpenButton,
		},
	}:: Button.KeyCodeBindingInfo,
	
	MyFarm = {
		actionName = "MyFarm",
		keyCodes = {
			Keybind.GamepadButtonDPadDown,
		},
	}:: Button.KeyCodeBindingInfo,
	
	Cub = {
		actionName = "CubShop",
		keyCodes = {
			Keybind.GamepadButtonDPadLeft,
		},
	}:: Button.KeyCodeBindingInfo,
	
	Sell = {
		actionName = "SellShop",
		keyCodes = {
			Keybind.GamepadButtonDPadRight,
		},
	}:: Button.KeyCodeBindingInfo,
	
	Tab = {
		actionName = "Tab",
		keyCodes = {
			Keybind.KeyboardTab,
			Keybind.GamepadButtonDPadRight,
		},
	}:: Button.KeyCodeBindingInfo,
	
	Number1 = {
		actionName = "Number1",
		keyCodes = {
			Keybind.KeyboardTab,
		},
	}:: Button.KeyCodeBindingInfo,
	
	Yes = {
		actionName = "Yes",
		keyCodes = {
			Keybind.GamepadButtonY,
		},
	}:: Button.KeyCodeBindingInfo,

	No = {
		actionName = "No",
		keyCodes = {
			Keybind.GamepadButtonX,
		},
	}:: Button.KeyCodeBindingInfo,
	
	Shop = {
		actionName = "Shop",
		keyCodes = {
			Keybind.GamepadButtonY,
		},
	}:: Button.KeyCodeBindingInfo,
	
}

return KeyCodeBindingInfo 
