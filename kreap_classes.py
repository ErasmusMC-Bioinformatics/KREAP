from collections import defaultdict
import os
import re
import shutil
import logging

import kreap_util
import kreap_classes

class Well(object):
    def __new__(cls, plate, values):
        return super(Well, cls).__new__(cls)

    def __init__(self, plate, values):
        self.plate = plate
        self.treatment = values['treatment']
        self.location = values['location']
        self.file_regex = re.compile(values['file_regex'])
        self.time_regex = re.compile(values['time_regex'])
        self.pixel_block_size = int(values['pixel_block_size'])
        self.object_size_min = int(values['object_size_min'])
        self.object_size_max = int(values['object_size_max'])
        self.time_interval = int(values["time_interval"])
        self.rotate = float(values["rotate"]) if "rotate" in values else 0

        self.files = [] #full path to the image
        self.file_names = [] #just the file names
        self.file_times = [] #stores just the "Time" identifier of the files (000001, 000002, 000003, etc)
        self.cellprofiler_result = None

        self.find_files()

    def find_files(self):
        well_path = self.get_well_path()
        if not os.path.exists(well_path):
            raise IOError("Well location doesn't exist: {0}".format(well_path))
        self.files = []
        for f in os.listdir(well_path):
            file_path = os.path.join(well_path, f)
            if self.file_regex.search(file_path):
                self.files.append(file_path)

        self.file_names = [os.path.basename(x) for x in self.files]
        self.file_times = sorted([self.time_regex.search(x).group("Time") for x in self.file_names], key=lambda x: int(x) if x.isdigit() else x)
        
        #check if cellprofiler was already run on this well
        cp_result = self.get_cellprofiler_result_file()
        if os.path.exists(cp_result):
            self.cellprofiler_result = cp_result

    def get_well_path(self):
        return os.path.join(self.plate.plate_root, self.location)

    def get_cellprofiler_result_file(self, with_header=True):
        if with_header:
            return os.path.join(self.get_well_path(), "numbers.txt")
        return os.path.join(self.get_well_path(), "numbers_no_header.txt")
    
    def has_cellprofiler_result(self):
        return self.cellprofiler_result != None

    def get_well_pipeline(self, pipeline_template, docker=False):
        well_path = self.get_well_path()
        well_pipeline_path = os.path.join(well_path, "well_pipeline.cppipe")
        if not os.path.exists(well_pipeline_path):
            context = {
                "file_regex": self.file_regex.pattern, 
                "time_regex": self.time_regex.pattern, 
                "pixel_block_size": self.pixel_block_size, 
                "object_size_min": self.object_size_min, 
                "object_size_max": self.object_size_max,
                "rotate": self.rotate,
                "well_path": "/well_dir/" if docker else well_path
            }
            kreap_util.write_jinja_template(pipeline_template, well_pipeline_path, context)
        return well_pipeline_path

    def run_cellprofiler(self, pipeline, docker=False):
        if not self.cellprofiler_result:
            logging.info("Running Cellprofiler on '{0}'".format(self.location))
            well_path = self.get_well_path()
            file_list_file = os.path.join(well_path, "filelist.txt")
            with open(file_list_file, 'w') as o:
                if docker:
                    o.write("\n".join(["/well_dir/{0}".format(os.path.basename(x)) for x in self.files]))
                else:
                    o.write("\n".join(self.files))
            pipeline = self.get_well_pipeline(pipeline, docker)
            p = kreap_util.execute_cellprofiler(self, pipeline, self.get_well_path(), file_list_file, docker)
            self.cellprofiler_result = os.path.join(well_path, "Nuclei_data.txt")

    def find_gap(self, rscript):
        if self.cellprofiler_result:
            logging.info("Finding the gap for '{0}'".format(self.location))
            p = kreap_util.execute_subprocess(["Rscript", rscript, self.cellprofiler_result, ",".join(self.file_times), self.get_well_path()], "after_CP", self.get_well_path())
            r_error = None
            after_log = os.path.join(self.get_well_path(), "after_CP_sterr.txt")
            with open(after_log, 'r') as i:
                r_error = i.read()
            if len(r_error) > 0:
                raise Exception("Something went wrong while running after_CP.r: {0}".format(r_error))
        else:
            raise Exception("First run the cellprofiler analysis")
    
    def add_well_index_html(self, index_template_file):
        well_path = self.get_well_path()
        well_index_path = os.path.join(well_path, "index.html")
        well_numbers_file = os.path.join(well_path, "numbers.txt")

        context = {
            "well_name": self.location,
            "num_images": len(self.files),
            "steps": kreap_util.file_to_dict_array(well_numbers_file),
            "original_images": ["Original_{0}.png".format(x) for x in self.file_times],
            "plot_images": ["Nuclei_{0}.png".format(x) for x in self.file_times],
            "file_times": self.file_times
        }
        kreap_util.write_jinja_template(index_template_file, well_index_path, context)
    
    def get_summary_data(self):
        summary_file = os.path.join(self.get_well_path(), "summary.txt")
        if not os.path.exists(summary_file) or not self.cellprofiler_result:
            raise Exception("Run cellprofiler and after_CP.r first")
        return kreap_util.matrix_file_to_dict_array(summary_file)

    def __str__(self):
        return "treatment: {0}\nlocation: {1}\nfile_regex: {2}\npixel_block_size: {3}\nobject_size_min: {4:d}\nobject_size_max: {5:d}\nFiles: {6}".format(self.treatment, self.location, self.file_regex.pattern, self.pixel_block_size, self.object_size_min, self.object_size_max, str(self.files))

class Plate(object):
    def __new__(cls, plate_root, well_index_file):
        return super(Plate, cls).__new__(cls)
    
    def __init__(self, plate_root, well_index_file):
        if not os.path.exists(plate_root):
            raise IOError("Plate root doesn't exist: {0}".format(plate_root))
            
        self.plate_root = plate_root

        print os.listdir(self.plate_root)
        self.wells = {}
        self.wells_by_treatment = defaultdict(list)
        self.parse_index_file(well_index_file)

        self.experiment_dir = None
        self.analysis_parameters = None

    
    def parse_index_file(self, well_index_file):
        if not os.path.exists(well_index_file):
            raise IOError("Well index file doesn't exist")
        
        logging.info("Parsing index file")

        well_data = kreap_util.file_to_dict_array(well_index_file)

        logging.info("{0} wells in plate".format(len(well_data)))
        row_number = 1
        for well_dict in well_data:
            well = Well(self, well_dict)
            self.wells[str(row_number)] = well
            self.wells_by_treatment[well.treatment].append(well)
            row_number += 1

    def setup_experiment_dir(self, experiment_dir):
        for treatment_key in self.wells_by_treatment.keys():
            treatment_wells = self.wells_by_treatment[treatment_key]
            treatment_dir = os.path.join(experiment_dir, treatment_key)

            if not os.path.exists(treatment_dir):
                os.makedirs(treatment_dir)

            for well in treatment_wells:
                dst = os.path.join(treatment_dir, "{0}.txt".format(well.location))
                shutil.copyfile(well.get_cellprofiler_result_file(with_header=False), dst)
        self.experiment_dir = experiment_dir

    def run_gompertz(self, gompertz_script, experiment_dir):
        self.setup_experiment_dir(experiment_dir)
        p = kreap_util.execute_subprocess(["Rscript", gompertz_script, experiment_dir,  str(self.wells.values()[0].time_interval)], "gompertz", experiment_dir)
        gompertz_error = None
        gompertz_log = os.path.join(experiment_dir, "gompertz_sterr.txt")
        with open(gompertz_log, 'r') as i:
            gompertz_error = i.read()
        if gompertz_error.find("Error") != -1:
            raise Exception("Something went wrong when running gompertz: {0}".format(gompertz_error))

    def get_summary_data(self):
        result = {}
        for well in self.wells.values():
            result[well.location] = well.get_summary_data()
        return result

    def run_cellprofiler(self, pipeline, docker=False):
        for well in self.wells.values():
            well.run_cellprofiler(pipeline, docker)
    
    def find_gap(self, rscript):
        for well in self.wells.values():
            well.find_gap(rscript)

    def add_well_index_html(self, index_file):
        for well in self.wells.values():
            well.add_well_index_html(index_file)
    
    def make_plate_index_html(self):
        plate_index_html = os.path.join(self.plate_root, "index.html")
        with open(plate_index_html, 'w') as o:
            for well in self.wells.values():
                o.write("<a href='{0}/index.html'>{0}</a><br />".format(well.location))

    def get_treatments_data(self):
        treatments = []
        for treatment_key in self.wells_by_treatment.keys():
            treatment = self.wells_by_treatment[treatment_key]
            treatments.append({"name": treatment_key, "num_wells": len(treatment), "time_points": len(treatment[0].files)})
        return treatments
    
    def get_analysis_parameters(self):
        if not self.experiment_dir:
            raise Exception("Run the gompert analysis first")

        if not self.analysis_parameters:
            parameters_file = os.path.join(self.experiment_dir, "parameters.txt")
            if not os.path.exists(parameters_file):
                raise Exception("No parameters file")
            self.analysis_parameters = kreap_util.file_to_dict_array(parameters_file)
        return self.analysis_parameters

    def add_treatment_plate_index_file(self, template_file, index_file):
        if not self.experiment_dir:
            raise Exception("Run the gompert analysis first")
        plate_index_file = os.path.join(self.experiment_dir, "index.html")

        index_data = kreap_util.file_to_dict_array(index_file)
        index = {}
        column_order = ["treatment", "location", "file_regex", "time_regex", "pixel_block_size", "object_size_min", "object_size_max", "time_interval"]
        index["header"] = "\t".join(column_order)

        for row in index_data: #setup stuff for creating a new index file client side, a dict with well as key and the entire tabulated row as value
            new_row = [""] * len(column_order)
            for i in range(len(column_order)):
                new_row[i] = row[column_order[i]]
            index[row["location"]] = "\t".join(new_row)
        
        context = {
            "wells": self.get_analysis_parameters(),
            "index_data": index
        }
        kreap_util.write_jinja_template(template_file, plate_index_file, context)

    def add_treatment_well_index_file(self, template_file):
        if not self.experiment_dir:
            raise Exception("Run the gompert analysis first")
        
        for treatment in self.wells_by_treatment.keys():
            logging.debug("Adding index file for treatment {0}".format(treatment))
            treatment_dir = os.path.join(self.experiment_dir, treatment)
            plots = [x for x in os.listdir(treatment_dir) if x.endswith(".png")]
            treatment_index_file = os.path.join(treatment_dir, "index.html")

            context = {
                "treatment_name": treatment,
                "plots": plots
            }

            kreap_util.write_jinja_template(template_file, treatment_index_file, context)
        
    def __str__(self):
        return "plate_root: {0}\nWells: {1}".format(self.plate_root, '\n'.join([str(well) for well in self.wells.values()]))  
     
