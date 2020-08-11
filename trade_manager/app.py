from TRADEMANAGER import TradeManager

# SETTINGS
evz_treshold = 3
news_avoidance = True
expert_name = 'NNFX FORWARD BACKTESTER'
settings_setfile = 'nnfx_forward_backtester'
timeframe = 'D1'  # M1, M5, M15, M30, H1, H4, D1, W1, MN
start_date = '2019.01.01'
end_date = '2020.08.11'
spread = '5'  # 0 = use current spread

forex_pairs = ["AUDCAD", "AUDCHF", "AUDJPY", "AUDNZD", "AUDUSD", "CADCHF", "CADJPY", "CHFJPY", "EURCHF", "EURAUD", "EURCAD", "EURGBP", "EURJPY", "EURNZD", "EURUSD",
               "GBPAUD", "GBPCAD", "GBPCHF", "GBPJPY", "GBPNZD", "GBPUSD", "NZDCHF", "NZDCAD", "NZDJPY", "NZDUSD", "USDCAD", "USDCHF", "USDJPY"]

benchmark_fx_pairs = ['EURUSD', 'AUDNZD', 'EURGBP', 'AUDCAD', 'CHFJPY']

dummy_pairs = ["AUDCAD", "AUDCHF", "AUDJPY", "AUDNZD", "AUDUSD", "CADCHF", "CADJPY", "CHFJPY", "EURCHF", "EURAUD", "EURCAD", "EURGBP", "EURJPY", "EURNZD", "EURUSD",
               "GBPAUD", "GBPCAD", "GBPCHF", "USDJPY"]

manager = TradeManager(evz_treshold=evz_treshold, news_avoidance=news_avoidance, news_hours=24, filter_high_impact_news_only=False, expert_name=expert_name,
                       settings_setfile=settings_setfile, timeframe=timeframe, start_date=start_date, end_date=end_date, spread=spread, pairs_to_use=benchmark_fx_pairs)

manager.copy_files_to_testers()
manager.start_testers()
manager.start_trade_manager()
