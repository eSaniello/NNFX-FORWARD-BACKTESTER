import subprocess
import shlex

forex_pairs = ["AUDCAD", "AUDCHF", "AUDJPY", "AUDNZD", "AUDUSD", "CADCHF", "CADJPY", "CHFJPY", "EURCHF", "EURAUD", "EURCAD", "EURGBP", "EURJPY", "EURNZD", "EURUSD",
               "GBPAUD", "GBPCAD", "GBPCHF", "GBPJPY", "GBPNZD", "GBPUSD", "NZDCHF", "NZDCAD", "NZDJPY", "NZDUSD", "USDCAD", "USDCHF", "USDJPY"]

benchmark_fx_pairs = ['EURUSD', 'AUDNZD', 'EURGBP', 'AUDCAD', 'CHFJPY']

dummy_pairs = ["AUDCAD", "AUDCHF", "AUDJPY", "AUDNZD", "AUDUSD",
               "CADCHF", "CADJPY", "CHFJPY", "EURCHF", "EURAUD", "USDCHF"]

pairs_to_use = forex_pairs


def open_testers(pairs):
    for pair in pairs:
        # open tester with .ini file to run strategy tester automatically with above specified settings
        path_to_tester = f"C:\\Users\\Shaniel Samadhan\\Desktop\\NNFX FORWARD BACKTESTER\\testers\\{pair}\\terminal.exe"
        command = f'"{path_to_tester}" /skipupdate /portable'

        subprocess.Popen(shlex.split(command))
        print(f'Started {pair}')


open_testers(pairs=pairs_to_use)
