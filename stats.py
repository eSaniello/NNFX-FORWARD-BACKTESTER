from datetime import datetime
from dateutil.relativedelta import relativedelta


# https://docs.mql4.com/constants/environment_state/statistics#enum_statistics

def calculateStats(stats, _trades, pairs, _start_date, _end_date):
    start_date = datetime.strptime(_start_date, '%Y.%m.%d')
    end_date = datetime.strptime(_end_date, '%Y.%m.%d')
    initial_balance = stats[pairs[0]]["STAT_INITIAL_DEPOSIT"]
    total_net_profit = 0
    end_balance = 0
    averag_winrate = 0
    total_gross_profit = 0
    total_gross_loss = 0
    profit_factor = 0
    annual_roi = 0
    total_return = 0
    total_rel_dd = 0
    total_max_dd = 0
    trades = []
    for i in range(len(_trades)):
        if _trades[i] not in _trades[i + 1:]:
            trades.append(_trades[i])

    print('=====STATS=====')
    print(f'Start date: {_start_date}')
    print(f'End date: {_end_date}')
    print(f'Initial balance: ${initial_balance}')

    for symbol in pairs:
        total_net_profit += stats[symbol]['STAT_PROFIT']
        averag_winrate += stats[symbol]['STAT_WINRATE']
        total_gross_profit += stats[symbol]['STAT_GROSS_PROFIT']
        total_gross_loss += stats[symbol]['STAT_GROSS_LOSS']
        total_max_dd += stats[symbol]['STAT_BALANCEDD_PERCENT']
        total_rel_dd += stats[symbol]['STAT_BALANCE_DDREL_PERCENT']

    end_balance = initial_balance + total_net_profit
    averag_winrate = averag_winrate / len(pairs)
    profit_factor = (total_gross_profit / (total_gross_loss * -1))
    date_diff = relativedelta(end_date, start_date)
    annual_roi = (total_net_profit / (date_diff.years) / initial_balance) * 100
    total_return = (total_net_profit / initial_balance) * 100
    total_max_dd = total_max_dd / len(pairs)
    total_rel_dd = total_rel_dd / len(pairs)
    print(f'Total net profit: ${round(total_net_profit, 2)}')
    print(f'End balance: ${round(end_balance, 2)}')
    print(f'Average winrate: {round(averag_winrate, 2)}%')
    print(f'Total gross profit: ${round(total_gross_profit, 2)}')
    print(f'Total gross loss: ${round(total_gross_loss, 2)}')
    print(f'Profit factor: {round(profit_factor, 2)}')
    print(
        f'Annual ROI (%): {round(annual_roi, 2) if date_diff.years > 0 else "-"}%')
    print(f'Total ROI (%): {round(total_return, 2)}%')
    print(f'Total trades: {len(trades)}')
    print(f'Max DD: {round(total_max_dd, 2)}%')
    print(f'Relative DD: {round(total_rel_dd, 2)}%')

    # for trade in trades:
    #     if trade['symbol'] == 'AUDNZD':
    #         print(trade)


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
    stats['STAT_WINRATE'] = float(stats['STAT_WINRATE'])
    stats['STAT_GROSS_PROFIT'] = float(stats['STAT_GROSS_PROFIT'])
    stats['STAT_GROSS_LOSS'] = float(stats['STAT_GROSS_LOSS'])
    stats['STAT_MAX_PROFITTRADE'] = float(stats['STAT_MAX_PROFITTRADE'])
    stats['STAT_MAX_LOSSTRADE'] = float(stats['STAT_MAX_LOSSTRADE'])
    stats['STAT_CONPROFITMAX'] = float(stats['STAT_CONPROFITMAX'])
    stats['STAT_CONPROFITMAX_TRADES'] = float(
        stats['STAT_CONPROFITMAX_TRADES'])
    stats['STAT_MAX_CONWINS'] = float(stats['STAT_MAX_CONWINS'])
    stats['STAT_MAX_CONPROFIT_TRADES'] = int(
        stats['STAT_MAX_CONPROFIT_TRADES'])
    stats['STAT_CONLOSSMAX'] = float(stats['STAT_CONLOSSMAX'])
    stats['STAT_CONLOSSMAX_TRADES'] = int(stats['STAT_CONLOSSMAX_TRADES'])
    stats['STAT_MAX_CONLOSSES'] = float(stats['STAT_MAX_CONLOSSES'])
    stats['STAT_MAX_CONLOSS_TRADES'] = int(stats['STAT_MAX_CONLOSS_TRADES'])
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
    stats['STAT_TRADES'] = int(stats['STAT_TRADES'])
    stats['STAT_PROFIT_TRADES'] = int(stats['STAT_PROFIT_TRADES'])
    stats['STAT_LOSS_TRADES'] = int(stats['STAT_LOSS_TRADES'])
    stats['STAT_SHORT_TRADES'] = int(stats['STAT_SHORT_TRADES'])
    stats['STAT_LONG_TRADES'] = int(stats['STAT_LONG_TRADES'])
    stats['STAT_PROFIT_SHORTTRADES'] = int(stats['STAT_PROFIT_SHORTTRADES'])
    stats['STAT_PROFIT_LONGTRADES'] = int(stats['STAT_PROFIT_LONGTRADES'])
    stats['STAT_PROFITTRADES_AVGCON'] = int(
        stats['STAT_PROFITTRADES_AVGCON'])
    stats['STAT_LOSSTRADES_AVGCON'] = int(stats['STAT_LOSSTRADES_AVGCON'])

    return stats
