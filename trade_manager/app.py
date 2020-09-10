from TRADEMANAGER import TradeManager
from optimize import generateOptimisationList
from time import sleep


# SETTINGS
optimisation = True
evz_treshold = 3
news_avoidance = True
expert_name = 'NNFX FORWARD BACKTESTER'
settings_setfile = 'nnfx_forward_backtester'
timeframe = 'D1'  # M1, M5, M15, M30, H1, H4, D1, W1, MN
start_date = '2019.05.01'
end_date = '2020.08.10'
spread = '5'  # 0 = use current spread

# List of pairs to test
forex_pairs = [
    "AUDCAD", "AUDCHF", "AUDJPY", "AUDNZD", "AUDUSD", "CADCHF", "CADJPY", "CHFJPY", "EURCHF", "EURAUD", "EURCAD", "EURGBP", "EURJPY", "EURNZD", "EURUSD",
    "GBPAUD", "GBPCAD", "GBPCHF", "GBPJPY", "GBPNZD", "GBPUSD", "NZDCHF", "NZDCAD", "NZDJPY", "NZDUSD", "USDCAD", "USDCHF", "USDJPY"
]

benchmark_fx_pairs = ['EURUSD', 'AUDNZD', 'EURGBP', 'AUDCAD', 'CHFJPY']

dummy_pairs = ["AUDCAD"]

# Settings to optimise
optimisation_variables = [
    # 'evz_treshold>2~8:2',
    # 'evz_treshold>1~10',
    # 'lookBackDays>180,365,730',
    'news_avoidance'
]

if optimisation:
    # Generating all possible optimisations based on above params
    optimisationList = []
    generateOptimisationList(optimisation_variables, optimisationList)

    # list to store all stats in
    all_stats = []

    for setting in optimisationList:
        manager = TradeManager(
            pairs_to_use=benchmark_fx_pairs,
            # evz_treshold=setting['evz_treshold'],
            evz_treshold=evz_treshold,
            news_avoidance=setting['news_avoidance'],
            news_hours=24,
            filter_high_impact_news_only=False,
            expert_name=expert_name,
            settings_setfile=settings_setfile,
            timeframe=timeframe,
            start_date=start_date,
            end_date=end_date,
            spread=spread,
            optimisation=optimisation
        )

        manager.copy_files_to_testers()
        manager.start_testers()
        stats = manager.start_trade_manager()
        all_stats.append({'settings': setting, 'stats': stats})

    # sort all stats after optimisation completes
    # find highest roi
    highest_roi = 0.0
    highest_stats = None
    for stat in all_stats:
        roi = float(stat['stats']['total_roi'])
        if roi > highest_roi:
            highest_roi = roi
            highest_stats = stat

    # print best performing run
    print(highest_roi)
    print(highest_stats)
else:
    manager = TradeManager(
        pairs_to_use=benchmark_fx_pairs,
        evz_treshold=evz_treshold,
        news_avoidance=news_avoidance,
        news_hours=24,
        filter_high_impact_news_only=False,
        expert_name=expert_name,
        settings_setfile=settings_setfile,
        timeframe=timeframe,
        start_date=start_date,
        end_date=end_date,
        spread=spread,
        optimisation=optimisation
    )

    manager.copy_files_to_testers()
    manager.start_testers()
    stats = manager.start_trade_manager()
