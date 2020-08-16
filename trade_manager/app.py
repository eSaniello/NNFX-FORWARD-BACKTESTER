from TRADEMANAGER import TradeManager
from optimizations import replace_in_file, navigate_and_rename
import os
import shutil
from time import sleep


# SETTINGS
evz_treshold = 3
news_avoidance = True
expert_name = 'NNFX FORWARD BACKTESTER'
settings_setfile = 'nnfx_forward_backtester'
timeframe = 'D1'  # M1, M5, M15, M30, H1, H4, D1, W1, MN
start_date = '2018.01.01'
end_date = '2020.08.10'
spread = '5'  # 0 = use current spread
optimisation = True

forex_pairs = ["AUDCAD", "AUDCHF", "AUDJPY", "AUDNZD", "AUDUSD", "CADCHF", "CADJPY", "CHFJPY", "EURCHF", "EURAUD", "EURCAD", "EURGBP", "EURJPY", "EURNZD", "EURUSD",
               "GBPAUD", "GBPCAD", "GBPCHF", "GBPJPY", "GBPNZD", "GBPUSD", "NZDCHF", "NZDCAD", "NZDJPY", "NZDUSD", "USDCAD", "USDCHF", "USDJPY"]

benchmark_fx_pairs = ['EURUSD', 'AUDNZD', 'EURGBP', 'AUDCAD', 'CHFJPY']

dummy_pairs = ["AUDCAD"]


# For optimization
token = "<PERIOD>"
period_start = 5
period_step = 5
period_end = 30

i = period_start
while i <= period_end:
    print(i)

    # # change .set file for every tester
    dir_src = "C:\\Users\\Shaniel Samadhan\\Desktop\\NNFX FORWARD BACKTESTER\\portable mt4\\"

    if os.path.isfile(f'{dir_src}nnfx_forward_backtester.set'):
        os.remove(f'{dir_src}nnfx_forward_backtester.set')

    navigate_and_rename(dir_src)

    replace_in_file(f'{dir_src}nnfx_forward_backtester.set', token, f'{i}')

    manager = TradeManager(pairs_to_use=benchmark_fx_pairs, evz_treshold=evz_treshold, news_avoidance=news_avoidance, news_hours=24, filter_high_impact_news_only=False, expert_name=expert_name,
                           settings_setfile=settings_setfile, timeframe=timeframe, start_date=start_date, end_date=end_date, spread=spread, optimisation=optimisation)

    manager.copy_files_to_testers()
    manager.start_testers()
    manager.start_trade_manager()

    i += period_step
    sleep(2)
