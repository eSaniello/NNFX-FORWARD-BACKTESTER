import pandas as pd
import glob


# path = r'reports'  # use your path
# all_files = glob.glob(path + "/*.csv")

# li = []

# for filename in all_files:
#     df = pd.read_csv(filename, header=0)
#     li.append(df)

# history = pd.concat(li, axis=0, ignore_index=True)
# print(history.sum())

df = pd.read_csv('reports/EURUSD.csv', header=0)
print(df)
