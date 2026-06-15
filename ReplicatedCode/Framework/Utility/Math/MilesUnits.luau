-- Arbitrary conversion for studs per mile. In this case, a stud is assumed to be one foot.
local STUDS_PER_MILE = 5280
local HOUR_SECONDS = 3600

local Units = {}

function Units.studsToMiles(studs: number): number
	return studs / STUDS_PER_MILE
end

function Units.milesToStuds(miles: number): number
	return miles * STUDS_PER_MILE
end

function Units.studsPerSecondToMilesPerHour(studsPerSecond: number): number
	local milesPerSecond = Units.studsToMiles(studsPerSecond)
	local milesPerHour = milesPerSecond * HOUR_SECONDS
	return milesPerHour
end

function Units.milesPerHourToStudsPerSecond(milesPerHour: number): number
	local studsPerHour = Units.milesToStuds(milesPerHour)
	local studsPerSecond = studsPerHour / HOUR_SECONDS
	return studsPerSecond
end

return Units
