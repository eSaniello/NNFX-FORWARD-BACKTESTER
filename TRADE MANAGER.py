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

while True:
    #  Wait for next request from client
    message = socket.recv()
    json_msg = json.loads(message)
    print(json_msg)

    # Check for data and send reply
    if json_msg["signal"] == "FLAT":
        socket.send(b"FLAT")

    if json_msg["signal"] == "SHORT" and json_msg["open_orders"] == "0":
        socket.send(b"SHORT")

    if json_msg["signal"] == "SHORT" and json_msg["open_orders"] != "0":
        socket.send(b"FLAT")

    if json_msg["signal"] == "LONG" and json_msg["open_orders"] == "0":
        socket.send(b"LONG")

    if json_msg["signal"] == "LONG" and json_msg["open_orders"] != "0":
        socket.send(b"FLAT")
