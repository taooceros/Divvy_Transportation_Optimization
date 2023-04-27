##
using Pkg
Pkg.add("Tidier")
Pkg.add("DataFrames")
Pkg.add("CSV")

##
using DataFrames, CSV
using Tidier
using Dates

##

# Read in the data

df = CSV.read("Divvy_Bicycle_Stations.csv", DataFrame)

##

@chain df begin
    @summarise(total_docks = sum(DocksInService))
end

##

# Read trip data

df = CSV.read("Divvy_Trips.csv", DataFrame)

##

rename!(df, [Symbol("START TIME"), Symbol("STOP TIME")] .=> [:start_time, :stop_time])
rename!(df, [Symbol("FROM STATION ID"), Symbol("TO STATION ID")] .=> [:from_station_id, :to_station_id])
rename!(df, [Symbol("BIKE ID")] .=> [:bike_id])

##

myFormat = Dates.DateFormat("mm/dd/yyyy HH:MM:SS p")
df.start_time = Dates.DateTime.(df.start_time, myFormat)
df.stop_time = Dates.DateTime.(df.stop_time, myFormat)


##

latest = filter(:start_time => >=(Dates.DateTime(2019, 1, 1)), df)

##

# group by bike id and find the average trip length
@chain latest begin
    @group_by(bike_id)
    @mutate(trip_length = Dates.value(stop_time - start_time) / 1000 / 60)
    @summarise(total_trips = n(), avg_trip_length = mean(trip_length), median_trip_length = median(trip_length), long_trip = mean(trip_length .> 30))
end

# group by from_station_id and find the average trip length
@chain latest begin
    @group_by(from_station_id)
    @mutate(trip_length = Dates.value(stop_time - start_time) / 1000 / 60)
    @summarise(total_trips = n(), avg_trip_length = mean(trip_length), median_trip_length = median(trip_length), long_trip = mean(trip_length .> 30))
end


# check cycle trips
@chain latest begin
    @mutate(circle_trip = from_station_id .== to_station_id)
    @group_by(circle_trip)
    @mutate(trip_length = Dates.value(stop_time - start_time) / 1000 / 60)
    @summarise(total_trips = n(), avg_trip_length = mean(trip_length), median_trip_length = median(trip_length), long_trip = mean(trip_length .> 30))
end

##

@chain latest begin
    transform([:start_time, :stop_time] => ((x, y) -> Dates.value.(y - x) / 1000 / 60)  => :duration)
    groupby(:from_station_id)
    combine(:duration => mean => :avg_duration)
end