
import os
import shutil


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


def navigate_and_rename(src):
    for item in os.listdir(src):
        s = os.path.join(src, item)
        if os.path.isdir(s):
            navigate_and_rename(s)
        elif s.endswith(".set"):
            shutil.copy(s, os.path.join(src, "nnfx_forward_backtester.set"))
