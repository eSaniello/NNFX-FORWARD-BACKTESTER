# Get signal from mt4
# Check exposure
# Check news (download historical data from forex factory and store in a sqlite db)
# check $EVZ (download historical data and store in a sqlite db)
# Send signal back
# Proceed to next candle
import zmq
import json

context = zmq.Context()
socket = context.socket(zmq.REP)
socket.bind("tcp://*:5555")

pub = context.socket(zmq.PUB)
pub.bind("tcp://*:6666")

everyone_conected = False
json_msg = None

while True:
    counter = 0
    #  Wait for next request from client
    while True:
        message = socket.recv()
        json_msg = json.loads(message)
        print(json_msg)

        if json_msg != None:
            counter = counter + 1
            socket.send(b"OK")
            print(json_msg["symbol"], "conncected")

            if counter >= 1:
                print("everyone connected")
                break

    # if everyone_conected == False:
    #     message = socket.recv()
    #     json_msg = json.loads(message)
    #     print(json_msg)

    #     if json_msg != None:
    #         counter = counter + 1
    #         socket.send(b"OK")
    #         print(json_msg["symbol"], "conncected")

    #         if counter >= 1:
    #             print("everyone connected")
    #             everyone_conected = True

    # if everyone_conected == True:
        # Check for data and send reply

    # message = socket.recv()
    # json_msg = json.loads(message)
    # print(json_msg)

    if json_msg["signal"] == "FLAT":
        topic = json_msg["symbol"]
        message_data = "hi"
        pub.send_string("%s %s" % (topic, message_data))
        # socket.send(b"OK")
        # print('signal sent', "%s %s" % (topic, message_data))

        # if json_msg["signal"] == "SHORT" and json_msg["open_orders"] == "0":
        #     socket.send(b"SHORT")

        # if json_msg["signal"] == "SHORT" and json_msg["open_orders"] != "0":
        #     socket.send(b"FLAT")

        # if json_msg["signal"] == "LONG" and json_msg["open_orders"] == "0":
        #     socket.send(b"LONG")

        # if json_msg["signal"] == "LONG" and json_msg["open_orders"] != "0":
        #     socket.send(b"FLAT")
