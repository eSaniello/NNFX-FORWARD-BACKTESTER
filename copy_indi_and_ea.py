import shutil
import os

forex_pairs = ["AUDCAD", "AUDCHF", "AUDJPY", "AUDNZD", "AUDUSD", "CADCHF", "CADJPY", "CHFJPY", "EURCHF", "EURAUD", "EURCAD", "EURGBP", "EURJPY", "EURNZD", "EURUSD",
               "GBPAUD", "GBPCAD", "GBPCHF", "GBPJPY", "GBPNZD", "GBPUSD", "NZDCHF", "NZDCAD", "NZDJPY", "NZDUSD", "USDCAD", "USDCHF", "USDJPY"]

for pair in forex_pairs:
    # remove the folders first
    shutil.rmtree(
        f'testers/{pair}/MQL4/Experts/_NNFX/NNFX FORWARD BACKTESTER/')

    # copy the folders
    shutil.copytree(
        'portable mt4/MQL4/Experts/_NNFX/NNFX FORWARD BACKTESTER/', f'testers/{pair}/MQL4/Experts/_NNFX/NNFX FORWARD BACKTESTER/')
    print(f'Copied Indicators and Experts folders to {pair}')

    # copy the nnfx_forward_backtester.ini file
    shutil.copy('portable mt4/nnfx_forward_backtester.ini',
                f'testers/{pair}/')
