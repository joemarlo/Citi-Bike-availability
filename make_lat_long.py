import pandas as pd
import os

# set directory
os.chdir('/home/joemarlo/Dropbox/Data/Projects/Citi-Bike-availability')
from creds_master import conn

# read in latest json
station_details = pd.read_json("https://gbfs.citibikenyc.com/gbfs/en/station_information.json")

# make lat long table
lat_long_df = pd.DataFrame(station_details.loc['stations',:]['data'])[['station_id', 'lat', 'lon', 'name']]
lat_long_df = lat_long_df.rename(columns={"lon": "long"}).reset_index(drop=True)

# write table to db
lat_long_df.to_sql(name='lat_long', con=conn, if_exists='replace', index=False)

# close connection to db
conn.close()
