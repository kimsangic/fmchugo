#!/bin/sh -x

# This script will parse a tree structure that is passed in on the command line looking for datasets

set -o errexit  # exit if any statement returns a non-true return value

# geta and gets are functions for printing out Yaml in Bash less than v4
geta() {
  local _ref=$1
  local -a _lines
  local _i
  local _leading_whitespace
  local _len

  IFS=$'\n' read -rd '' -a _lines ||:
  _leading_whitespace=${_lines[0]%%[^[:space:]]*}
  _len=${#_leading_whitespace}
  for _i in "${!_lines[@]}"; do
    eval "$(printf '%s+=( "%s" )' "$_ref" "${_lines[$_i]:$_len}")"
  done
}

gets() {
  local _ref=$1
  local -a _result
  local IFS

  geta _result
  IFS=$'\n'
  printf -v "$_ref" '%s' "${_result[*]}"
}

# echo "Check program requirements..."
# (
#   set +e
#   programs=( sed realpath find )
#   missing=0
#   for i in ${programs[@]}; do
#       command -v $i 2&> /dev/null
#       if [ $? -eq 0 ]; then
#           echo " * Found $i"
#       else
#           echo " * ERROR: missing $i"
#           missing=1
#       fi
#   done
#   if [[ "$missing" -ne 0 ]]; then
#       echo "Missing required commands"
#       exit 1
#   fi
# )

usage() {
  echo "`basename $0`"
  echo "   Usage: "
  echo "     [-d <input directory>] directory to search"
  echo "     [-o <output directory>] directory that files will be written to" 
  echo "     [-y] ignore prompt and just run"
  exit 1
}

# Catch any help requests
for arg in "$@"; do
  case "$arg" in
    --help| -h)
        usage
        ;;
  esac
done

while getopts :d:o:y option
do
  case "${option}"
  in
      d) INPUT_DIR=${OPTARG};;
      o) OUTPUT_DIR=${OPTARG};;
      y) IGNORE_PROMPT=true;;
      *) usage;;
  esac
done
shift "$(($OPTIND -1))"

if [ -z $INPUT_DIR ]; then
  echo "ERROR: Input directory required."
  exit 1
fi

if [ -z $OUTPUT_DIR ]; then
  echo "ERROR: Output directory required."
  exit 1
fi

# If parameters passed in don't exist get out
if ! [ -d $INPUT_DIR ]; then
  echo "ERROR: Input directory doesn't exist"
  exit 1
fi

# If parameters passed in don't exist get out
if ! [ -d $OUTPUT_DIR ]; then
  echo "ERROR: Output directory doesn't exist"
  exit 1
fi

echo "INPUT DIRECTORY:      $INPUT_DIR"
echo "OUTPUT DIRECTORY:     $OUTPUT_DIR"
if [ $IGNORE_PROMPT != "true" ]; then
  read -p "Are you sure you want to Proceed [y/N]?"
  if ! [[ "$REPLY" =~ ^[Yy]$ ]]; then
      echo "Maybe next time!"
      exit 1
  fi
fi

# Look for these types of Genomes.  This can obviously change depending on what you want to do
# I am taking a very simple approach to producing the markdown files in this POC and will only
# look in very specific locations.  This also assumes the data lives under a '/data' directory
# as is defined in the find command below
TYPES=( bacteria fungi insects plants )
WEB_ADDRESS="http://fmcbioinformatics.eastus2.cloudapp.azure.com"
for TYPE in "${TYPES[@]}"; do
  mkdir -p $OUTPUT_DIR/$TYPE
  while read -r COLLECTION; do
    if [ -z $COLLECTION ]; then
      break;
    fi
    if [ "$COLLECTION" != "." ]; then
      mkdir -p $OUTPUT_DIR/$TYPE/$COLLECTION
gets OUTPUT_MD <<'EOS'
---
title: \"$COLLECTION\"
fastqc_forward_reads: \"$WEB_ADDRESS/$TYPE/data/$COLLECTION/fastqc/${COLLECTION}_R1-final_fastqc.html\"
fastqc_reverse_reads: \"$WEB_ADDRESS/$TYPE/data/$COLLECTION/fastqc/${COLLECTION}_R2-final_fastqc.html\"
download_genome_sequences: \"$WEB_ADDRESS/$TYPE/data/$COLLECTION/prokka/$COLLECTION.fna\"
download_genbank: \"$WEB_ADDRESS/$TYPE/data/$COLLECTION/prokka/$COLLECTION.gbk\"
download_transcript_sequences: \"$WEB_ADDRESS/$TYPE/data/$COLLECTION/prokka/$COLLECTION.ffn\"
download_protein_sequences: \"$WEB_ADDRESS/$TYPE/data/$COLLECTION/prokka/$COLLECTION.faa\"
download_gene_feature: \"$WEB_ADDRESS/$TYPE/data/$COLLECTION/prokka/$COLLECTION.tsv\"
download_annotation: \"$WEB_ADDRESS/$TYPE/data/$COLLECTION/prokka/$COLLECTION.gff\"
statistics_quast: \"$WEB_ADDRESS/$TYPE/data/$COLLECTION/quast/report.html\"
statistics_busco: \"$WEB_ADDRESS/$TYPE/data/$COLLECTION/busco/short_summary.specific.bacteria_odb10.busco.txt\"
classification_phyloflash: \"$WEB_ADDRESS/$TYPE/data/$COLLECTION/phyloflash/$COLLECTION.phyloFlash.html\"
classification_kraken: \"$WEB_ADDRESS/$TYPE/data/$COLLECTION/kraken/$COLLECTION.kraken.report\"
classification_krona: \"$WEB_ADDRESS/$TYPE/data/$COLLECTION/krona/$COLLECTION.kraken.krona.html\"
classification_mash: \"$WEB_ADDRESS/$TYPE/data/$COLLECTION/mash/$COLLECTION.mash.txt\"
classification_mlst: \"$WEB_ADDRESS/$TYPE/data/$COLLECTION/mlst/$COLLECTION.mlst.txt\"
---
EOS
      printf '%s\n' "$OUTPUT_MD" > $OUTPUT_DIR/$TYPE/$COLLECTION/_index.md
    fi
  done <<< "$(find $INPUT_DIR/$TYPE/data \! -name .DS_Store -exec realpath --relative-to $INPUT_DIR/$TYPE/data {} \; | cut -d/ -f1 | uniq)"
done



