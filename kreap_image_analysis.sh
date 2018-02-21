index=$1
zip=$2
output=$3
output_dir=$4

dir="$(cd "$(dirname "$0")" && pwd)"

python $dir/kreap_image_analysis.py --index-file "${index}" --plate-zip "${zip}" --out-html "${output}" --out-dir "${output_dir}"
