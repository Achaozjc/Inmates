local LeaderboardIgnore = {}

local list = {
    2415509880, --Roronoa
    1626784844, --OdiBrodie
    1254921096, --daishilalala
    4595632038, --apg
    5734186222, --fuguo
    5156601289, --junchao
    2289588826, --Broleolee
    9658259778, --ApparentlyOwner
}

function LeaderboardIgnore.ignore(userId: number)
    if tonumber(userId) < 0 or table.find(list, userId) then
        return true
    end
    return false
end

return LeaderboardIgnore
