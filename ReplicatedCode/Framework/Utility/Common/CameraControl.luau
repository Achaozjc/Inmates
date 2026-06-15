--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local localplayer = Players.LocalPlayer or Players:GetPropertyChangedSignal("LocalPlayer"):Wait() :: Player
local mouse = localplayer:GetMouse()
local Camera = workspace.CurrentCamera :: Camera
local Janitor = require(ReplicatedStorage.ReplicatedCode.Framework.Packages.Janitor)

local TWEEN_INFO = TweenInfo.new(0.5)
local CAMERA_MOVESIZE = 5
local cameraControl = {}
local janitor = Janitor.new()

-- 对话镜头：独立绑定点，避免与 cameraMove 等共用 janitor 时互相误清
local DIALOGUE_RENDER_STEP_NAME = "Framework_CameraDialogueFocus"
local dialogueFocusBound = false

-- 全屏菜单固定机位（装饰商店等）：与其它镜头互斥
local STATIC_SCENE_RENDER_STEP_NAME = "Framework_CameraStaticScene"
local staticSceneBound = false
local pendingStaticSceneTween: Tween? = nil

export type DialogueFocusOptions = {
	lookHeight: number?, -- 看向目标时在部件 Position 上的额外高度
	-- 以下均以玩家 HumanoidRootPart 为基准：后脑勺方向后退 + 左肩侧偏移（越肩看 NPC）
	shoulderBack: number?, -- 沿 -LookVector 后退距离
	shoulderSide: number?, -- 沿 -RightVector 侧移，正值为玩家左手侧（参考图：玩家在后脑勺侧方入画）
	shoulderHeight: number?, -- 相对 Root 向上的肩颈锚点高度
}


function cameraControl.setEnabled(enabled :boolean)
	Camera.CameraType = if enabled then Enum.CameraType.Custom else Enum.CameraType.Scriptable
end


function cameraControl.startControl(enabled :boolean)
	Camera.CameraType = if enabled then Enum.CameraType.Scriptable else Enum.CameraType.Custom
end


function cameraControl.setCFrame(cframe :CFrame)
	Camera.CFrame = cframe
end

function cameraControl.cameraMove(cframe :CFrame)
	janitor:Add(RunService.Heartbeat:Connect(function(deltaTime: number)
		Camera.CameraType = Enum.CameraType.Scriptable
		--camera.CFrame = CameraFocus.WorldCFrame	
		Camera.CFrame  = Camera.CFrame:Lerp(cframe * CFrame.Angles(
			math.rad((((mouse.Y - mouse.ViewSizeY/2)/mouse.ViewSizeY))* -CAMERA_MOVESIZE),
			math.rad((((mouse.X - mouse.ViewSizeX/2)/mouse.ViewSizeX))* -CAMERA_MOVESIZE),0
			),0.1) 
	end),"Disconnect")
end


function cameraControl.Zoom(part :BasePart?,info : TweenInfo,waitForCompletion :boolean?)
	if not part or not info or not waitForCompletion then
		return
	end
	Camera.CameraType = Enum.CameraType.Scriptable
	local distance = math.max(part.Size.X, part.Size.Y, part.Size.Z)* 1.5

	local direction=(Camera.CFrame.Position - part.Position).Unit
	local targetCFrame = CFrame.new(part.Position + direction * distance, part.Position)
	local tween = TweenService:Create(Camera, info, { CFrame = targetCFrame })
	tween:Play()
	
	if waitForCompletion then
		tween.Completed:Wait()
	end
end


function cameraControl.cameraView(amount: number)
	amount = tonumber(amount) or 0 

	if amount > 0 then
		localplayer.CameraMode = Enum.CameraMode.Classic 
	end

	local tween = TweenService:Create(localplayer, TweenInfo.new(.5), {
		CameraMinZoomDistance = amount,
		CameraMaxZoomDistance = amount 
	})
		
	tween.Completed:Once(function()
		localplayer.CameraMode = amount <= 0 and Enum.CameraMode.LockFirstPerson or Enum.CameraMode.Classic 
		tween:Destroy()
	end)
	tween:Play()
end 


function cameraControl.cameraFocus(field: number)
	local tween =TweenService:Create(Camera,TWEEN_INFO,{
		FieldOfView = field,
	})
	tween:Play()
end

function cameraControl.cameraFocusPosition(rootPart: BasePart)
	Camera.CameraType = Enum.CameraType.Scriptable
	local targetPosition = rootPart.Position + (rootPart.CFrame.LookVector * -10) + Vector3.new(0, 5, 0)
	Camera.CFrame = CFrame.lookAt(targetPosition, rootPart.Position, Vector3.yAxis)
	Camera.CameraType = Enum.CameraType.Custom
end

-- 结束对话镜头（恢复默认角色相机）
function cameraControl.endDialogueFocus()
	if dialogueFocusBound then
		RunService:UnbindFromRenderStep(DIALOGUE_RENDER_STEP_NAME)
		dialogueFocusBound = false
	end
	Camera.CameraType = Enum.CameraType.Custom
end

function cameraControl.endStaticSceneFocus()
	if pendingStaticSceneTween then
		pendingStaticSceneTween:Cancel()
		pendingStaticSceneTween = nil
	end
	if staticSceneBound then
		RunService:UnbindFromRenderStep(STATIC_SCENE_RENDER_STEP_NAME)
		staticSceneBound = false
	end
	Camera.CameraType = Enum.CameraType.Custom
end

--[[
	将相机固定为看向 lookAt，可选 Tween；结束后每帧锁定 CFrame，直至 endStaticSceneFocus。
	与对话镜头互斥：会先结束对话镜头。
]]
function cameraControl.focusStaticSceneAt(lookAt: Vector3, camPosition: Vector3, tweenInfo: TweenInfo?)
	cameraControl.endDialogueFocus()
	cameraControl.endStaticSceneFocus()

	local targetCFrame = CFrame.lookAt(camPosition, lookAt, Vector3.yAxis)
	Camera.CameraType = Enum.CameraType.Scriptable

	local function bindLock()
		staticSceneBound = true
		RunService:BindToRenderStep(STATIC_SCENE_RENDER_STEP_NAME, Enum.RenderPriority.Camera.Value, function()
			Camera.CameraType = Enum.CameraType.Scriptable
			Camera.CFrame = targetCFrame
		end)
	end

	if tweenInfo then
		local tween = TweenService:Create(Camera, tweenInfo, { CFrame = targetCFrame })
		pendingStaticSceneTween = tween
		tween.Completed:Once(function()
			if pendingStaticSceneTween ~= tween then
				return
			end
			pendingStaticSceneTween = nil
			tween:Destroy()
			bindLock()
		end)
		tween:Play()
	else
		Camera.CFrame = targetCFrame
		bindLock()
	end
end

--[[
	对话越肩镜头：相机在玩家后脑勺侧方（默认左肩后），看向 NPC 目标点。
	需在客户端调用；角色不存在时静默跳过。
]]
function cameraControl.focusDialogueSubject(subjectPart: BasePart, options: DialogueFocusOptions?)
	local lookHeight = (options and options.lookHeight) or 2
	local shoulderBack = (options and options.shoulderBack) or 5.8
	local shoulderSide = (options and options.shoulderSide) or 3.4
	local shoulderHeight = (options and options.shoulderHeight) or 2.1

	cameraControl.endDialogueFocus()

	local character = localplayer.Character
	local playerRoot = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not playerRoot then
		return
	end

	Camera.CameraType = Enum.CameraType.Scriptable
	dialogueFocusBound = true

	RunService:BindToRenderStep(DIALOGUE_RENDER_STEP_NAME, Enum.RenderPriority.Camera.Value, function()
		if not subjectPart.Parent then
			cameraControl.endDialogueFocus()
			return
		end

		local char = localplayer.Character
		local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not root then
			cameraControl.endDialogueFocus()
			return
		end

		local lookAt = subjectPart.Position + Vector3.new(0, lookHeight, 0)
		-- 肩颈锚点：再沿 -Look 后退、-Right 侧移，得到后脑勺侧方机位
		local pivot = root.Position + root.CFrame.UpVector * shoulderHeight
		local camPos = pivot - root.CFrame.LookVector * shoulderBack - root.CFrame.RightVector * shoulderSide
		Camera.CFrame = CFrame.lookAt(camPos, lookAt, Vector3.yAxis)
	end)
end

function cameraControl.stop()
	cameraControl.endDialogueFocus()
	cameraControl.endStaticSceneFocus()
	janitor:Cleanup()
	cameraControl.setEnabled(true)
end


return cameraControl

