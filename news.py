import sqlite3
from sqlite3 import Error
import csv
from datetime import datetime
from datetime import timedelta


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


def check_for_news(date, high_impact_only=False):
    """ Check if there is news in the next 24 hours
    :param date: current date
    :param high_impact_only: filter only news with high impact
    :return: to trade or not to trade boolean
    """

    current_date = datetime.strptime(date, '%Y.%m.%d %H:%M:%S')


if __name__ == '__main__':
    con = create_connection(r"db\news.db")
    # cur = con.cursor()
    # # use your column names here
    # cur.execute("""CREATE TABLE news (
    #     id integer PRIMARY KEY,
    #     date text,
    #     currency text,
    #     impact text,
    #     description text,
    #     actual text,
    #     forecast text,
    #     previous text,
    #     revisedFrom text,
    #     eventId text
    #     );""")

    # with open('news.csv', 'r') as fin:  # `with` statement available in 2.5+
    #     # csv.DictReader uses first line in file for column headings by default
    #     dr = csv.DictReader(fin)  # comma is default delimiter
    #     to_db = [(i['date'], i['currency'], i['impact'], i['description'], i['actual'],
    #               i['forecast'], i['previous'], i['revisedFrom'], i['eventId']) for i in dr]

    # cur.executemany(
    #     "INSERT INTO news (date, currency, impact, description, actual, forecast, previous, revisedFrom, eventId) VALUES (?, ?,?,?,?,?,?,?,?);", to_db)

    # con.commit()
    # con.close()
