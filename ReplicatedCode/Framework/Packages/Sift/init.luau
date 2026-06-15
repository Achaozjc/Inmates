--!strict
local Types = require(script.Types)

--[=[
	@class Sift

		Sift 是一个用于操作数组的库。它提供了许多
	数组（列表）、字典和集合的函数。

	Sift 由多个子模块组成。每个子模块提供
	操作特定数据类型的函数，并且
	可以通过 Sift 模块中各自的名称进行访问
	(例如`Sift.Array.At()`），或直接访问（例如`local At = require(Sift.Array.At)`）。

	某些方法和模块也有别名，这些别名可以在相应子模块/方法的
	相应子模块/方法的文档中。

	完整文档请参见各个子模块页面。

	Luau 类型 `Dictionary<K, V>`、`Array<T>`（别名为 `List<T>`）和 `Set<T>` 由 Sift 模块导出（例如，可通过 `Sift.Array<string>` 使用它们），但也可从 [Sift.Types] 获取。
]=]
local Sift = {
	Array = require(script.Array),
	Dictionary = require(script.Dictionary),
	Set = require(script.Set),

	None = require(script.None),
	Types = require(script.Types),

	equalObjects = require(script.Util.equalObjects),
	isEmpty = require(script.Util.isEmpty),
}

Sift.List = Sift.Array

--- @prop Array Array
--- @within Sift

--- @prop List Array
--- @within Sift
--- @tag Alias

--- @prop Dictionary Dictionary
--- @within Sift

--- @prop Set Set
--- @within Sift

--- @prop Types Types
--- @within Sift

export type Dictionary<K, V> = Types.Dictionary<K, V>

export type Array<T> = Types.Array<T>
export type List<T> = Array<T>
export type Set<T> = Types.Set<T>

return Sift
