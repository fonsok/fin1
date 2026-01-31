#!/bin/bash

# Script to clean Xcode's derived data for the FIN1 project

# Default derived data location
DERIVED_DATA_DIR="$HOME/Library/Developer/Xcode/DerivedData"

echo "Cleaning Derived Data for FIN1..."

# Find FIN1 derived data folder
FIN1_FOLDERS=$(find "$DERIVED_DATA_DIR" -name "*FIN1*" -type d)

if [ -z "$FIN1_FOLDERS" ]; then
  echo "No FIN1 derived data folders found."
else
  echo "Found the following FIN1 derived data folders:"
  echo "$FIN1_FOLDERS"
  echo "Removing..."
  
  # Remove each folder
  for folder in $FIN1_FOLDERS; do
    rm -rf "$folder"
    echo "Removed: $folder"
  done
  
  echo "Derived data cleanup complete."
fi

echo "Done! Please rebuild your project in Xcode."
