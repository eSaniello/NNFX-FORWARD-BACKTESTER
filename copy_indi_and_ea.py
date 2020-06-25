import shutil
import os


def copy_files_to_testers(pairs):
    for pair in pairs:
        # remove the folders first
        shutil.rmtree(
            f'testers/{pair}/MQL4/Experts/')

        # copy the folders
        shutil.copytree(
            'portable mt4/MQL4/Experts/', f'testers/{pair}/MQL4/Experts/')

        # copy the nnfx_forward_backtester.ini file
        shutil.copy('portable mt4/nnfx_forward_backtester.ini',
                    f'testers/{pair}/')

        # copy the nnfx_forward_backtester.set file
        shutil.copy('portable mt4/nnfx_forward_backtester.set',
                    f'testers/{pair}/')

        print(f'Copied indicators, experts, settings and .ini file to {pair}')
