import subprocess
import shlex


expert_token = "<EXPERT>"
file_token = "<FILE>"
symbol_token = "<SYMBOL>"
timeframe_token = "<TIMEFRAME>"
start_date_token = "<START_DATE>"
end_date_token = "<END_DATE>"
spread_token = "<SPREAD>"


def replace_in_file(file_path, str_search, str_replace):
    # read input file
    fin = open(file_path, "rt")
    # read file contents to string
    data = fin.read()
    # replace all occurrences of the required string
    data = data.replace(str_search, str_replace)
    # close the input file
    fin.close()
    # open the input file in write mode
    fin = open(file_path, "wt")
    # overrite the input file with the resulting data
    fin.write(data)
    # close the file
    fin.close()


def run_testers(pairs, _expert_name, _settings_setfile, _timeframe, _spread, _start_date, _end_date):
    for pair in pairs:
        # change .ini file for every tester
        path_to_ini_file = f'testers/{pair}/config/nnfx_forward_backtester.ini'
        replace_in_file(path_to_ini_file, expert_token, _expert_name)
        replace_in_file(path_to_ini_file, file_token, _settings_setfile)
        replace_in_file(path_to_ini_file, symbol_token, pair)
        replace_in_file(path_to_ini_file, timeframe_token, _timeframe)
        replace_in_file(path_to_ini_file, spread_token, _spread)
        replace_in_file(path_to_ini_file, start_date_token, _start_date)
        replace_in_file(path_to_ini_file, end_date_token, _end_date)

        # open tester with .ini file to run strategy tester automatically with above specified settings
        path_to_tester = f"C:\\Users\\Shaniel Samadhan\\Desktop\\NNFX FORWARD BACKTESTER\\testers\\{pair}\\terminal.exe"
        absolute_path_to_ini_file = f"C:\\Users\\Shaniel Samadhan\\Desktop\\NNFX FORWARD BACKTESTER\\testers\\{pair}\\config\\nnfx_forward_backtester.ini"
        command = f'"{path_to_tester}" "{absolute_path_to_ini_file}" /skipupdate /portable'
        # print(command)
        subprocess.Popen(shlex.split(command))
        print(f'Started {pair}')


# https://www.mql5.com/en/forum/127577
