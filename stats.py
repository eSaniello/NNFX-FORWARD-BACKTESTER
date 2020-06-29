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

# df = pd.read_csv('reports/EURUSD.csv', header=0)
# print(df)

# https://docs.mql4.com/constants/environment_state/statistics#enum_statistics

def decodeHistory(_trade):
    trade = _trade
    ticket = int(trade['ticket'])
    balance = trade['balance']
    if balance.find('[tp]') > 0:
        balance = balance.replace('[tp]', '')
    elif balance.find('[sl]') > 0:
        balance = balance.replace('[sl]', '')
    balance = float(balance)
    profit = float(trade['profit'])
    _type = int(trade['type'])
    lots = float(trade['lots'])
    open_price = float(trade['open_price'])
    close_price = float(trade['close_price'])
    tp = float(trade['tp'])
    sl = float(trade['sl'])

    trade['ticket'] = ticket
    trade['balance'] = balance
    trade['profit'] = profit
    trade['type'] = _type
    trade['lots'] = lots
    trade['open_price'] = open_price
    trade['close_price'] = close_price
    trade['tp'] = tp
    trade['sl'] = sl

    return trade


def decodeStats(_stats):
    stats = _stats

    stats['STAT_INITIAL_DEPOSIT'] = float(stats['STAT_INITIAL_DEPOSIT'])
    stats['STAT_PROFIT'] = float(stats['STAT_PROFIT'])
    stats['STAT_GROSS_PROFIT'] = float(stats['STAT_GROSS_PROFIT'])
    stats['STAT_GROSS_LOSS'] = float(stats['STAT_GROSS_LOSS'])
    stats['STAT_MAX_PROFITTRADE'] = float(stats['STAT_MAX_PROFITTRADE'])
    stats['STAT_MAX_LOSSTRADE'] = float(stats['STAT_MAX_LOSSTRADE'])
    stats['STAT_CONPROFITMAX'] = float(stats['STAT_CONPROFITMAX'])
    stats['STAT_CONPROFITMAX_TRADES'] = float(
        stats['STAT_CONPROFITMAX_TRADES'])
    stats['STAT_MAX_CONWINS'] = float(stats['STAT_MAX_CONWINS'])
    stats['STAT_MAX_CONPROFIT_TRADES'] = float(
        stats['STAT_MAX_CONPROFIT_TRADES'])
    stats['STAT_CONLOSSMAX'] = float(stats['STAT_CONLOSSMAX'])
    stats['STAT_CONLOSSMAX_TRADES'] = float(stats['STAT_CONLOSSMAX_TRADES'])
    stats['STAT_MAX_CONLOSSES'] = float(stats['STAT_MAX_CONLOSSES'])
    stats['STAT_MAX_CONLOSS_TRADES'] = float(stats['STAT_MAX_CONLOSS_TRADES'])
    stats['STAT_BALANCEMIN'] = float(stats['STAT_BALANCEMIN'])
    stats['STAT_BALANCE_DD'] = float(stats['STAT_BALANCE_DD'])
    stats['STAT_BALANCEDD_PERCENT'] = float(stats['STAT_BALANCEDD_PERCENT'])
    stats['STAT_BALANCE_DDREL_PERCENT'] = float(
        stats['STAT_BALANCE_DDREL_PERCENT'])
    stats['STAT_BALANCE_DD_RELATIVE'] = float(
        stats['STAT_BALANCE_DD_RELATIVE'])
    stats['STAT_EQUITYMIN'] = float(stats['STAT_EQUITYMIN'])
    stats['STAT_EQUITY_DD'] = float(stats['STAT_EQUITY_DD'])
    stats['STAT_EQUITYDD_PERCENT'] = float(stats['STAT_EQUITYDD_PERCENT'])
    stats['STAT_EQUITY_DDREL_PERCENT'] = float(
        stats['STAT_EQUITY_DDREL_PERCENT'])
    stats['STAT_EQUITY_DD_RELATIVE'] = float(stats['STAT_EQUITY_DD_RELATIVE'])
    stats['STAT_EXPECTED_PAYOFF'] = float(stats['STAT_EXPECTED_PAYOFF'])
    stats['STAT_PROFIT_FACTOR'] = float(stats['STAT_PROFIT_FACTOR'])
    stats['STAT_MIN_MARGINLEVEL'] = float(stats['STAT_MIN_MARGINLEVEL'])
    stats['STAT_TRADES'] = float(stats['STAT_TRADES'])
    stats['STAT_PROFIT_TRADES'] = float(stats['STAT_PROFIT_TRADES'])
    stats['STAT_LOSS_TRADES'] = float(stats['STAT_LOSS_TRADES'])
    stats['STAT_SHORT_TRADES'] = float(stats['STAT_SHORT_TRADES'])
    stats['STAT_LONG_TRADES'] = float(stats['STAT_LONG_TRADES'])
    stats['STAT_PROFIT_SHORTTRADES'] = float(stats['STAT_PROFIT_SHORTTRADES'])
    stats['STAT_PROFIT_LONGTRADES'] = float(stats['STAT_PROFIT_LONGTRADES'])
    stats['STAT_PROFITTRADES_AVGCON'] = float(
        stats['STAT_PROFITTRADES_AVGCON'])
    stats['STAT_LOSSTRADES_AVGCON'] = float(stats['STAT_LOSSTRADES_AVGCON'])

    return stats
