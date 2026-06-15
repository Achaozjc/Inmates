local convertSaveData = {}

function convertSaveData.cframe(String : string) :CFrame
	local splittedString = string.split(String,",")
	local newCFrame = CFrame.new(
		splittedString[1],
		splittedString[2],
		splittedString[3],
		splittedString[4],
		splittedString[5],
		splittedString[6],
		splittedString[7],
		splittedString[8],
		splittedString[9],
		splittedString[10],
		splittedString[11],
		splittedString[12]
	)
	return newCFrame
end

function convertSaveData.position(String: string) :Vector3
	local splittedString = string.split(String,",")
	local position = Vector3.new(
		splittedString[1], 
		splittedString[2], 
		splittedString[3]
	)
	return position
end

function convertSaveData.color3(String: string) :Color3
	local splittedString = string.split(String,",")
	local position = Color3.new(
		splittedString[1], 
		splittedString[2], 
		splittedString[3]
	)
	return position
end

return convertSaveData