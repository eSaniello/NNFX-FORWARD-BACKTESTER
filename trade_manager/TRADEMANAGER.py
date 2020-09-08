import zmq
import time
import sys
import msvcrt
import json
from copy_indi_and_ea import _copy_files_to_testers
from run_testers import run_testers
from evz import check_evz
from news import check_for_news
from stats import decodeHistory
from stats import decodeStats
from stats import calculateStats


class TradeManager:
    # Initialize all parameters first
    def __init__(self, evz_treshold, news_avoidance, news_hours, filter_high_impact_news_only, expert_name, settings_setfile, timeframe, start_date, end_date, spread, pairs_to_use, optimisation):
        print("STARTING BACKWARD FORWARD SERVER\n")

        self.evz_treshold = evz_treshold
        self.news_avoidance = news_avoidance
        self.expert_name = expert_name
        self.settings_setfile = settings_setfile
        self.timeframe = timeframe
        self.start_date = start_date
        self.end_date = end_date
        self.spread = spread
        self.pairs_to_use = pairs_to_use
        self.news_hours = news_hours
        self.filter_high_impact_news_only = filter_high_impact_news_only
        self.optimisation = optimisation

    # Copy all the files to the testers
    def copy_files_to_testers(self):
        print('Copying all the necesarry files to all the testers...')
        _copy_files_to_testers(self.pairs_to_use)

    # Start all testers
    def start_testers(self):
        print('\nStarting all clients...')
        run_testers(self.pairs_to_use, self.expert_name, self.settings_setfile,
                    self.timeframe, self.spread, self.start_date, self.end_date)

    # start the server and begin trading
    def start_trade_manager(self):
        # initialize the sockets
        context = zmq.Context()
        socket = context.socket(zmq.REP)
        pub = context.socket(zmq.PUB)

        socket.bind("tcp://127.0.0.1:5555")
        pub.bind("tcp://127.0.0.1:6666")

        # create local variables
        print("\nWaiting for clients to connect...")
        signals = {}
        clients = 0
        history = []
        stats = {}
        balance = []
        equity = []
        signal_date = None
        max_clients = len(self.pairs_to_use)

        # function to decode the signal data and convert it into a json object
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

        # function to check for ctrl-z to quit in case of error
        def kbfunc():
            x = msvcrt.kbhit()
            if x:
                ret = ord(msvcrt.getch())
            else:
                ret = -1

            if ret == 26:  # Check for ctrlZ
                sys.exit()

            return ret

        # first loop to check if all testers are connected
        while True:
            try:
                signal = socket.recv_string(zmq.NOBLOCK)
                signal = decodeSignal(signal)

                # add signal to signals dict
                if signal['symbol'] not in signals:
                    clients += 1
                    print(signal['symbol'] + " Connected")
                    signals[signal['symbol']] = signal

                # sort the signals alphabetically to make sure results are not random
                signals = {
                    value['symbol']: value for value in sorted(
                        map(
                            lambda key: signals[key],
                            signals.keys()
                        ),
                        key=lambda signals: signals['symbol'],
                        reverse=False
                    )
                }

                # Ok we have decoded the signal, tell the client we are done for now
                socket.send_string("OK")

                # Loop through the signals and find the lowest signal date, check for missed candles
                signal_date = signals[next(iter(signals))]['date']

                # find the lowest date in the signal first
                missed = False
                for symbol, signal in signals.items():
                    # atleast 1 signal has incorrect date
                    if signal_date != signal['date']:
                        missed = True

                    # find the lowest date
                    if signal['date'] < signal_date:
                        signal_date = signal['date']

                # break out of loop once all the clients are connected
                if clients >= max_clients:
                    break

            except zmq.error.Again:
                time.sleep(.001)

                if kbfunc() != -1:  # poll keyboard for ctrl-z to exit (or move on to testing)
                    break

        print("Total of", len(signals), "clients connected")
        print()
        print("Starting backtest:")

        # second loop to trade all the signals
        while True:
            # loop through signals array, checking signals, add instruction key to each (next, trade, news_close, hold)
            # that just tells them to trade if signal and next if none

            # sum up exposure of existing trades
            # exposure['USD'][S] = trade1 + trade2
            # then to check exposure, check if current exposure + 2 <= 2...
            # trade 1 and 2 are just from OrderType call in mt4, so -1 none, 1 SHORT, 0 LONG
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

            # this will just be a race to who's first

            # NEWS
            # If there news is then don't trade
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
                    if evz_val == 0 or evz_val >= self.evz_treshold:
                        evz = True
                        print(f'$EVZ value: {evz_val}')
                    else:
                        if evz_msg:
                            evz_msg = False
                            print(f'$EVZ too low: {evz_val}')

                # check for upcoming news events
                if self.news_avoidance:
                    news = check_for_news(
                        self.news_hours, signals[symbol]['date'], symbol, base, quote, self.filter_high_impact_news_only)

                    if news == True:
                        # if first trade hit tp then do nothing. We are risk free
                        if signals[symbol]['trade1'] == -1 and signals[symbol]['trade2'] != -1:
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

                # set the instructions that will be sent to the EA
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
            print(f'Equity: {round(eq, 2)}%')
            print(f'Balance: {round(bal, 2)}%')

            print("Sending instructions via PUB socket")

            # send all the instructions to testers
            for symbol in signals:
                # if the dates aren't in sync then send a HOLD command
                # this will tell the EA to stay on the current candle and send the same signal again
                # untill all of the other testers have caught up
                if signals[symbol]['date'] != signal_date:
                    signals[symbol]['instruction'] = 'HOLD'

                # send instructions via broadcast socket
                pub.send_string(f"{symbol} {signals[symbol]['instruction']}")

            # OK Instructions sent, waiting for next candle information
            # empty the signals dict to recieve new ones
            signals = {}

            while True:
                try:
                    signal = socket.recv_string(zmq.NOBLOCK)
                    signal = decodeSignal(signal)

                    if signal['symbol'] not in signals:
                        signals[signal['symbol']] = signal

                    # sort the signals alphabetically to makie sure results are not random
                    signals = {
                        value['symbol']: value for value in sorted(
                            map(
                                lambda key: signals[key],
                                signals.keys()
                            ),
                            key=lambda signals: signals['symbol'],
                            reverse=False
                        )
                    }

                    # Ok we have decoded the signal, tell the client we are done for now
                    socket.send_string("OK")

                    # Put all trades in an array
                    if(signals[signal['symbol']]['order1'] != 0):
                        if(signals[signal['symbol']]['order1'] not in history):
                            trade = decodeHistory(
                                signals[signal['symbol']]['order1'])
                            history.append(trade)

                    if(signals[signal['symbol']]['order2'] != 0):
                        if(signals[signal['symbol']]['order2'] not in history):
                            trade = decodeHistory(
                                signals[signal['symbol']]['order2'])
                            history.append(trade)

                    # put all the stats in an array
                    if(signals[signal['symbol']]['stats'] != 0):
                        if(signal['symbol'] not in stats):
                            stat = decodeStats(
                                signals[signal['symbol']]['stats'])
                            stats[signal['symbol']] = stat

                    # Loop through the signals and find the lowest signal date, check for missed candles
                    signal_date = signals[next(iter(signals))]['date']

                    # find the lowest date in the signal first
                    missed = False
                    for symbol, signal in signals.items():
                        # atleast 1 signal has incorrect date
                        if signal_date != signal['date']:
                            missed = True

                        # find the lowest date
                        if signal['date'] < signal_date:
                            signal_date = signal['date']

                    # break out of loop once we have signals from every client
                    if len(signals) == clients:
                        print("Recieved all signals via REP socket")

                        for symbol in signals:
                            # print recieved signals to terminal
                            print(
                                f"{symbol}: date: {signals[symbol]['date']}, trade1: {signals[symbol]['trade1']}, trade2: {signals[symbol]['trade2']}, open_orders: {signals[symbol]['open_orders']}, signal: {signals[symbol]['signal']}, balance: {signals[symbol]['balance']}, equity: {signals[symbol]['equity']}")

                        break

                except zmq.error.Again:
                    time.sleep(.001)

            if self.optimisation == True:
                if signals[list(signals.keys())[0]]['finished'] == True:
                    # DEINIT
                    print('\nFINISHED\n')

                    # once done testing, calculate all the statistics
                    calculateStats(
                        stats, history, self.pairs_to_use,
                        self.start_date, self.end_date, balance, equity
                    )
                    break
            else:
                counter = 0
                for symbol in signals:
                    if signals[symbol]['finished'] == True:
                        counter += 1

                    if counter >= clients:
                        # DEINIT
                        print('\nFINISHED\n')

                        # once done testing, calculate all the statistics
                        calculateStats(
                            stats, history, self.pairs_to_use,
                            self.start_date, self.end_date, balance, equity
                        )
                        exit()
