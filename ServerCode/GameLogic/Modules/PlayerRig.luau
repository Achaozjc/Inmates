--!strict

local DEFAULT_TIMEOUT = 10

local PlayerRig = {}

export type Parts = {
    humanoid: Humanoid,
    animator: Animator,
    rootPart: BasePart,
    torsoPart: BasePart,
    rightHandPart: BasePart,
}

local function waitForBasePart(character: Model, partName: string, timeout: number?): BasePart
    local part = character:FindFirstChild(partName) or character:WaitForChild(partName, timeout or DEFAULT_TIMEOUT)
    assert(part and part:IsA("BasePart"), string.format("Character missing BasePart %s", partName))
    return part :: BasePart
end

function PlayerRig.waitForHumanoid(character: Model, timeout: number?): Humanoid
    local humanoid = character:FindFirstChildOfClass("Humanoid")
        or character:WaitForChild("Humanoid", timeout or DEFAULT_TIMEOUT)
    assert(humanoid and humanoid:IsA("Humanoid"), "Character missing Humanoid")
    return humanoid :: Humanoid
end

function PlayerRig.waitForAnimator(humanoid: Humanoid, timeout: number?): Animator
    local animator = humanoid:FindFirstChildOfClass("Animator")
        or humanoid:WaitForChild("Animator", timeout or DEFAULT_TIMEOUT)
    assert(animator and animator:IsA("Animator"), "Humanoid missing Animator")
    return animator :: Animator
end

function PlayerRig.waitForRootPart(character: Model, timeout: number?): BasePart
    return waitForBasePart(character, "HumanoidRootPart", timeout)
end

function PlayerRig.waitForTorsoPart(character: Model, humanoid: Humanoid, timeout: number?): BasePart
    if humanoid.RigType == Enum.HumanoidRigType.R15 then
        return waitForBasePart(character, "UpperTorso", timeout)
    end
    return waitForBasePart(character, "Torso", timeout)
end

function PlayerRig.waitForRightHandPart(character: Model, humanoid: Humanoid, timeout: number?): BasePart
    if humanoid.RigType == Enum.HumanoidRigType.R15 then
        return waitForBasePart(character, "RightHand", timeout)
    end
    return waitForBasePart(character, "Right Arm", timeout)
end

function PlayerRig.waitForParts(character: Model, timeout: number?): Parts
    if not character:IsDescendantOf(workspace) then
        character.AncestryChanged:Wait()
    end

    local humanoid = PlayerRig.waitForHumanoid(character, timeout)
    local rootPart = PlayerRig.waitForRootPart(character, timeout)
    local torsoPart = PlayerRig.waitForTorsoPart(character, humanoid, timeout)
    local rightHandPart = PlayerRig.waitForRightHandPart(character, humanoid, timeout)
    local animator = PlayerRig.waitForAnimator(humanoid, timeout)

    return {
        humanoid = humanoid,
        animator = animator,
        rootPart = rootPart,
        torsoPart = torsoPart,
        rightHandPart = rightHandPart,
    }
end

return PlayerRig
