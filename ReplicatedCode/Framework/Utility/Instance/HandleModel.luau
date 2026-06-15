
local function handleModel(stageModel : Model, visible: boolean)
	for _ , part in ipairs(stageModel:GetChildren()) do
		if part:IsA("BasePart") and part.Name ~= "RootPart" then
			part.Transparency = visible and 0 or 1
			part.CanTouch = visible and true or false
			part.CanQuery = visible and true or false
			part.CanCollide = visible and true or false
		end
	end
end

return handleModel
