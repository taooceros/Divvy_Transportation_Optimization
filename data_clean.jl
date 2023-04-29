##
using Pkg
Pkg.add("Tidier")
Pkg.add("DataFrames")
Pkg.add("CSV")
Pkg.add("DataFramesMeta")
Pkg.add("KernelDensity")
Pkg.add("Interpolations")
Pkg.add("Plots")
Pkg.add("StatsPlots")




##

# Read in the data

stations = CSV.read("Divvy_Bicycle_Stations.csv", DataFrame)

##

@chain df begin
    @summarise(total_docks = sum(DocksInService))
end

##
using DataFrames, CSV, DataFramesMeta
using Dates
using Statistics
using Gadfly

# Read trip data

trips_2022_05 = CSV.read("202205-divvy-tripdata.csv", DataFrame)
trips_2023_03 = CSV.read("202303-divvy-tripdata.csv", DataFrame)

time_format = dateformat"yyyy-mm-dd HH:MM:SS"

trips = (trips_2022_05, trips_2023_03)

for trip in trips
    @transform!(trip, :started_at = Dates.DateTime.(:started_at, time_format))
    @transform!(trip, :ended_at = Dates.DateTime.(:ended_at, time_format))
    @transform!(trip, :started_hour = Dates.hour.(:started_at))
    @transform!(trip, :ended_hour = Dates.hour.(:ended_at))
    @transform!(trip, :started_day_of_week = Dates.dayofweek.(:started_at))
    @transform!(trip, :ended_day_of_week = Dates.dayofweek.(:ended_at))
    @transform!(trip, :started_month = Dates.month.(:started_at))
    @transform!(trip, :ended_month = Dates.month.(:ended_at))
    @transform!(trip, :trip_length = Dates.value.(:ended_at - :started_at) / 1000 / 60)
end

dropmissing!.(trips)

##

station_data = @chain trips_2022_05 begin
    groupby(:start_station_id)
    @combine begin
        :total_trips = length(:start_station_id)
        :avg_trip_length = mean(:trip_length)
        :median_trip_length = median(:trip_length)
        :long_trip = mean(:trip_length .> 30)
        :start_lng = first(:start_lng)
        :start_lat = first(:start_lat)
    end
    @subset :total_trips .> 100
end

Gadfly.plot(station_data, x=:start_lng, y=:start_lat, color=:total_trips, Geom.point)

##


# group by bike id and find the average trip length

@chain trips begin
    groupby(:bike_id)
    @combine begin
        :total_trips = length(:trip_length)
        :avg_trip_length = mean(:trip_length)
        :median_trip_length = median(:trip_length)
        :long_trip = mean(:trip_length .> 30)
    end
end

# group by from_station_id and find the average trip length

@chain trips begin
    groupby(:from_station_id)
    @combine begin
        :total_trips = length(:trip_length)
        :avg_trip_length = mean(:trip_length)
        :median_trip_length = median(:trip_length)
        :long_trip = mean(:trip_length .> 30)
    end
end


# check cycle trips
@chain trips begin
    @transform :circle_trip = :from_station_id .== :to_station_id
    groupby(:circle_trip)
    @combine begin
        :total_trips = length(:trip_length)
        :avg_trip_length = mean(:trip_length)
        :median_trip_length = median(:trip_length)
        :long_trip = mean(:trip_length .> 30)
    end
end

# different time range usage data analysis
@chain trips begin
    @transform :hour = Dates.hour.(:start_time)
    groupby([:from_station_id, :hour])
    @combine begin
        :total_trips = length(:trip_length)
        :avg_trip_length = mean(:trip_length)
        :median_trip_length = median(:trip_length)
        :long_trip = mean(:trip_length .> 30)
    end
end

##

by_month = @chain trips begin
    @select(:start_month, :from_longitude, :from_latitude, :to_longitude, :to_latitude)
    # remove missing values
    @subset! :from_longitude .+ :from_latitude .+ :to_longitude .+ :to_latitude .!== missing
    groupby(:start_month)
end

##

using KernelDensity
using Interpolations
using Plots, StatsPlots

x1 = Vector(by_month[1].from_longitude)
y1 = Vector(by_month[1].from_latitude)
x2 = Vector(by_month[1].to_longitude)
y2 = Vector(by_month[1].to_latitude)

x1 = sort(rand(disallowmissing(x1), 10000))
y1 = sort(rand(disallowmissing(y1), 10000))
x2 = sort(rand(disallowmissing(x2), 10000))
y2 = sort(rand(disallowmissing(y2), 10000))

k1 = kde((x1, y1))
ik1 = InterpKDE(k1)
k2 = kde((x2, y2))
ik2 = InterpKDE(k2)


z1 = pdf(ik1, x1, y1)
z2 = pdf(ik2, x2, y2)

h1 = heatmap(x1, y1, z1, c = :BuPu)
h2 = heatmap(x2, y2, z2, c = :BuPu)

plot(h1,h2)