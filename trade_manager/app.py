from TRADEMANAGER import TradeManager
from optimize import generateOptimisationList
from optimize import apply_setting_to_ini_file
from optimize import append_list_as_row
from tqdm import tqdm
import sys
import time


# SETTINGS
optimisation = False
evz_treshold = 3
news_avoidance = False
expert_name = 'NNFX FORWARD BACKTESTER'
timeframe = 'H1'  # M1, M5, M15, M30, H1, H4, D1, W1, MN
start_date = '2017.01.01'
end_date = '2020.11.02'
spread = '1'  # 0 = use current spread

# List of pairs to test
forex_pairs = [
    "AUDCAD", "AUDCHF", "AUDJPY", "AUDNZD", "AUDUSD", "CADCHF", "CADJPY", "CHFJPY", "EURCHF", "EURAUD", "EURCAD", "EURGBP", "EURJPY", "EURNZD", "EURUSD",
    "GBPAUD", "GBPCAD", "GBPCHF", "GBPJPY", "GBPNZD", "GBPUSD", "NZDCHF", "NZDCAD", "NZDJPY", "NZDUSD", "USDCAD", "USDCHF", "USDJPY"
]

benchmark_fx_pairs = ['EURUSD', 'AUDNZD', 'AUDCAD', 'CHFJPY', 'EURGBP']

pairs = forex_pairs

# ##################################
# optimisation flow
# gen optim list >> loop over list >> apply settings to .ini files and copy >> run testers with settings >> repeat
# FORMAT:
# range: 'name>start~stop:step'
# boolean: 'name_of_var'
# linear: 'name>1,2,3,4,5'
# range and linear mix: 'name>2~7,8,9,10~12'
optimisation_variables = [
    # 'evz_treshold>2~8:2',
    # 'news_avoidance',
    'scaleOut',
    'use7CandleRule',
    'filterPullbacks',
    'baselineATRFilter',
    # 'takeProfitPercent>0.5~2.0:0.1',
    # 'stoplossPercent>0.5~2.0:0.1'
]

if optimisation:
    # Generating all possible optimisations based on above params
    optimisationList = []
    generateOptimisationList(optimisation_variables, optimisationList)

    for setting in tqdm(optimisationList, file=sys.stdout, desc='Running test'):
        # Apply settings to EAname.ini settings file
        apply_setting_to_ini_file(
            'scaleOut', setting['scaleOut'])
        apply_setting_to_ini_file(
            'use7CandleRule', setting['use7CandleRule'])
        apply_setting_to_ini_file(
            'filterPullbacks', setting['filterPullbacks'])
        apply_setting_to_ini_file(
            'baselineATRFilter', setting['baselineATRFilter'])
        # apply_setting_to_ini_file(
        #     'takeProfitPercent', setting['takeProfitPercent'])
        # apply_setting_to_ini_file(
        #     'stoplossPercent', setting['stoplossPercent'])

        manager = TradeManager(
            pairs_to_use=pairs,
            # evz_treshold=setting['evz_treshold'],
            evz_treshold=evz_treshold,
            # news_avoidance=setting['news_avoidance'],
            news_avoidance=news_avoidance,
            news_hours=24,
            filter_high_impact_news_only=False,
            expert_name=expert_name,
            timeframe=timeframe,
            start_date=start_date,
            end_date=end_date,
            spread=spread,
            optimisation=optimisation
        )

        manager.copy_files_to_testers()
        manager.start_testers()
        stats = manager.start_trade_manager()

        insertRow = []
        insertRow.append(str(setting))
        insertRow.append(stats['init_balance'])
        insertRow.append(stats['net_profit'])
        insertRow.append(stats['end_balance'])
        insertRow.append(stats['average_winrate'])
        insertRow.append(stats['total_gross_profit'])
        insertRow.append(stats['total_gross_loss'])
        insertRow.append(stats['profit_factor'])
        insertRow.append(stats['annual_roi'])
        insertRow.append(stats['total_roi'])
        insertRow.append(stats['total_trades'])
        insertRow.append(stats['max_drawdown'])

        append_list_as_row('optimisation.csv', insertRow)
        time.sleep(2)

else:
    one_run = False
    while True:
        if not one_run:
            manager = TradeManager(
                pairs_to_use=pairs,
                evz_treshold=evz_treshold,
                news_avoidance=news_avoidance,
                news_hours=24,
                filter_high_impact_news_only=False,
                expert_name=expert_name,
                timeframe=timeframe,
                start_date=start_date,
                end_date=end_date,
                spread=spread,
                optimisation=optimisation
            )

            manager.copy_files_to_testers()
            manager.start_testers()
            stats = manager.start_trade_manager()

            one_run = True
