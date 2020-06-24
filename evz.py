import sqlite3
from sqlite3 import Error
import csv
from datetime import datetime


def create_connection(db_file):
    """ create a database connection to the SQLite database
        specified by db_file
    :param db_file: database file
    :return: Connection object or None
    """
    conn = None
    try:
        conn = sqlite3.connect(db_file)
        return conn
    except Error as e:
        print(e)

    return conn


def check_evz(date):
    """ Get the $EVZ value for the given date
    :param date: current date
    :return: $EVZ value
    """

    current_date = datetime.strptime(
        date, '%Y.%m.%d %H:%M:%S').strftime('%Y-%m-%d')

    con = create_connection(r"db\forward_backtester.db")
    cur = con.cursor()
    cur.execute("SELECT close FROM evz where date == ?", (current_date,))
    rows = cur.fetchall()

    if len(rows) > 0:
        val = rows[0][0]
        return val
    else:
        return 0


# ADD CSV FILE TO SQLITE DB
# con = create_connection(r"db\forward_backtester.db")
# cur = con.cursor()
# cur.execute('''CREATE TABLE IF NOT EXISTS evz (
#     date TEXT PRIMARY KEY,
#     open REAL,
#     high REAL,
#     low REAL,
#     close REAL,
#     change REAL,
#     volume REAL
#     );''')

# with open(r'db/$evz_daily.csv', 'r') as fin:  # `with` statement available in 2.5+
#     # csv.DictReader uses first line in file for column headings by default
#     dr = csv.DictReader(fin)  # comma is default delimiter
#     to_db = [(i['date'], i['open'], i['high'], i['low'],
#               i['close'], i['change'], i['volume']) for i in dr]

# cur.executemany(
#     "INSERT INTO evz (date, open, high, low, close, change, volume) VALUES (?, ?, ?, ?, ?, ?, ?);", to_db)
# con.commit()
# con.close()

# CHANGE DATE FORMAT IN CSV FILE ROW
# with open(r'db/$evz_daily.csv', 'r') as source:
#     with open('output.csv', 'w') as result:
#         writer = csv.writer(result, lineterminator='\n')
#         reader = csv.reader(source)
#         source.readline()
#         for row in reader:
#             ts = row[0]
#             ts = datetime.strptime(
#                 ts, "%Y-%m-%d %H:%M:%S").strftime("%Y-%m-%d")
#             if ts != "":
#                 row[0] = ts
#                 writer.writerow(row)
# source.close()
# result.close()
