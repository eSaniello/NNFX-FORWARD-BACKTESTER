import zmq
import time
import sys
import msvcrt
import json
from news import check_for_news
import datetime

context = zmq.Context()

print("Starting Backward Forward Server")
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
    # atr = int(json_msg['atr'])
    trade1 = int(json_msg['trade1'])
    trade2 = int(json_msg['trade2'])
    _signal = int(json_msg['signal'])
    open_orders = int(json_msg['open_orders'])

    # json_msg['atr'] = atr
    json_msg['trade1'] = trade1
    json_msg['trade2'] = trade2
    json_msg['signal'] = _signal
    json_msg['open_orders'] = open_orders

    return json_msg


print("Waiting for clients to connect...")

signals = {}
clients = 0
max_clients = 5

# TODO: Make sure all testers are on same date!
dates = {}

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

print("Total of", len(signals), "clients connected...")
print()
print("Starting backtest:")


while True:
    # loop through signals array, checking signals, for now add instruction key to each (next, trade, news) that just tells them to trade if signal and next if none

    # sum up exposure of existing trades
    #
    # exposure['USD'][S] = trade1 + trade2
    #
    # then to check exposure, check if current exposure + 2 <= 2...
    # need to change EA to send direction of trade (maybe just put long/flat/short in trade1 and trade2 for now then change to risk percent later
    #
    # trade 1 and 2 are just from OrderType call in mt4, so -1 none, 1 SHORT, 0 LONG
    #
    # long means long on first cur, short on second
    exposure = {}

    # TODO: change this to use 2 varliables, shortExposure and longExposure dont really need anything this fancy
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

    # TODO: NEWS
    # If there is then don't trade
    # If in a losing trade then exit
    # if the first trade hit tp then do nothing

    for symbol in signals:
        trade = False
        _long = False
        _short = False
        news = False
        close_trades = False

        # check if we have enough exposure free
        base = symbol[0:3]
        quote = symbol[3:6]

        # check for upcomming news events
        news = check_for_news(
            24, signals[symbol]['date'], symbol, base, quote, False)

        if news == True:
            if signals[symbol]['trade1'] == -1 and signals[symbol]['trade1'] != -1:
                close_trades = False
            else:
                close_trades = True

        if int(signals[symbol]['signal']) > 0:
            if not close_trades:
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

    print("Sending instructions via PUB socket")

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

            # break out of loop once we have signals from every client
            if len(signals) == clients:
                print("Recieved all signals via REP socket")
                print(signals)
                break

        except zmq.error.Again:
            time.sleep(.001)

print(signals)
