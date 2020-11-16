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
old_data = pd.read_sql("SELECT * FROM last_12 WHERE is_pred = 0", con=conn)
old_data['datetime'] = old_data.datetime.dt.tz_localize('America/New_York')

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
new_data = new_data.loc[pd.to_datetime(new_data.datetime, utc=True).dt.tz_convert('America/New_York') >= (datetime - dt.timedelta(hours=12)),:].reset_index(drop=True)

# split data for predictions
data_for_preds = new_data.loc[pd.to_datetime(new_data.datetime, utc=True).dt.tz_convert('America/New_York') >= (datetime - dt.timedelta(hours=3)),:].reset_index(drop=True)

# create identifiers for month, day, hour
data_for_preds['month'] = pd.DatetimeIndex(data_for_preds['datetime']).month
data_for_preds['day'] = pd.DatetimeIndex(data_for_preds['datetime']).day
data_for_preds['hour'] = pd.DatetimeIndex(data_for_preds['datetime']).hour
data_for_preds['weekday'] = pd.DatetimeIndex(data_for_preds['datetime']).dayofweek.isin(range(0,6)) * 1

# add in zip code group
station_zip_mapping = pd.read_csv("Modeling/station_details.csv")[['station_id', 'zip_id']]
data_for_preds['station_id'] = data_for_preds['station_id'].astype('int64')
data_for_preds = data_for_preds.merge(station_zip_mapping, how='left', on='station_id')

# create new columns containing counts of bikes leaving for the past one hour and past three hours
tmp = data_for_preds
tmp['bikes_leaving'] = tmp[['station_id', 'num_docks_available']].groupby(by='station_id').diff()
tmp['bikes_leaving'] = np.maximum(0, tmp['bikes_leaving'])
tmp['bikes_arriving'] = tmp[['station_id', 'num_bikes_available']].groupby(by='station_id').diff()
tmp['bikes_arriving'] = np.maximum(0, tmp['bikes_arriving'])
tmp = tmp.set_index('datetime')
lag_one_hour = tmp.last('1H').groupby('station_id').sum().reset_index()[['station_id', 'bikes_leaving', 'bikes_arriving']]
lag_one_hour = lag_one_hour.rename(columns={"bikes_leaving": "lag_one_hour"})
lag_three_hour = tmp.last('3H').groupby('station_id').sum().reset_index()[['station_id', 'bikes_leaving', 'bikes_arriving']]
lag_three_hour = lag_three_hour.rename(columns={"bikes_leaving": "lag_three_hours"})

# combine back into one df with just obeservations for the latest datetime
data_for_preds = data_for_preds.loc[data_for_preds.datetime == datetime,:]\
    .merge(lag_one_hour, how='left', on='station_id')\
    .merge(lag_three_hour, how='left', on='station_id')

# set X matrices
X = data_for_preds[['zip_id', 'month', 'day', 'hour', 'weekday', 'lag_one_hour', 'lag_three_hours']]

# dummy code
X = pd.get_dummies(X, columns=['zip_id', 'month', 'day', 'hour'])

# make predictions
preds = xg_reg.predict(xgb.DMatrix(X)).round()

# add preds to dataframe
preds = pd.DataFrame(data={'station_id': data_for_preds.station_id,
                            'num_bikes_available': data_for_preds.num_bikes_available - preds,
                            'num_docks_available': data_for_preds.num_docks_available + preds,
                            'datetime': datetime + dt.timedelta(hours=1),
                            'is_pred': 1})

# append and writeout
new_data.append(preds).to_sql(name='last_12', con=conn, if_exists='replace', index=False)

# close connection to db
conn.close()
