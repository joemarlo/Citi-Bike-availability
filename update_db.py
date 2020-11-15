import pandas as pd
import numpy as np
import os
import datetime as dt
os.chdir('/home/joemarlo/Dropbox/Data/Projects/Citi-Bike-availability')
from creds_master import conn

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

# replace data on db
new_data.to_sql(name='last_12', con=conn, if_exists='replace', index=False)

# close connection to db
conn.close()
