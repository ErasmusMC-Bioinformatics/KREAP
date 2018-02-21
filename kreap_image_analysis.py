import argparse
import os
import re
import subprocess
import site
import datetime
import logging
import shutil
import sys

import kreap_util
import kreap_classes


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--index-file", help="The index file that ")
    parser.add_argument("--plate-zip", help="The zip file containing the wells")
    parser.add_argument("--out-html", help="The output HTML file")
    parser.add_argument("--out-dir", help="The output directory")

    args = parser.parse_args()

    output_dir = args.out_dir

    logging.basicConfig(filename=args.out_html, level=logging.INFO, format="%(asctime)s:&emsp;%(message)s <br />", datefmt='%Y/%m/%d %H:%M:%S')
    logging.getLogger().addHandler(logging.StreamHandler(sys.stdout)) # also log to stdout
    logging.info("Started KREAP")

    if not os.path.exists(args.out_dir):
        os.makedirs(args.out_dir)
    unzip_path = os.path.join(args.out_dir, "plate")
    if not os.path.exists(unzip_path):
        os.makedirs(unzip_path)

    logging.info("Unzipping plate zip")
    p = kreap_util.unzip_to(args.plate_zip, unzip_path)
    #kreap_util.write_std_output(p, "unzip", output_dir)

    logging.info("Processing wells")
    plate = kreap_classes.Plate(unzip_path, args.index_file)

    tool_dir = os.path.dirname(os.path.realpath(__file__))

    logging.info("Running Cellprofiler")
    pipeline_template_file = os.path.join(tool_dir, "pipeline_template.cppipe")
    plate.run_cellprofiler(pipeline_template_file, docker=True)

    logging.info("Finding the gaps")
    rscript = os.path.join(tool_dir, "after_CP.r")
    plate.find_gap(rscript)

    logging.debug("Adding html files")
    plate.make_plate_index_html()

    index_file = os.path.join(tool_dir, "index.html")
    plate.add_well_index_html(index_file)

    logging.debug("Creating referal html page")
    referal_template_file = os.path.join(tool_dir, "first_page_template.html")

    context = {
        "datetime": datetime.datetime.now(),
        "wells": plate.get_summary_data()
    }

    shutil.move(args.out_html, os.path.join(output_dir, "log.html"))

    kreap_util.write_jinja_template(referal_template_file, args.out_html, context)

    logging.debug("Done!")

if __name__ == "__main__":
    main()