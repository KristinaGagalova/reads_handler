#!/bin/bash

# Author: Kristina K. Gagalova
# Date: 24 Nov 2024
# Description: The script concatenates read libraries that have a similar prefix. Instead of doing that manually, it saves a lot of time if you have many files
# Advantage: Uses GNU parallel so that it's fast for multiple files.   
# Caveat: The script is hard coded for specific reads suffix, can be improved to be more dynamic. 

# Define the root directory containing the files (passed as a parameter to the script)
ROOT_DIR=$1

# File to store the list of merging jobs
LIST_FILE="merge_jobs_list.txt"  # Stores valid merge jobs
LIST_NOMERGE="Nomerge_jobs_list.txt"  # Stores jobs where no merging is required

# Clear the list files if they already exist to ensure fresh output
> "$LIST_FILE"  # Clear or create the file to store valid merge jobs
> "$LIST_NOMERGE"  # Clear or create the file to store non-mergeable entries

# Traverse the directory and process all gzipped `.fq.gz` files
find "$ROOT_DIR" -type f -name "*.fq.gz" | while read -r file; do
    dir=$(dirname "$file")  # Extract the directory containing the file
    # Extract the prefix by removing unique identifiers and lane information
    prefix=$(basename "$file" | sed -E 's/_[[:alnum:]]+_L[0-9]+_[12]\.fq\.gz//')  # High-level prefix
    suffix=$(basename "$file" | grep -oP '_[12]\.fq\.gz')  # Extract `_1` or `_2` suffix
    base_suffix=$(basename "$suffix" | grep -oP '[12]')  # Extract `1` or `2` from the suffix
    output_file="${dir}/${prefix}_merged_${base_suffix}.fq.gz"  # Define the output file for merging

    # Find all files matching the prefix and suffix, and sort them to ensure consistent order
    matching_files=$(find "$dir" -type f -name "${prefix}*${suffix}" | sort | tr '\n' ' ')

    # Write the merge job to the list if there are matching files
    if [[ ! -z "$matching_files" ]]; then
        echo "$matching_files$output_file" >> "$LIST_FILE"  # Write in the format: input1 input2 ... output
    fi
done

# Remove duplicate lines from the merge jobs list for clean processing
sort -u "$LIST_FILE" -o "$LIST_FILE"

# Split the `LIST_FILE` into two lists:
# - `LIST_FILE` retains only lines with 3 or more fields (valid merge jobs)
# - `LIST_NOMERGE` contains lines with fewer than 3 fields (no merging required)
awk 'NF < 3' "$LIST_FILE" > "$LIST_NOMERGE"  # Lines with less than 3 columns go to `LIST_NOMERGE`
awk 'NF >= 3' "$LIST_FILE" > tmp && mv tmp "$LIST_FILE"  # Retain only valid merge jobs in `LIST_FILE`

echo "Merge job list created at $LIST_FILE"

# Define a function to process each merge job
process_merge() {
    line="$1"  # Current line from `LIST_FILE`
    # Extract the output file (last column)
    output_file=$(echo "$line" | awk '{print $NF}')
    
    # Extract all input files (all columns except the last)
    input_files=$(echo "$line" | awk '{$NF=""; print $0}')

    # Merge input files using zcat, then compress and save as the output file
    echo "Merging files into $output_file"
    zcat $input_files | gzip > "$output_file"
}

export -f process_merge  # Export the function for use with GNU Parallel

# Use GNU Parallel to process each line in `LIST_FILE` concurrently
cat "$LIST_FILE" | parallel -j $(nproc) process_merge {}

echo "Merging completed."
