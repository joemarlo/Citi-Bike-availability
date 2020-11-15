import pandas as pd
import numpy as np
import os
import gc
import sqlite3
import datetime as dt
from pandas.tseries.holiday import USFederalHolidayCalendar as calendar
import matplotlib.pyplot as plt
import seaborn as sns

os.chdir('/home/joemarlo/Dropbox/Data/Projects/NYC-data')

# connect to database and extract ...
conn = sqlite3.connect('NYC.db')
os.chdir('/home/joemarlo/Dropbox/Data/Projects/Citi-Bike-availability')

# bring all the 2019 citibike data into memory
master_df = pd.read_sql("SELECT Starttime, `Start.station.id` FROM `citibike.2019`;", con=conn)
master_df = master_df.rename(columns={"Starttime": "datetime", "Start.station.id": "station_id"})
conn.close()

# convert from seconds to datetime
master_df['datetime'] = pd.to_datetime(master_df['datetime'], unit='s')

# create identifiers for month, day, hour
master_df['month'] = pd.DatetimeIndex(master_df['datetime']).month
master_df['day'] = pd.DatetimeIndex(master_df['datetime']).day
master_df['hour'] = pd.DatetimeIndex(master_df['datetime']).hour
master_df['weekday'] = master_df['datetime'].dt.dayofweek.apply(lambda x: x in range(0, 6)) * 1

# create df of just the trip count by station, month, day, Hour
trip_counts = master_df.groupby(['station_id', 'month', 'day', 'hour', 'weekday']).size().reset_index(name='counts')

# create date columns
trip_counts['year'] = 2019
trip_counts['date'] = pd.to_datetime(trip_counts[['year', 'month', 'day']])
trip_counts = trip_counts[['date', 'hour', 'station_id', 'counts']]

# convert implicit NAs to explicit 0s
# ie. there should be a row for each combination of station, month, day, hour
trip_counts = trip_counts.set_index(['station_id', 'date', 'hour'])
mux = pd.MultiIndex.from_product(\
    [trip_counts.index.levels[0], trip_counts.index.levels[1], trip_counts.index.levels[2]],\
    names=['station_id', 'date', 'hour'])
trip_counts = trip_counts.reindex(mux, fill_value=0).reset_index()

# create datetime column by the hour
trip_counts['year'] = 2019
trip_counts['month'] = pd.DatetimeIndex(trip_counts['date']).month
trip_counts['day'] = pd.DatetimeIndex(trip_counts['date']).day
trip_counts['datetime'] = pd.to_datetime(trip_counts[['year', 'month', 'day', 'hour']])
del trip_counts['year']

### create column of lagged trip counts
# lag one hour
trip_counts = trip_counts.set_index('datetime', drop=False)
right_df = trip_counts[['datetime', 'station_id', 'counts']].shift(periods=1, freq='H')
right_df['datetime'] = right_df.index
right_df = right_df.rename(columns={"counts": "lag_one_hour"}).reset_index(drop=True)
trip_counts = trip_counts.reset_index(drop=True)
trip_counts = trip_counts.merge(right_df, how='left', on=['datetime', 'station_id'])

# lag three hours
trip_counts = trip_counts.set_index('datetime', drop=False)
right_df = trip_counts[['datetime', 'station_id', 'counts']].shift(periods=3, freq='H')
right_df['datetime'] = right_df.index
right_df = right_df.rename(columns={"counts": "lag_three_hours"}).reset_index(drop=True)
trip_counts = trip_counts.reset_index(drop=True)
trip_counts = trip_counts.merge(right_df, how='left', on=['datetime', 'station_id'])

# add weekday back
trip_counts['weekday'] = trip_counts['datetime'].dt.dayofweek.apply(lambda x: x in range(0, 6)) * 1
del trip_counts['datetime'], trip_counts['date']

# replace Nans

# add in zip code group
station_zip_mapping = pd.read_csv("Modeling/station_details.csv")[['station_id', 'zip_id']]
trip_counts =  trip_counts.merge(station_zip_mapping, how='left', on='station_id')
