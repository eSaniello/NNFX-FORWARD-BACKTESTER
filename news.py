import sqlite3
from sqlite3 import Error
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


def check_for_news(hours, date, symbol, base, quote, high_impact_only=False):
    """ Check if there is news in the next given hours
    :param hours: how many hours to avoid
    :param date: current date
    :param base: base currency
    :param quote: quote currency
    :param symbol: currency pair
    :param high_impact_only: filter only news with high impact
    :return: to trade or not to trade boolean
    """

    current_date = datetime.strptime(
        date, '%Y.%m.%d %H:%M:%S').strftime('%Y-%m-%d %H:%M:%S')
    next_day = datetime.strptime(
        current_date, '%Y-%m-%d %H:%M:%S') + timedelta(hours=hours)

    con = create_connection(r"db\news.db")
    cur = con.cursor()
    cur.execute("SELECT * FROM news where date >= ?and date <= ?",
                (current_date, next_day))
    rows = cur.fetchall()

    for row in rows:
        # check for news
        country = row[2]
        title = row[4]
        impact = row[3]
        news_date = row[1]

        # USD news to avoid
        if (base == 'USD' or quote == 'USD') and country.find('USD') > -1:
            # US Dollar News Events to Avoid:
            # 1) Non-Farm Payroll (NFP - 1st Friday of the month)
            # 2) FOMC Interest Rates
            # 3) Fed Chair (Currently Powell) Speaks
            # 4) Consumer Price Index (CPI)

            if (high_impact_only == True and impact.find('H') > -1) or (title.find('Non-Farm Employment') > -1 and title.find('ADP') == -1) or title.find('Federal Funds Rate') > -1 or title.find('Fed Chair') > -1 or title.find('CPI') > -1:
                print(f'{symbol} News time out: {title} - {news_date}')
                return True
        # AUD news to avoid
        elif (base == 'AUD' or quote == 'AUD') and country.find('AUD') > -1:
            # Australian Dollar News Events to Avoid:
            # 1) Interest Rates
            # 2) Unemployment Rates

            if (high_impact_only == True and impact.find('H') > -1) or title.find('RBA Rate') > -1 or title.find('Unemployment') > -1:
                print(f'{symbol} News time out: {title} - {news_date}')
                return True
        # CAD news to avoid
        elif (base == 'CAD' or quote == 'CAD') and country.find('CAD') > -1:
            # Canadian Dollar News Events to Avoid:
            # 1) Unemployement Rates (1st Friday of the month)
            # 2) Interest Rates
            # 3) Retail Sales
            # 4) Consumer Price Index (CPI)

            if (high_impact_only == True and impact.find('H') > -1) or title.find('Unemployment') > -1 or title.find('BOC Rate') > -1 or title.find('Retail Sales') > -1 or title.find('CPI') > -1:
                print(f'{symbol} News time out: {title} - {news_date}')
                return True
        # CHF news to avoid
        elif (base == 'CHF' or quote == 'CHF') and country.find('CHF') > -1:
            # Swiss Franc News Events to Avoid:
            # 1) Interest (Libor) Rates

            if (high_impact_only == True and impact.find('H') > -1) or title.find('Libor') > -1:
                print(f'{symbol} News time out: {title} - {news_date}')
                return True
        # EUR news to avoid
        elif (base == 'EUR' or quote == 'EUR') and country.find('EUR') > -1:
            # Euro News Events to Avoid:
            # 1) Interest Rates
            # 2) ECB President (Currently Draghi) speaks

            if (high_impact_only == True and impact.find('H') > -1) or title.find('Main Refinancing Rate') > -1 or title.find('Monetary Policy') > -1 or title.find('ECB President') > -1:
                print(f'{symbol} News time out: {title} - {news_date}')
                return True
        # GBP news to avoid
        elif (base == 'GBP' or quote == 'GBP') and country.find('GBP') > -1:
            # Great British Pound News Events to Avoid:
            # 1) Interest Rates (MPC Rate Vote)
            # 2) Gross Domestic Product (GDP)

            if (high_impact_only == True and impact.find('H') > -1) or title.find('Bank Rate Votes') > -1 or title.find('GDP') > -1:
                print(f'{symbol} News time out: {title} - {news_date}')
                return True
        # JPY news to avoid
        elif (base == 'JPY' or quote == 'JPY') and country.find('JPY') > -1:
            # Japanese Yen News Events to Avoid:
            # 1) Interest Rates

            if (high_impact_only == True and impact.find('H') > -1) or title.find('BOJ Policy Rate') > -1:
                print(f'{symbol} News time out: {title} - {news_date}')
                return True
        # NZD news to avoid
        elif (base == 'NZD' or quote == 'NZD') and country.find('NZD') > -1:
            # New Zealand Dollar News Events to Avoid:
            # 1) Interest Rates
            # 2) Unemployment Rates
            # 3) Gross Domestic Product (GDP)
            # 4) Global Dairy Trade (GDT)

            if (high_impact_only == True and impact.find('H') > -1) or title.find('RBNZ Rate') > -1 or title.find('Unemployment') > -1 or title.find('GDP') > -1 or title.find('GDT') > -1:
                print(f'{symbol} News time out: {title} - {news_date}')
                return True

    return False
    con.commit()
    con.close()


# if __name__ == '__main__':
#     check_for_news(24, '2020.06.15 23:59:59', 'EURUSD', 'EUR', 'USD', True)
