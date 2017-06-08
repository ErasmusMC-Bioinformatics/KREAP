#!/bin/bash
set -e
dir="$(cd "$(dirname "$0")" && pwd)"
input=$1
index=$2
output=$3
output_dir=$4

input_dir="${input/.dat/_files}/plate"

/media/galaxy/data/anaconda/anaconda2/bin/python $dir/kreap_data_modeling.py --input ${input_dir} --index-file $index --out-html $output --out-dir ${output_dir}
