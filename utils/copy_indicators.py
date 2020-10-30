import shutil

forex_pairs = ["AUDCAD", "AUDCHF", "AUDJPY", "AUDNZD", "AUDUSD", "CADCHF", "CADJPY", "CHFJPY", "EURCHF", "EURAUD", "EURCAD", "EURGBP", "EURJPY", "EURNZD", "EURUSD",
               "GBPAUD", "GBPCAD", "GBPCHF", "GBPJPY", "GBPNZD", "GBPUSD", "NZDCHF", "NZDCAD", "NZDJPY", "NZDUSD", "USDCAD", "USDCHF", "USDJPY"]

for pair in forex_pairs:
    shutil.rmtree(
        f'testers/{pair}/MQL4/indicators/')

    shutil.copytree('portable mt4/MQL4/indicators',
                    f'testers/{pair}/MQL4/indicators')
    print(f'Copied {pair}')
