import shutil


def _copy_files_to_testers(pairs, optimisation):
    for pair in pairs:
        # remove the folders first
        shutil.rmtree(
            f'testers/{pair}/MQL4/Experts/')
        shutil.rmtree(
            f'testers/{pair}/MQL4/Include/')
        shutil.rmtree(
            f'EA/')

        # copy the folders
        shutil.copytree(
            'portable mt4/MQL4/Experts/', f'testers/{pair}/MQL4/Experts/')
        shutil.copytree(
            'portable mt4/MQL4/Include/', f'testers/{pair}/MQL4/Include/')

        shutil.copytree(
            'portable mt4/MQL4/Experts/', f'EA/')
        shutil.copy('portable mt4/MQL4/Include/Baseline.mqh',
                    f'EA/')
        shutil.copy('portable mt4/MQL4/Include/Confirmation_1.mqh',
                    f'EA/')
        shutil.copy('portable mt4/MQL4/Include/Confirmation_2.mqh',
                    f'EA/')
        shutil.copy('portable mt4/MQL4/Include/Vol.mqh',
                    f'EA/')
        shutil.copy('portable mt4/MQL4/Include/Exit.mqh',
                    f'EA/')

        # copy the nnfx_forward_backtester.ini file
        shutil.copy('portable mt4/nnfx_forward_backtester.ini',
                    f'testers/{pair}/config/')

        # copy the settings file
        shutil.copy('portable mt4/NNFX FORWARD BACKTESTER.ini',
                    f'testers/{pair}/tester/')

        if optimisation == False:
            print(
                f'Copied indicators, experts, settings and .ini file to {pair}')
