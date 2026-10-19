--!strict
-- The daily login streak. Days are counted in UTC from os.time(), so everyone rolls over at the
-- same moment. Pure numbers so tools/test can check it.
local Daily = {}

Daily.MaxDay = 7 -- the reward grows up to this streak day, then stays there
Daily.PerDay = 0.5 -- stat points on your lowest stat for each streak day

function Daily.today(now: number): number
	return now // 86400
end

-- the streak after logging in on `today`, given the last day it counted. nil if it already
-- counted today (no reward). a missed day starts it over at 1
function Daily.next(lastDay: number, streak: number, today: number): number?
	if lastDay == today then
		return nil
	end
	return if lastDay == today - 1 then streak + 1 else 1
end

function Daily.reward(streak: number): number
	return math.min(streak, Daily.MaxDay) * Daily.PerDay
end

assert(Daily.next(10, 3, 10) == nil, "same day gives nothing")
assert(Daily.next(9, 3, 10) == 4, "next day adds one")
assert(Daily.next(7, 3, 10) == 1, "a missed day starts over")
assert(Daily.next(0, 0, 10) == 1, "first ever login is day 1")
assert(Daily.reward(1) == 0.5 and Daily.reward(30) == Daily.MaxDay * Daily.PerDay, "reward caps")
assert(Daily.today(86400 * 5 + 100) == 5, "day boundary")

return Daily
