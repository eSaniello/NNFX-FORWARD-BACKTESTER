import shutil
import os
import glob
import sys
from tqdm import tqdm


forex_pairs = ["AUDCAD", "AUDCHF", "AUDJPY", "AUDNZD", "AUDUSD", "CADCHF", "CADJPY", "CHFJPY", "EURCHF", "EURAUD", "EURCAD", "EURGBP", "EURJPY", "EURNZD", "EURUSD",
               "GBPAUD", "GBPCAD", "GBPCHF", "GBPJPY", "GBPNZD", "GBPUSD", "NZDCHF", "NZDCAD", "NZDJPY", "NZDUSD", "USDCAD", "USDCHF", "USDJPY"]


def copy_data(pairs):
    for pair in tqdm(pairs, file=sys.stdout, desc='Copying'):

        files = glob.glob(f'testers/{pair}/history/ICMarkets-Demo01/*')
        for f in files:
            os.remove(f)

        os.chdir(
            "C:\\Users\Shaniel Samadhan\\Desktop\\NNFX FORWARD BACKTESTER\\portable mt4\history\\ICMarkets-Demo01")
        for file in glob.glob("*.hst"):
            if file.find(pair) > -1:
                shutil.copy(f'C:\\Users\Shaniel Samadhan\\Desktop\\NNFX FORWARD BACKTESTER\\portable mt4\history\\ICMarkets-Demo01/{file}',
                            f'C:/Users/Shaniel Samadhan/Desktop/NNFX FORWARD BACKTESTER/testers/{pair}/history/ICMarkets-Demo01/')

        print(f'Copied data to {pair}')


copy_data(forex_pairs)
