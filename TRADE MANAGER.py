# Get signal from mt4
# Check exposure
# Check news (download historical data from forex factory and store in a sqlite db)
# check $EVZ (download historical data and store in a sqlite db)
# Send signal back
# Proceed to next candle
import zmq
import json
from time import sleep

context = zmq.Context()
socket = context.socket(zmq.REP)
socket.bind("tcp://*:5555")

pub = context.socket(zmq.PUB)
pub.bind("tcp://*:6666")

everyone_conected = False
json_msg = None
signals_dict = {}
max_clients = 2
counter = 0

print("Starting backward forward server")
print("Waiting for clients to connect...")

while True:
    while counter <= max_clients:
        if everyone_conected == False:
            message = socket.recv()
            json_msg = json.loads(message)

            if json_msg != None:
                counter = counter + 1
                socket.send(b"OK")
                print(json_msg["symbol"], "conncected")

                signals_dict[json_msg["symbol"]] = json_msg

                if counter >= max_clients:
                    print("Total of %i clients connected" % counter)
                    print("Starting backtest:")
                    everyone_conected = True
                    break
        else:
            break

    if everyone_conected:
        print("Got signals via REP socket")
        print(signals_dict)

        print("Sending response via PUB socket")
        for i in signals_dict:
            if signals_dict[i]["signal"] == "FLAT":
                topic = signals_dict[i]["symbol"]
                message_data = "FLAT"
                print("%s %s" % (topic, message_data))
                sleep(1)
                pub.send_string("%s %s" % (topic, message_data))

            elif signals_dict[i]["signal"] == "SHORT":
                topic = signals_dict[i]["symbol"]
                message_data = "SHORT"
                print("%s %s" % (topic, message_data))
                pub.send_string("%s %s" % (topic, message_data))

            elif signals_dict[i]["signal"] == "LONG":
                topic = signals_dict[i]["symbol"]
                message_data = "LONG"
                print("%s %s" % (topic, message_data))
                pub.send_string("%s %s" % (topic, message_data))
            else:
                print("send meh")

        print("second", signals_dict)

        ctr = 0
        while ctr <= max_clients:
            message = socket.recv()
            json_msg = json.loads(message)

            if json_msg != None:
                ctr = ctr + 1
                socket.send(b"OK")

                # signals_dict[json_msg["symbol"]] = json_msg
                signals_dict.update({json_msg["symbol"]: json_msg})

                print("third", signals_dict)

                if ctr >= max_clients:
                    break
