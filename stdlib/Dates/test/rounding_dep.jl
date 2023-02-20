# This file is a part of Julia. License is MIT: https://julialang.org/license

module RoundingTestsDep

using Test
using Dates

@testset "Rounding for dates at the rounding epoch (year 0000)" begin
    dt = Dates.DateTime(0)
    @test floor(dt, Dates.Year) == dt
    @test floor(dt, Dates.Month) == dt
    @test floor(dt, Dates.Week) == Dates.Date(-1, 12, 27)   # Monday prior to 0000-01-01
    @test floor(Dates.Date(-1, 12, 27), Dates.Week) == Dates.Date(-1, 12, 27)
    @test floor(dt, Dates.Day) == dt
    @test floor(dt, Dates.Hour) == dt
    @test floor(dt, Dates.Minute) == dt
    @test floor(dt, Dates.Second) == dt
    @test ceil(dt, Dates.Year) == dt
    @test ceil(dt, Dates.Month) == dt
    @test ceil(dt, Dates.Week) == Dates.Date(0, 1, 3)       # Monday following 0000-01-01
    @test ceil(Dates.Date(0, 1, 3), Dates.Week) == Dates.Date(0, 1, 3)
    @test ceil(dt, Dates.Day) == dt
    @test ceil(dt, Dates.Hour) == dt
    @test ceil(dt, Dates.Minute) == dt
    @test ceil(dt, Dates.Second) == dt
end
@testset "Rounding for multiples of a period" begin
    # easiest to test close to rounding epoch
    dt = Dates.DateTime(0, 1, 19, 19, 19, 19, 19)
    @test floor(dt, Dates.Year(2)) == DateTime(0)
    @test floor(dt, Dates.Month(2)) == DateTime(0, 1)       # Odd number; months are 1-indexed
    @test floor(dt, Dates.Week(2)) == DateTime(0, 1, 17)    # Third Monday of 0000
    @test floor(dt, Dates.Day(2)) == DateTime(0, 1, 19)     # Odd number; days are 1-indexed
    @test floor(dt, Dates.Hour(2)) == DateTime(0, 1, 19, 18)
    @test floor(dt, Dates.Minute(2)) == DateTime(0, 1, 19, 19, 18)
    @test floor(dt, Dates.Second(2)) == DateTime(0, 1, 19, 19, 19, 18)
    @test ceil(dt, Dates.Year(2)) == DateTime(2)
    @test ceil(dt, Dates.Month(2)) == DateTime(0, 3)        # Odd number; months are 1-indexed
    @test ceil(dt, Dates.Week(2)) == DateTime(0, 1, 31)     # Fifth Monday of 0000
    @test ceil(dt, Dates.Day(2)) == DateTime(0, 1, 21)      # Odd number; days are 1-indexed
    @test ceil(dt, Dates.Hour(2)) == DateTime(0, 1, 19, 20)
    @test ceil(dt, Dates.Minute(2)) == DateTime(0, 1, 19, 19, 20)
    @test ceil(dt, Dates.Second(2)) == DateTime(0, 1, 19, 19, 19, 20)
end
@testset "Rounding for dates with negative years" begin
    dt = Dates.DateTime(-1, 12, 29, 19, 19, 19, 19)
    @test floor(dt, Dates.Year(2)) == DateTime(-2)
    @test floor(dt, Dates.Month(2)) == DateTime(-1, 11)     # Odd number; months are 1-indexed
    @test floor(dt, Dates.Week(2)) == DateTime(-1, 12, 20)  # 2 weeks prior to 0000-01-03
    @test floor(dt, Dates.Day(2)) == DateTime(-1, 12, 28)   # Even; 4 days prior to 0000-01-01
    @test floor(dt, Dates.Hour(2)) == DateTime(-1, 12, 29, 18)
    @test floor(dt, Dates.Minute(2)) == DateTime(-1, 12, 29, 19, 18)
    @test floor(dt, Dates.Second(2)) == DateTime(-1, 12, 29, 19, 19, 18)
    @test ceil(dt, Dates.Year(2)) == DateTime(0)
    @test ceil(dt, Dates.Month(2)) == DateTime(0, 1)        # Odd number; months are 1-indexed
    @test ceil(dt, Dates.Week(2)) == DateTime(0, 1, 3)      # First Monday of 0000
    @test ceil(dt, Dates.Day(2)) == DateTime(-1, 12, 30)    # Even; 2 days prior to 0000-01-01
    @test ceil(dt, Dates.Hour(2)) == DateTime(-1, 12, 29, 20)
    @test ceil(dt, Dates.Minute(2)) == DateTime(-1, 12, 29, 19, 20)
    @test ceil(dt, Dates.Second(2)) == DateTime(-1, 12, 29, 19, 19, 20)
end
@testset "Rounding for dates that should not need rounding" begin
    for dt in [Dates.DateTime(2016, 1, 1), Dates.DateTime(-2016, 1, 1)]
        local dt
        for p in [Dates.Year, Dates.Month, Dates.Day, Dates.Hour, Dates.Minute, Dates.Second]
            local p
            @test floor(dt, p) == dt
            @test ceil(dt, p) == dt
        end
    end
end
@testset "Various available RoundingModes" begin
    dt = Dates.DateTime(2016, 2, 28, 12)
    @test round(dt, Dates.Day, RoundNearestTiesUp) == Dates.DateTime(2016, 2, 29)
    @test round(dt, Dates.Day, RoundUp) == Dates.DateTime(2016, 2, 29)
    @test round(dt, Dates.Day, RoundDown) == Dates.DateTime(2016, 2, 28)
    @test_throws DomainError round(dt, Dates.Day, RoundNearest)
    @test_throws DomainError round(dt, Dates.Day, RoundNearestTiesAway)
    @test_throws DomainError round(dt, Dates.Day, RoundToZero)
    @test round(dt, Dates.Day) == round(dt, Dates.Day, RoundNearestTiesUp)
end
@testset "Rounding datetimes to invalid resolutions" begin
    dt = Dates.DateTime(2016, 2, 28, 12, 15)
    for p in [Dates.Year, Dates.Month, Dates.Week, Dates.Day, Dates.Hour]
        local p
        for v in [-1, 0]
            @test_throws DomainError floor(dt, p(v))
            @test_throws DomainError ceil(dt, p(v))
            @test_throws DomainError round(dt, p(v))
        end
    end
end
@testset "Rounding for periods" begin
    x = Dates.Second(172799)
    @test floor(x, Dates.Week) == Dates.Week(0)
    @test floor(x, Dates.Day) == Dates.Day(1)
    @test floor(x, Dates.Hour) == Dates.Hour(47)
    @test floor(x, Dates.Minute) == Dates.Minute(2879)
    @test floor(x, Dates.Second) == Dates.Second(172799)
    @test floor(x, Dates.Millisecond) == Dates.Millisecond(172799000)
    @test ceil(x, Dates.Week) == Dates.Week(1)
    @test ceil(x, Dates.Day) == Dates.Day(2)
    @test ceil(x, Dates.Hour) == Dates.Hour(48)
    @test ceil(x, Dates.Minute) == Dates.Minute(2880)
    @test ceil(x, Dates.Second) == Dates.Second(172799)
    @test ceil(x, Dates.Millisecond) == Dates.Millisecond(172799000)
    @test round(x, Dates.Week) == Dates.Week(0)
    @test round(x, Dates.Day) == Dates.Day(2)
    @test round(x, Dates.Hour) == Dates.Hour(48)
    @test round(x, Dates.Minute) == Dates.Minute(2880)
    @test round(x, Dates.Second) == Dates.Second(172799)
    @test round(x, Dates.Millisecond) == Dates.Millisecond(172799000)

    x = Dates.Nanosecond(2000999999)
    @test floor(x, Dates.Second) == Dates.Second(2)
    @test floor(x, Dates.Millisecond) == Dates.Millisecond(2000)
    @test floor(x, Dates.Microsecond) == Dates.Microsecond(2000999)
    @test floor(x, Dates.Nanosecond) == x
    @test ceil(x, Dates.Second) == Dates.Second(3)
    @test ceil(x, Dates.Millisecond) == Dates.Millisecond(2001)
    @test ceil(x, Dates.Microsecond) == Dates.Microsecond(2001000)
    @test ceil(x, Dates.Nanosecond) == x
    @test round(x, Dates.Second) == Dates.Second(2)
    @test round(x, Dates.Millisecond) == Dates.Millisecond(2001)
    @test round(x, Dates.Microsecond) == Dates.Microsecond(2001000)
    @test round(x, Dates.Nanosecond) == x
end

@testset "Rounding DateTime to Date" begin
    now_ = DateTime(2020, 9, 1, 13)
    for p in (Year, Month, Day)
        for r in (RoundUp, RoundDown)
            @test round(Date, now_, p, r) == round(Date(now_), p, r)
        end
        @test round(Date, now_, p) == round(Date, now_, p, RoundNearestTiesUp)
        @test floor(Date, now_, p) == round(Date, now_, p, RoundDown)
        @test ceil(Date, now_, p)  == round(Date, now_, p, RoundUp)
    end
end
@testset "Rounding for periods that should not need rounding" begin
    for x in [Dates.Week(3), Dates.Day(14), Dates.Second(604800)]
        local x
        for p in [Dates.Week, Dates.Day, Dates.Hour, Dates.Second, Dates.Millisecond, Dates.Microsecond, Dates.Nanosecond]
            local p
            @test floor(x, p) == p(x)
            @test ceil(x, p) == p(x)
        end
    end
end
@testset "Various available RoundingModes for periods" begin
    x = Dates.Hour(36)
    @test round(x, Dates.Day, RoundNearestTiesUp) == Dates.Day(2)
    @test round(x, Dates.Day, RoundUp) == Dates.Day(2)
    @test round(x, Dates.Day, RoundDown) == Dates.Day(1)
    @test_throws DomainError round(x, Dates.Day, RoundNearest)
    @test_throws DomainError round(x, Dates.Day, RoundNearestTiesAway)
    @test_throws DomainError round(x, Dates.Day, RoundToZero)
    @test round(x, Dates.Day) == round(x, Dates.Day, RoundNearestTiesUp)
end
@testset "Rounding periods to invalid resolutions" begin
    x = Dates.Hour(86399)
    for p in [Dates.Week, Dates.Day, Dates.Hour, Dates.Second, Dates.Millisecond, Dates.Microsecond, Dates.Nanosecond]
        local p
        for v in [-1, 0]
            # @test_throws DomainError floor(x, p(v))
            # @test_throws DomainError ceil(x, p(v))
            # @test_throws DomainError round(x, p(v))
        end
    end
    for p in [Dates.Year, Dates.Month]
        local p
        for v in [-1, 0, 1]
            # @test_throws MethodError floor(x, p(v))
            # @test_throws MethodError ceil(x, p(v))
            # @test_throws DomainError round(x, p(v))
        end
    end
end

end
