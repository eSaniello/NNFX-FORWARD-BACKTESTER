import zmq
import time
import sys
import msvcrt
import json
import datetime
import csv
from news import check_for_news
from evz import check_evz
from copy_indi_and_ea import copy_files_to_testers
from run_testers import run_testers
from stats import decodeHistory
from stats import decodeStats
from stats import calculateStats

# https://docs.mql4.com/trading/orderselect

print("STARTING BACKWARD FORWARD SERVER\n")
# SETTINGS
evz_treshold = 3
news_avoidance = True
expert_name = 'NNFX FORWARD BACKTESTER'
settings_setfile = 'nnfx_forward_backtester'
timeframe = 'D1'  # M1, M5, M15, M30, H1, H4, D1, W1, MN
start_date = '2017.01.01'
end_date = '2020.04.01'
spread = '5'  # 0 = use current spread

forex_pairs = ["AUDCAD", "AUDCHF", "AUDJPY", "AUDNZD", "AUDUSD", "CADCHF", "CADJPY", "CHFJPY", "EURCHF", "EURAUD", "EURCAD", "EURGBP", "EURJPY", "EURNZD", "EURUSD",
               "GBPAUD", "GBPCAD", "GBPCHF", "GBPJPY", "GBPNZD", "GBPUSD", "NZDCHF", "NZDCAD", "NZDJPY", "NZDUSD", "USDCAD", "USDCHF", "USDJPY"]

_forex_pairs = ["AUDCAD", "AUDCHF", "AUDJPY", "AUDNZD", "AUDUSD", "CADCHF", "CADJPY", "CHFJPY", "EURCHF", "EURAUD", "EURCAD", "EURGBP", "EURJPY", "EURNZD", "EURUSD",
                "GBPAUD", "GBPCAD", "GBPCHF", "GBPJPY", "GBPNZD", "GBPUSD", "NZDJPY", "NZDUSD", "USDCAD", "USDCHF", "USDJPY"]

benchmark_fx_pairs = ['EURUSD', 'AUDNZD', 'EURGBP', 'AUDCAD', 'CHFJPY']

dummy_pairs = ['NZDCHF', 'NZDCAD']

pairs_to_use = _forex_pairs

max_clients = len(pairs_to_use)

# copy all the files to the testers first
print('Copying all the necesarry files to all the testers...')
copy_files_to_testers(forex_pairs)

# run all the testers
print('\nStarting all clients...')
run_testers(pairs=pairs_to_use, _expert_name=expert_name, _settings_setfile=settings_setfile,
            _timeframe=timeframe, _spread=spread, _start_date=start_date, _end_date=end_date)

context = zmq.Context()
socket = context.socket(zmq.REP)
pub = context.socket(zmq.PUB)

socket.bind("tcp://127.0.0.1:5555")
pub.bind("tcp://127.0.0.1:6666")


def kbfunc():
    x = msvcrt.kbhit()
    # print(msvcrt.getch())
    # print(ord(msvcrt.getch()))

    if x:
        ret = ord(msvcrt.getch())
    else:
        ret = -1

    if ret == 26:  # Check for ctrlZ
        sys.exit()

    return ret


def checkEqual1(iterator):
    iterator = iter(iterator)
    try:
        first = next(iterator)
    except StopIteration:
        return True
    return all(first == rest for rest in iterator)


def decodeSignal(signal):
    json_msg = json.loads(signal)
    trade1 = int(json_msg['trade1'])
    trade2 = int(json_msg['trade2'])
    _signal = int(json_msg['signal'])
    open_orders = int(json_msg['open_orders'])
    finished = True if json_msg['finished'] == 'true' else False

    json_msg['trade1'] = trade1
    json_msg['trade2'] = trade2
    json_msg['signal'] = _signal
    json_msg['open_orders'] = open_orders
    json_msg['finished'] = finished

    return json_msg


print("\nWaiting for clients to connect...")
signals = {}
clients = 0
history = []
stats = {}
dates = {}
balance = []
equity = []
while True:
    try:
        signal = socket.recv_string(zmq.NOBLOCK)

        signal = decodeSignal(signal)

        if signal['symbol'] not in signals:
            clients += 1
            print(signal['symbol'] + " Connected")
            signals[signal['symbol']] = signal

        # Ok we have decoded the signal, tell the client we are done for now
        socket.send_string("OK")

# #################################################################################
        # for symbol in signals:
        #     current_date = datetime.datetime.strptime(
        #         signals[symbol]['date'], '%Y.%m.%d %H:%M:%S')

        #     dates[symbol] = current_date

        # if len(dates) > 0:
        #     result = checkEqual1(dates)
        # if result == False:
        #     now = datetime.datetime.now()
        #     youngest = max(dt for dt in dates.values() if dt < now)

        #     print('Testers not in sync')
        #     # go to next candle
        #     for symbol in signals:
        #         _date = datetime.datetime.strptime(
        #             signals[symbol]['date'], '%Y.%m.%d %H:%M:%S')

        #         if _date != youngest:
        #             signals[symbol]['instruction'] = 'NEXT'
        #             pub.send_string(
        #                 f"{symbol} {signals[symbol]['instruction']}")
# #############################################################################################

        # TODO: remove this for proper testing
        # break out of loop once we have more than 1 client for testing purposes
        if clients >= max_clients:
            break

    except zmq.error.Again:
        time.sleep(.001)

        if kbfunc() != -1:  # poll keyboard for ctrl-z to exit (or move on to testing)
            break

print("Total of", len(signals), "clients connected")
print()
print("Starting backtest:")


while True:
    # loop through signals array, checking signals, for now add instruction key to each (next, trade, news) that just tells them to trade if signal and next if none

    # sum up exposure of existing trades
    #
    # exposure['USD'][S] = trade1 + trade2
    #
    # then to check exposure, check if current exposure + 2 <= 2...
    #
    # trade 1 and 2 are just from OrderType call in mt4, so -1 none, 1 SHORT, 0 LONG
    #
    # long means long on first cur, short on second
    exposure = {}

    for symbol, signal in signals.items():
        for trade in ['trade1', 'trade2']:
            base = symbol[0:3]
            quote = symbol[3:6]

            if base not in exposure:
                exposure[base] = {}
                exposure[base]['LONG'] = 0
                exposure[base]['SHORT'] = 0

            if quote not in exposure:
                exposure[quote] = {}
                exposure[quote]['LONG'] = 0
                exposure[quote]['SHORT'] = 0

            if int(signal[trade]) != -1:
                if int(signal[trade] == 0):  # LONG
                    exposure[base]['LONG'] += 1  # Base currency
                    exposure[quote]['SHORT'] += 1  # Quote currency
                elif int(signal[trade]) == 1:  # SHORT
                    exposure[base]['SHORT'] += 1  # Base currency
                    exposure[quote]['LONG'] += 1  # Quote currency

    # ok now we have our exposure, as we take trades we need to check exposure

    # define FLAT 0
    # define LONG 1
    # define SHORT 2

    # this will just be a race to whos first, need to sort signals buy an order at some stage

    # NEWS
    # If there is then don't trade
    # If in a losing trade then exit
    # if the first trade hit tp then do nothing

    evz = False
    evz_msg = True
    for symbol in signals:
        trade = False
        _long = False
        _short = False
        news = False
        close_trades = False

        # check if we have enough exposure free
        base = symbol[0:3]
        quote = symbol[3:6]

        # check $EVZ value and if it's above the treshold
        if not evz:
            evz_val = check_evz(signals[symbol]['date'])
            if evz_val == 0 or evz_val >= evz_treshold:
                evz = True
                print(f'$EVZ value: {evz_val}')
            else:
                if evz_msg:
                    evz_msg = False
                    print(f'$EVZ too low: {evz_val}')

        # check for upcomming news events
        if news_avoidance:
            news = check_for_news(
                24, signals[symbol]['date'], symbol, base, quote, False)

            if news == True:
                if signals[symbol]['trade1'] == -1 and signals[symbol]['trade1'] != -1:
                    close_trades = False
                else:
                    close_trades = True

        if int(signals[symbol]['signal']) > 0:
            if not close_trades:
                if evz:
                    if int(signals[symbol]['signal']) == 1:  # LONG
                        if exposure[base]['LONG'] == 0 and exposure[quote]['SHORT'] == 0:
                            # take the trade and set it to full exposure
                            trade = True
                            _long = True
                            _short = False
                            exposure[base]['LONG'] = 2
                            exposure[quote]['SHORT'] = 2
                    elif int(signals[symbol]['signal']) == 2:  # SHORT
                        if exposure[base]['SHORT'] == 0 and quote in exposure and exposure[quote]['LONG'] == 0:
                            # take the trade and set it to full exposure
                            trade = True
                            _long = False
                            _short = True
                            exposure[base]['SHORT'] = 2
                            exposure[quote]['LONG'] = 2

                if not trade:
                    print(f" **** CURRENCY EXPOSURE ON {symbol} *** ")

        if trade:
            if _long:
                signals[symbol]['instruction'] = 'LONG'
            elif _short:
                signals[symbol]['instruction'] = 'SHORT'
        elif close_trades:
            signals[symbol]['instruction'] = 'NEWS_CLOSE'
        else:
            signals[symbol]['instruction'] = 'NEXT'

    # Calculate total balance and equity
    bal = 0
    eq = 0
    for symbol, signal in signals.items():
        eq += float(signal['equity'])
        bal += float(signal['balance'])

    balance.append(bal)
    equity.append(eq)
    print(f'Equity (%): {round(eq, 2)}%')
    print(f'Balance (%): {round(bal, 2)}%')

    print("Sending instructions via PUB socket")

    # send all the instructions to testers
    for symbol in signals:
        pub.send_string(f"{symbol} {signals[symbol]['instruction']}")

    # OK Instructions set, waiting for next candle information
    signals = {}

    while True:
        try:
            signal = socket.recv_string(zmq.NOBLOCK)
            signal = decodeSignal(signal)

            if signal['symbol'] not in signals:

                signals[signal['symbol']] = signal

            # Ok we have decoded the signal, tell the client we are done for now
            socket.send_string("OK")

    # #################################################################################
            # for symbol in signals:
            #     current_date = datetime.datetime.strptime(
            #         signals[symbol]['date'], '%Y.%m.%d %H:%M:%S')

            #     dates[symbol] = current_date

            # if len(dates) > 0:
            #     result = checkEqual1(dates)
            # if result == False:
            #     now = datetime.datetime.now()
            #     youngest = max(dt for dt in dates.values() if dt < now)

            #     print('Testers not in sync')
            #     # go to next candle
            #     for symbol in signals:
            #         _date = datetime.datetime.strptime(
            #             signals[symbol]['date'], '%Y.%m.%d %H:%M:%S')

            #         if _date != youngest:
            #             signals[symbol]['instruction'] = 'NEXT'
            #             pub.send_string(
            #                 f"{symbol} {signals[symbol]['instruction']}")
    # #############################################################################################

            # Put all trades in an array
            if(signals[signal['symbol']]['order1'] != 0):
                if(signals[signal['symbol']]['order1'] not in history):
                    trade = decodeHistory(signals[signal['symbol']]['order1'])
                    history.append(trade)

            if(signals[signal['symbol']]['order2'] != 0):
                if(signals[signal['symbol']]['order2'] not in history):
                    trade = decodeHistory(signals[signal['symbol']]['order2'])
                    history.append(trade)

            # put all the stats in an array
            if(signals[signal['symbol']]['stats'] != 0):
                if(signal['symbol'] not in stats):
                    stat = decodeStats(signals[signal['symbol']]['stats'])
                    stats[signal['symbol']] = stat

            # break out of loop once we have signals from every client
            if len(signals) == clients:
                print("Recieved all signals via REP socket")

                for symbol in signals:
                    print(
                        f"{symbol}: date: {signals[symbol]['date']}, trade1: {signals[symbol]['trade1']}, trade2: {signals[symbol]['trade2']}, open_orders: {signals[symbol]['open_orders']}, signal: {signals[symbol]['signal']}, balance: {signals[symbol]['balance']}, equity: {signals[symbol]['equity']}")

                break

        except zmq.error.Again:
            time.sleep(.001)

    counter = 0
    for symbol in signals:
        if signals[symbol]['finished'] == True:
            counter += 1

        if counter >= clients:
            # DEINIT
            print('\nFINISHED\n')
            calculateStats(stats, history, pairs_to_use,
                           start_date, end_date, balance, equity)
            exit()
