import zmq
import time
import sys
import msvcrt
import json

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

# step 1 for tonight. get this looping and telling the algo to take any trades it gets a signal for
# read the first signals and build an array of all connected clients
# on each loop, go through each client and send a trade signal if trade is set to true
# array of python dictionrys?
# lsit of dictionarys i guess

# wait for first clients, loop indefinately until keypress
#
# do the first calculation for currency over exposure and send instructions
#
# then from then on, make sure we get signals from every client before moving forward
#

# testing MT4, maybe try to make 2 MT4 testers, that use windows file system links for expert directory - not sure how that will go for compiling and reseting the UI
# might have to close and open second mt4 every time compile?? hopefully it just reads from HDD

# Wait for clients
# On keypress go forward (make a fixed number of clients to 2 for testing, so once it has 2 clients it will automatically move forward as well

#
# do while
#
#   Calulate news/currency exposure
#
#   Send instructions
#
#   Wait for next candle information
#
# client only has basic trade, news and skip functionality will be enough to get the following working
# news system (database)
# currency exposure
#
# Get basic loop sorted and working
# test with multiple clients
# then basic currency exposure system dack - race style
# then database news system
# Collect signals from all clients and store in a list of Dictionarys
# maybe clicking stop on client - send message to python server to remove it from client list?


print("Waiting for clients to connect...")

signals = {}
clients = 0
max_clients = 2

while True:
    try:
        # messagge format: symbol:'AUDUSD',date:'2020-04-01',atr:'209.15',trade1:'0',trade2:'0',signal:'0'
        signal = socket.recv_string(zmq.NOBLOCK)

        # TODO: maybe some form of validation, if not valid send 'retry'
        signal = decodeSignal(signal)

        if signal['symbol'] not in signals:
            clients += 1
            print(signal['symbol'] + " Connected")
            signals[signal['symbol']] = signal

        # Ok we have decoded the signal, tell the client we are done for now
        socket.send_string("OK")

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

# TODO: would check here that all clients are on the same candle, otherwise syncronise them

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

    for symbol in signals:
        trade = False
        _long = False
        _short = False

        if int(signals[symbol]['signal']) > 0:
            # check if we have enough exposure free
            base = symbol[0:3]
            quote = symbol[3:6]

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
                print(" **** Currency over exposure on ", symbol)

        # if signals[symbol]['open_orders'] == 0:
        if trade:
            if _long:
                signals[symbol]['instruction'] = 'LONG'
            elif _short:
                signals[symbol]['instruction'] = 'SHORT'
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

            # break out of loop once we have signals from every client
            if len(signals) == clients:
                print("Recieved all signals via REP socket")
                print(signals)
                break

        except zmq.error.Again:
            time.sleep(.001)

print(signals)
