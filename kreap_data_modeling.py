import argparse
import os
import datetime
from collections import defaultdict
import logging
import sys
import shutil

import kreap_classes
import kreap_util

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--input-dir", help="A plate directory with wells, structured as described in the index file.")
    parser.add_argument("--index-file", help="The index file")
    parser.add_argument("--out-html", help="The output HTML file")
    parser.add_argument("--out-dir", help="The output directory")
    args = parser.parse_args()

    logging.basicConfig(filename=args.out_html, level=logging.DEBUG, format="%(asctime)s:&emsp;%(message)s <br />", datefmt='%Y/%m/%d %H:%M:%S')
    logging.getLogger().addHandler(logging.StreamHandler(sys.stdout)) # also log to stdout
    logging.info("Started KREAP Analysis")

    logging.info("Processing wells")
    plate = kreap_classes.Plate(args.input_dir, args.index_file)


    tool_dir = os.path.dirname(os.path.realpath(__file__))
    #gompertz_script = os.path.join(tool_dir, "Gompertz_inversion_NLS_with_error_handling_clean.R")
    gompertz_script = os.path.join(tool_dir, "Gompertz_inversion_NLS_error_handling_v3_clean.R")

    experiment_dir = os.path.join(args.out_dir, "experiment")

    os.makedirs(experiment_dir)

    logging.info("Running Gompertz analysis")
    plate.run_gompertz(gompertz_script, experiment_dir)

    treatment_plate_index_file = os.path.join(tool_dir, "treatment_plate_index.html")

    logging.debug("Adding plate html file")
    plate.add_treatment_plate_index_file(treatment_plate_index_file, args.index_file)

    treatment_well_index_file = os.path.join(tool_dir, "treatment_well_index.html")

    logging.debug("Adding treatment html file")
    plate.add_treatment_well_index_file(treatment_well_index_file)

    referal_template_file = os.path.join(tool_dir, "first_page_template.html")

    logging.debug("Creating referal html page")
    errors = defaultdict(list)
    for well in plate.get_analysis_parameters():
        errors[well["Treatment"]].append(well["Mu_m"] != "NA" and float(well["R2"]) >= 0.9)
    errors = {k: "Ok" if all(v) else "Error!" for k,v in errors.iteritems()}


    context = {
        "datetime": datetime.datetime.now(),
        "wells": plate.get_summary_data(),
        "treatments": plate.get_treatments_data(),
        "errors": errors
    }

    shutil.move(args.out_html, os.path.join(args.out_dir, "log.html"))

    kreap_util.write_jinja_template(referal_template_file, args.out_html, context)
        
    

if __name__ == "__main__":
    main()
