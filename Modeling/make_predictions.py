import pandas as pd
import numpy as np
import os
import xgboost as xgb
import datetime as dt

# set directory
os.chdir('/home/joemarlo/Dropbox/Data/Projects/Citi-Bike-availability')
from creds_master import conn

# load model
xg_reg = xgb.Booster({'nthread': 4})
xg_reg.load_model('Modeling/xgb_trip_starts_py.model')

# read in the data
old_data = pd.read_sql("SELECT * FROM last_12;", con=conn)

# read in latest json
station_status = pd.read_json("https://gbfs.citibikenyc.com/gbfs/en/station_status.json")
datetime = pd.to_datetime(station_status['last_updated'], unit='s').dt.tz_localize('UTC').dt.tz_convert('America/New_York')[0]
station_status = pd.json_normalize(station_status['data']['stations'])

# only retain relavant columns
data_to_append = station_status[['station_id', 'num_bikes_available', 'num_docks_available']].drop_duplicates()
data_to_append['datetime'] = datetime
data_to_append['is_pred'] = 0

# combine data and delete observations > 12hours old
new_data = old_data.append(data_to_append).drop_duplicates()
new_data['is_pred'] = 0
new_data = new_data.loc[pd.to_datetime(new_data.datetime, utc=True).dt.tz_convert('America/New_York') >= (datetime - dt.timedelta(hours=12)),:]

# split data for predictions
data_for_preds = new_data.loc[pd.to_datetime(new_data.datetime, utc=True).dt.tz_convert('America/New_York') >= (datetime - dt.timedelta(hours=3)),:]

# create identifiers for month, day, hour
data_for_preds['month'] = pd.DatetimeIndex(data_for_preds['datetime']).month
data_for_preds['day'] = pd.DatetimeIndex(data_for_preds['datetime']).day
data_for_preds['hour'] = pd.DatetimeIndex(data_for_preds['datetime']).hour
data_for_preds['weekday'] = pd.DatetimeIndex(data_for_preds['datetime']).dayofweek.isin(range(0,6)) * 1

# add in zip code group
station_zip_mapping = pd.read_csv("Modeling/station_details.csv")[['station_id', 'zip_id']]
data_for_preds['station_id'] = data_for_preds['station_id'].astype('int64')
data_for_preds = data_for_preds.merge(station_zip_mapping, how='left', on='station_id')

# TODO
tmp = data_for_preds.set_index(['datetime', 'station_id'])
tmp['counts'] = tmp.groupby(level='station_id').shift(-1)

# add lagged data
# lag one hour
tmp = tmp.set_index('datetime', drop=False)
right_df = tmp[['datetime', 'station_id', 'counts']].shift(periods=1, freq='H')
right_df['datetime'] = right_df.index
right_df = right_df.rename(columns={"counts": "lag_one_hour"}).reset_index(drop=True)
trip_counts = trip_counts.reset_index(drop=True)
trip_counts = trip_counts.merge(right_df, how='left', on=['datetime', 'station_id'])

# dummy code
X = pd.get_dummies(X, columns=['zip_id', 'month', 'day', 'hour'])
