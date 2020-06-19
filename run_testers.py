import subprocess


forex_pairs = ["AUDCAD", "AUDCHF", "AUDJPY", "AUDNZD", "AUDUSD", "CADCHF", "CADJPY", "CHFJPY", "EURCHF", "EURAUD", "EURCAD", "EURGBP", "EURJPY", "EURNZD", "EURUSD",
               "GBPAUD", "GBPCAD", "GBPCHF", "GBPJPY", "GBPNZD", "GBPUSD", "NZDCHF", "NZDCAD", "NZDJPY", "NZDUSD", "USDCAD", "USDCHF", "USDJPY"]

benchmark_fx_pairs = ['EURUSD', 'AUDNZD', 'EURGBP', 'AUDCAD', 'CHFJPY']

# for pair in benchmark_fx_pairs:
#     subprocess.Popen(
#         [f"C:\\Users\\Shaniel Samadhan\\Desktop\\NNFX FORWARD BACKTESTER\\testers\\{pair}\\terminal.exe", 'skipupdate', '/portable'])
#     print(f'Opened {pair}')


# command = "cmd /C " & Chr(34) & Chr(34) & terminal_path & Chr(34) & " " & Chr(34) & data_dir_path & "tester\" & ini_file & ".ini" & Chr(34) & " / skipupdate" & Chr(34)
# cmd /C ""C:\Program Files (x86)\MetaTrader 4 IC Markets\terminal.exe"
# "C:\Users\Shaniel Samadhan\AppData\Roaming\MetaQuotes\Terminal\1DAFD9A7C67DC84FE37EAA1FC1E5CF75\tester\VPU Algo EURUSD 2017-2021.ini" /skipupdate"

def replace_in_file(file_path, str_search, str_replace):
    # read input file
    fin = open(file_path, "rt")
    # read file contents to string
    data = fin.read()
    # replace all occurrences of the required string
    data = data.replace(str_search, str_replace)
    # close the input file
    fin.close()
    # open the input file in write mode
    fin = open(file_path, "wt")
    # overrite the input file with the resulting data
    fin.write(data)
    # close the file
    fin.close()


# Try to start all testers with their apropriate .ini files with the correct symbol and dates
replace_in_file('portable mt4/nnfx_forward_backtester.ini',
                '<EXPERT>', 'meow')

replace_in_file('portable mt4/nnfx_forward_backtester.ini',
                '<SYMBOL>', 'EURUSD')
