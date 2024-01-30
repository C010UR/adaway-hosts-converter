#!/bin/bash

# Check if the input file name is provided
if [ $# -ne 1 ]; then
    echo "Usage: $0 input_urls.txt"
    exit 1
fi

# Read the input file line by line
while IFS= read -r url; do
    echo -n "$url"

    filename=$(basename $(dirname $url))
    filename="$filename.txt"

    truncate -s 0 $filename

    curl -s "$url" | while IFS= read -r line; do
        echo "0.0.0.0 $line" >>$filename
    done

    echo " -> $filename.txt"

done <"$1"
