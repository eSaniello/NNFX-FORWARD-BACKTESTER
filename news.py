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
    # # cur.execute("""CREATE TABLE news (
    # #     id integer PRIMARY KEY,
    # #     date text,
    # #     currency text,
    # #     impact text,
    # #     description text
    # #     );""")

    # # con.commit()
    # con.close()
