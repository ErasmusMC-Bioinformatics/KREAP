import os
import subprocess
import datetime
import logging
import sys

from jinja2 import Template

from collections import defaultdict

def write_jinja_template(in_template, out_file, context={}):
    logging.debug("Writing Jinja2 template '{0}' to '{1}'".format(in_template, out_file))
    with open(in_template, 'r') as in_t, open(out_file, 'w') as out:
        t = Template(in_t.read())
        out.write(t.render(**context))

def write_std_output(output_process, process_name, log_dir):
    logging.debug("Writing std outputs of '{0}' to '{1}'".format(process_name, log_dir))
    stdout_file = os.path.join(log_dir, "{0}_stdout.txt".format(process_name))
    with open(stdout_file, 'a') as o:
        o.write("{0} \n".format(datetime.datetime.now()))
        o.write(output_process.stdout.read())
    
    stderr_file = os.path.join(log_dir, "{0}_stderr.txt".format(process_name))
    with open(stderr_file, 'a') as o:
        o.write("{0} \n".format(datetime.datetime.now()))
        o.write(output_process.stderr.read())

def file_to_dict_array(input_file, separator="\t"):
    """
    Turns a column based file into an array of dicts, where the keys are the column names
    So result[3]["first"] gets the value from the column with the name "first" and the fourth row
    """
    result = []
    with open(input_file, 'rU') as i:
        header = None
        for line in i:
            splt = line.rstrip().split(separator)
            if not header:
                header = splt
                continue
            result.append({header[i]: splt[i] for i in range(len(splt))})
    return result

def matrix_file_to_dict_array(f, seperator="\t", num_key_cols=1):
    """
    Turns a matrix file (row and column names) into a dict of dicts
    so result["row1"]["column.5"] returns 5,1 (x,y) in the matrix
    num_key_cols can be used to make multiple rows the row name, so result["treatment_well"]["R2"]
    """
    result = defaultdict(dict)
    with open(f, 'r') as i:
        header=None
        for l in i:
            l = l.rstrip()
            splt = l.split(seperator)
            row_name = "_".join(splt[:num_key_cols])
            values = splt
            if not header:
                header = values
                continue
            result[row_name] = {header[i]: values[i] for i in range(len(values))}
        return result


def execute_subprocess(command, name="", log_dir=""):
    logging.debug("Executing subprocess '{0}'".format(' '.join(command)))
    if not name:
        name = command[0]
    if not log_dir:
        p = subprocess.Popen(command, stdout=sys.stdout, stderr=sys.stderr)
    else:
        stdout_file = os.path.join(log_dir, "{0}_stdout.txt".format(name))
        stderr_file = os.path.join(log_dir, "{0}_sterr.txt".format(name))
        with open(stdout_file, 'w') as o, open(stderr_file, 'w') as e:
            p = subprocess.Popen(command, stdout=o, stderr=e)
    p.wait()
    return p

def unzip_to(zip_file, unzip_path):
    if not os.path.exists(unzip_path):
        os.makedirs(unzip_path)
    
    p = execute_subprocess(["unzip", zip_file, "-d", unzip_path], name="unzip", log_dir=unzip_path)

    return p

def execute_cellprofiler(well, pipeline, output_dir, file_list, docker=False):
    command = ["cellprofiler", "--run-headless", "--do-not-fetch", "-c", "-r", "--pipeline={0}".format(pipeline), "-o", output_dir, "--file-list={0}".format(file_list)]
    if docker:
        command = ["docker", "run", "-v", "{0}:/well_dir/".format(output_dir), "cellprofiler/cellprofiler:2.2", "-c", "-r", "--pipeline=/well_dir/well_pipeline.cppipe", "-o", "/well_dir/", "--file-list", "/well_dir/filelist.txt"]
    print " ".join(command)
    p = execute_subprocess(command, "cellprofiler", output_dir)
    cellprofiler_error = None
    cellprofiler_log = os.path.join(output_dir, "cellprofiler_sterr.txt")
    with open(cellprofiler_log, 'r') as o:
        cellprofiler_error = o.read()
    error_check = "Image # {0:d}, module ExportToSpreadsheet".format(len(well.files))
    if cellprofiler_error.find(error_check) == -1:
        raise Exception("Something went wrong when running cellprofiler on well, can't find '{0}': {1}".format(error_check, cellprofiler_error))
    
    return p