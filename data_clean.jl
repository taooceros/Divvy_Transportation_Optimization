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
using DataFrames, CSV, DataFramesMeta
using Dates
using Statistics

##

# Read in the data

stations = CSV.read("../data/Divvy_Bicycle_Stations.csv", DataFrame)

##

@chain df begin
    @summarise(total_docks = sum(DocksInService))
end

##

# Read trip data

trips = CSV.read("Divvy_Trips.csv", DataFrame)


for col_name in names(trips)
    if occursin(" ", col_name)
        new_col_name = lowercase(replace(col_name, " " => "_"))
        @rename!(trips, $new_col_name = $col_name)
    end
end


time_format = dateformat"mm/dd/yyyy HH:MM:SS p"

@transform!(trips, :start_time = Dates.DateTime.(:start_time, time_format))
@transform!(trips, :stop_time = Dates.DateTime.(:stop_time, time_format))
@transform!(trips, :start_hour = Dates.hour.(:start_time))
@transform!(trips, :stop_hour = Dates.hour.(:stop_time))
@transform!(trips, :start_day_of_week = Dates.dayofweek.(:start_time))
@transform!(trips, :stop_day_of_week = Dates.dayofweek.(:stop_time))
@transform!(trips, :start_month = Dates.month.(:start_time))
@transform!(trips, :stop_month = Dates.month.(:stop_time))

##

@subset! trips :start_time .>= DateTime(2019, 1, 1)

##

@transform!(trips, :trip_length = Dates.value.(:stop_time - :start_time) / 1000 / 60)

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