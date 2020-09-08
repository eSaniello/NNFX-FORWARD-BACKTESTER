from numpy import arange


def safe_arange(start, stop, step):
    return step * arange(start / step, stop / step)


def generateOptimisationList(cur_variables, optimisations, output={}, cur_level=1):
    if len(cur_variables) > 0:
        cur_item = cur_variables[cur_level - 1]

        if isinstance(cur_item, str):
            cur_item = cur_item.split('>')

            if len(cur_item) > 1:
                for cur_range in cur_item[1].split(','):
                    is_range = False

                    try:
                        round(float(cur_range), 2)
                        is_range = True
                    except ValueError:
                        if ':' in cur_range or '~' in cur_range:
                            is_range = True

                    if is_range:
                        # check for step notation
                        step = cur_range.split(':')
                        rng = step[0]

                        if len(step) > 1:
                            step = float(step[1])
                        else:
                            step = 1

                        rng = rng.split('~')

                        if len(rng) > 1:
                            for cur_val in safe_arange(float(rng[0]), float(rng[1]) + 0.0001, step):
                                output = dict(output)
                                output[cur_item[0]] = cur_val

                                if cur_level < len(cur_variables):
                                    generateOptimisationList(cur_variables, optimisations, dict(
                                        output), cur_level + 1)
                                else:
                                    optimisations.append(output)
                        else:
                            output = dict(output)
                            output[cur_item[0]] = round(float(rng[0]), 2)

                            if cur_level < len(cur_variables):
                                generateOptimisationList(cur_variables, optimisations, dict(
                                    output), cur_level + 1)
                            else:
                                optimisations.append(output)
                    else:
                        # we are just handling single string values
                        output = dict(output)
                        output[cur_item[0]] = cur_range

                        if cur_level < len(cur_variables):
                            generateOptimisationList(cur_variables, optimisations,
                                                     dict(output), cur_level + 1)
                        else:
                            optimisations.append(output)
            else:
                # dealing with a boolean
                for cur_bool in [True, False]:
                    output = dict(output)
                    output[cur_item[0]] = cur_bool

                    if cur_level < len(cur_variables):
                        generateOptimisationList(
                            cur_variables, optimisations, output, cur_level + 1)
                    else:
                        optimisations.append(output)
