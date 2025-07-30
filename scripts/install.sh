#! /usr/bin/env bash

#
# BUILD AND LOAD A TRAIT ONTOLOGY
# 
# Arguments to build an sgn .obo file:
#   --input/-i = path to trait workbook file
#   --output/-o = path to generated sgn obo file
#   --filter/-f = (optional) name of institution to use as variable filter
#
# Arguments to install .obo file on server:
#   --server-user = name of ssh user on install server
#   --server-host = hostname of install server
#   --server-instance = service name of breedbase instance to update
# 
#

# Define paths to ontology scripts
SCRIPT_DIR=$(dirname "$0")
BUILD_SCRIPT="$SCRIPT_DIR/build_traits.pl"
BUILD_PROPS_SCRIPT="$SCRIPT_DIR/build_trait_props.pl"
CONVERT_SCRIPT="$SCRIPT_DIR/convert_obo.pl"

# Define short and long options
SHORT="i:,o:,f:"
LONG="input:,output:,filter:,server-user:,server-host:,server-instance:"

# Initialize variables
input=""
output=""
filter_institution=""
temp_file=".temp-standard.obo"
server_user=""
server_host=""
server_instance=""

# Parse arguments
params="$(getopt -o $SHORT -l $LONG --name "$(basename "$0")" -- "$@")"
eval set -- "$params"
unset params
while true; do
    case $1 in
        -i|--input)
            input="$2"
            shift 2
            ;;
        -o|--output)
            output="$2"
            shift 2
            ;;
        -f|--filter)
            filter_institution="$2"
            shift 2
            ;;
        --server-user)
            server_user="$2"
            shift 2
            ;;
        --server-host)
            server_host="$2"
            shift 2
            ;;
        --server-instance)
            server_instance="$2"
            shift 2
            ;;
        --)
            shift
            break
            ;;
        *)
            usage
            ;;
    esac
done


# Check arguments
if [[ -z "$input" ]]; then
    echo "ERROR: input file is required"
    exit 1
fi
if [[ -z "$output" ]]; then
    echo "ERROR: output file is required"
    exit 1
fi
if [[ ! -f "$input" ]]; then
    echo "ERROR: input file does not exist"
    exit 1
fi


# Build the standard obo file to a temp file
echo "==> BUILDING STANDARD OBO FILE..."
filter_argument=""
if [[ ! -z "$filter_institution" ]]; then
    filter_argument="-i $filter_institution"
fi
perl "$BUILD_SCRIPT" -o "$temp_file" -u $(whoami) $filter_argument --use-preferred-synonyms -v "$input"

# Convert to SGN obo file
namespace=$(cat "$temp_file" | grep ^default-namespace: | tr -s ' ' | cut -d ' ' -f 2)
echo "==> CONVERTING TO SGN OBO FILE [$output]..."
perl "$CONVERT_SCRIPT" -d "$namespace" -o "$output" -v "$temp_file"
rm "$temp_file"

# Generate trait props file
output_props="${output%.*}-props.xlsx"
echo "==> GENERATING TRAIT PROPS FILE [$output_props]..."
perl "$BUILD_PROPS_SCRIPT" -o "$output_props" $filter_argument -v "$input"


if [[ ! -z "$server_user" ]] && [[ ! -z "$server_host" ]] && [[ ! -z "$server_instance" ]]; then
    echo "==> UPDATING ONTOLOGY ON $server_host:$server_instance..."
    scp "$output" $server_user@$server_host:.ontology.obo
    scp "$output_props" $server_user@$server_host:.ontology-props.xlsx
    ssh -t $server_user@$server_host -C "breedbase update-traits $server_instance .ontology.obo .ontology-props.xlsx 2>&1"
fi