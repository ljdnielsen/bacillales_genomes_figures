#!/bin/bash

# Check if the input argument (directory path) is provided
if [ "$#" -ne 2 ]; then
    echo "Usage: $0 <input_directory> <output_directory>"
    exit 1
fi

# Assign the first argument to a variable
input_directory="$1"
output_directory="$2"

# Check if input_directory is a directory
if [ ! -d "$input_directory" ]; then
    echo "Error: '$input_directory' is not a valid directory."
    exit 1
fi

# Check if output_directory is a directory
if [ ! -d "$input_directory" ]; then
    echo "Error: '$input_directory' is not a valid directory."
    exit 1
fi

# Find and rename .fna files
find "$input_directory" -type f -name "*.fna" | while read file; do
    # Extract the directory path and the file name
    dir_path=$(dirname "$file")
    new_name=$(basename "$dir_path").fasta

    # Construct the new file path
    new_file_path="$output_directory/fasta/$new_name"

    # Move file to fasta directory
    echo "Moving $file to $new_file_path"
    mv "$file" "$new_file_path"
done

# Find and rename .gbff files
find "$input_directory" -type f -name "*.gbff" | while read file; do
    # Extract the directory path and the file name
    dir_path=$(dirname "$file")
    new_name=$(basename "$dir_path").gbff

    # Construct the new file path
    new_file_path="$output_directory/genbank/$new_name"

    # Move file to fasta directory
    echo "Moving $file to $new_file_path"
    mv "$file" "$new_file_path"
done
