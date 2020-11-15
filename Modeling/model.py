import pandas as pd
import numpy as np
import os
import matplotlib.pyplot as plt
import seaborn as sns
import xgboost as xgb

from sklearn.ensemble import RandomForestRegressor
from sklearn.model_selection import train_test_split
from sklearn import preprocessing
from sklearn.preprocessing import OneHotEncoder
from sklearn.metrics import mean_squared_error as MSE
from yellowbrick.regressor import ResidualsPlot


os.chdir('/home/joemarlo/Dropbox/Data/Projects/Citi-Bike-availability')

# set X and y matrices
X = trip_counts[['zip_id', 'month', 'day', 'hour', 'weekday', 'lag_one_hour', 'lag_three_hours']]
y = trip_counts.counts

# dummy code Year and Month
X = pd.get_dummies(X, columns=['zip_id', 'month', 'day', 'hour'])

# split the data
X_train, X_test, y_train, y_test = train_test_split(X, y, test_size=0.5, random_state=44)


##### xgboost
# Instantiate the XGBRegressor
xg_reg = xgb.XGBRegressor(objective='count:poisson', seed=44, n_jobs=-1, nthread=-1, \
                          n_estimators=30, max_depth=5, learning_rate=0.7)

# Fit the regressor to the training set
xg_reg.fit(X_train, y_train)

# Predict the labels of the test set: preds
preds = xg_reg.predict(X_test)

# Compute the rmse
MSE(y_test, preds)**(1/2)

# boxplot of residuals
ax = sns.boxplot(x=preds-y_test)
ax.set(xlabel='Difference b/t actual and prediction')
plt.show()

## Cross validate
# Create the DMatrix
dmatrix = xgb.DMatrix(data=X_train, label=y_train)

# Create the parameter dictionary: params
params = {"objective":"reg:poisson", "max_depth":6}

# Perform cross-validation: cv_results
cv_results = xgb.cv(dtrain=dmatrix, params=params, nfold=4, num_boost_round=5, metrics="rmse", as_pandas=True, seed=123)

# Print cv_results
print(cv_results)

# Create a pd.Series of features importances
importances = pd.Series(data=xg_reg.feature_importances_,
                        index= X_train.columns)

# Sort importances
importances_sorted = importances.sort_values()

# Draw a horizontal barplot of importances_sorted
importances_sorted.plot(kind='barh')
plt.title('Features Importances')
plt.gcf().set_size_inches(5, 15)
plt.show()

# save the model
xg_reg.save_model('Modeling/xgb_trip_starts_py.model')

# load model
#xg_reg = xgb.Booster({'nthread': 4})
#xg_reg.load_model('Modeling/xgb_trip_starts_py.model')
