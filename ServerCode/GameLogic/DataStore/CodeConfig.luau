--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TimeTokenCategory = require(ReplicatedStorage.ReplicatedCode.GameLogic.SharedConstants.Categories.TimeTokenCategory)
local CodeRewardConfig = require(ReplicatedStorage.ReplicatedCode.GameLogic.Shared.Configs.CodeRewardConfig)

local CodeConfig = {}

CodeConfig.EXPIRATION = TimeTokenCategory.days * 20
CodeConfig.Codes = CodeRewardConfig.Codes

return CodeConfig
