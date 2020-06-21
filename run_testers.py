import subprocess
import shlex


forex_pairs = ["AUDCAD", "AUDCHF", "AUDJPY", "AUDNZD", "AUDUSD", "CADCHF", "CADJPY", "CHFJPY", "EURCHF", "EURAUD", "EURCAD", "EURGBP", "EURJPY", "EURNZD", "EURUSD",
               "GBPAUD", "GBPCAD", "GBPCHF", "GBPJPY", "GBPNZD", "GBPUSD", "NZDCHF", "NZDCAD", "NZDJPY", "NZDUSD", "USDCAD", "USDCHF", "USDJPY"]

benchmark_fx_pairs = ['EURUSD', 'AUDNZD', 'EURGBP', 'AUDCAD', 'CHFJPY']

expert_name = 'NNFX FORWARD BACKTESTER'
settings_setfile = 'nnfx_forward_backtester'
timeframe = 'D1'
start_date = '2017.01.01'
end_date = '2020.01.01'


expert_token = "<EXPERT>"
file_token = "<FILE>"
symbol_token = "<SYMBOL>"
timeframe_token = "<TIMEFRAME>"
start_date_token = "<START_DATE>"
end_date_token = "<END_DATE>"


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


for pair in benchmark_fx_pairs:
    # change .ini file for every tester
    path_to_ini_file = f'testers/{pair}/nnfx_forward_backtester.ini'
    replace_in_file(path_to_ini_file, expert_token, expert_name)
    replace_in_file(path_to_ini_file, file_token, settings_setfile)
    replace_in_file(path_to_ini_file, symbol_token, pair)
    replace_in_file(path_to_ini_file, timeframe_token, timeframe)
    replace_in_file(path_to_ini_file, start_date_token, start_date)
    replace_in_file(path_to_ini_file, end_date_token, end_date)

    # open tester with .ini file to run strategy tester automatically with above specified settings
    path_to_tester = f"C:\\Users\\Shaniel Samadhan\\Desktop\\NNFX FORWARD BACKTESTER\\testers\\{pair}\\terminal.exe"
    absolute_path_to_ini_file = f"C:\\Users\\Shaniel Samadhan\\Desktop\\NNFX FORWARD BACKTESTER\\testers\\{pair}\\nnfx_forward_backtester.ini"
    command = f'"{path_to_tester}" "{absolute_path_to_ini_file}" /skipupdate /portable'
    print(command)
    subprocess.Popen(shlex.split(command))
    print(f'Opened {pair}')


# https://www.mql5.com/en/forum/127577
