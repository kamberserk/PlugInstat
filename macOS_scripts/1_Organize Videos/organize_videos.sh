#!/bin/bash

# Script to organize video files based on video_text.txt content
# Creates folders for each set play and moves matching MP4 files

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== Video File Organizer ===${NC}"
echo "Reading video_text.txt and organizing MP4 files..."
echo ""

# Check if video_text.txt exists
if [ ! -f "video_text.txt" ]; then
    echo -e "${RED}Error: video_text.txt not found in current directory${NC}"
    echo "Please ensure video_text.txt is in the same directory as this script"
    exit 1
fi

# Check if there are any MP4 files
mp4_count=$(find . -maxdepth 1 -name "*.mp4" | wc -l)
if [ $mp4_count -eq 0 ]; then
    echo -e "${YELLOW}Warning: No MP4 files found in current directory${NC}"
    echo "The script will create folders but won't move any files"
    echo ""
fi

# Initialize counters
folders_created=0
files_moved=0
errors=0

echo -e "${BLUE}Processing video_text.txt...${NC}"
echo ""

# Read video_text.txt line by line
while IFS= read -r line; do
    # Skip empty lines
    if [ -z "$line" ]; then
        continue
    fi
    
    # Parse the line: ID|Timeslot|SetPlay
    # Example: 1|1st quarter, 00:18 - 00:50|Diamond
    # Using pipe separator makes parsing much simpler
    
    # Split by pipe character
    id=$(echo "$line" | cut -d'|' -f1)
    timeslot=$(echo "$line" | cut -d'|' -f2)
    setplay=$(echo "$line" | cut -d'|' -f3)
    
    # Clean up the setplay (remove leading/trailing spaces)
    setplay=$(echo "$setplay" | xargs)
    
    # Skip if setplay is empty
    if [ -z "$setplay" ]; then
        echo -e "${YELLOW}Warning: Empty set play name for line: $line${NC}"
        continue
    fi
    
    echo -e "${BLUE}Processing: ID=$id, Timeslot=$timeslot, Set Play=$setplay${NC}"
    
    # Create folder for the set play if it doesn't exist
    if [ ! -d "$setplay" ]; then
        echo -e "${GREEN}Creating folder: $setplay${NC}"
        mkdir -p "$setplay"
        folders_created=$((folders_created + 1))
    else
        echo -e "${YELLOW}Folder already exists: $setplay${NC}"
    fi
    
    # Find MP4 files that match the timeslot pattern
    # Extract the timeslot part (e.g., "00:18 - 00:50")
    timeslot_pattern=$(echo "$timeslot" | grep -o '[0-9]\{2\}:[0-9]\{2\} - [0-9]\{2\}:[0-9]\{2\}')
    
    if [ -n "$timeslot_pattern" ]; then
        echo "Looking for MP4 files matching timeslot: $timeslot_pattern"
        
        # Normalize the timeslot pattern to match filename format
        # Convert: "09:03 - 22:00" to "9_3_-_22_0"
        # Remove leading zeros from minutes and seconds using awk for better precision
        normalized_pattern=$(echo "$timeslot_pattern" | awk -F' - ' '{
            split($1, start, ":")
            split($2, end, ":")
            start_min = start[1] + 0  # Convert to number to remove leading zeros
            start_sec = start[2] + 0
            end_min = end[1] + 0
            end_sec = end[2] + 0
            printf "%d_%d_-_%d_%d", start_min, start_sec, end_min, end_sec
        }')
        
        echo "Normalized pattern: $normalized_pattern"
        
        # Also normalize the quarter part to match filename format
        # Convert: "1st quarter" to "1st_quarter"
        normalized_quarter=$(echo "$timeslot" | sed 's/ /_/g')
        
        echo "Normalized quarter: $normalized_quarter"
        
        # Create more flexible patterns for better matching
        # Pattern 1: Just the time numbers with single digits (e.g., "9_3_-_22_0")
        time_only_pattern=$(echo "$timeslot_pattern" | awk -F' - ' '{
            split($1, start, ":")
            split($2, end, ":")
            start_min = start[1] + 0
            start_sec = start[2] + 0
            end_min = end[1] + 0
            end_sec = end[2] + 0
            printf "%d_%d_-_%d_%d", start_min, start_sec, end_min, end_sec
        }')
        
        # Pattern 2: Quarter with underscore (e.g., "1st_quarter")
        quarter_underscore=$(echo "$timeslot" | sed 's/ /_/g')
        
        # Pattern 3: Quarter without spaces (e.g., "1stquarter")
        quarter_no_space=$(echo "$timeslot" | sed 's/ //g')
        
        echo "Additional patterns:"
        echo "  Time only: $time_only_pattern"
        echo "  Quarter underscore: $quarter_underscore"
        echo "  Quarter no space: $quarter_no_space"
        
        # Find MP4 files with matching any of the patterns
        matching_files=$(find . -maxdepth 1 -name "*.mp4" | grep -E "($normalized_pattern|$normalized_quarter|$time_only_pattern|$quarter_underscore|$quarter_no_space)")
        
        if [ -n "$matching_files" ]; then
            echo -e "${GREEN}Found matching files:${NC}"
            while read -r file; do
                if [ -n "$file" ]; then
                    filename=$(basename "$file")
                    echo "  - $filename"
                    
                    # Move file to the set play folder
                    if mv "$file" "$setplay/"; then
                        echo -e "${GREEN}  ✓ Moved to $setplay/${NC}"
                        files_moved=$((files_moved + 1))
                    else
                        echo -e "${RED}  ✗ Failed to move $filename${NC}"
                        errors=$((errors + 1))
                    fi
                fi
            done <<< "$matching_files"
        else
            echo -e "${YELLOW}No MP4 files found matching patterns:${NC}"
            echo "  Timeslot pattern: $normalized_pattern"
            echo "  Quarter pattern: $normalized_quarter"
            echo "  Available MP4 files:"
            find . -maxdepth 1 -name "*.mp4" | head -5 | while read -r file; do
                echo "    - $(basename "$file")"
            done
        fi
    else
        echo -e "${YELLOW}Could not extract timeslot pattern from: $timeslot${NC}"
    fi
    
    echo ""
    
done < "video_text.txt"

# Summary
echo -e "${BLUE}=== Organization Complete ===${NC}"
echo -e "${GREEN}Folders created: $folders_created${NC}"
echo -e "${GREEN}Files moved: $files_moved${NC}"
if [ $errors -gt 0 ]; then
    echo -e "${RED}Errors encountered: $errors${NC}"
fi

echo ""
echo -e "${BLUE}Current directory structure:${NC}"
find . -type d -maxdepth 1 | sort

echo ""
echo -e "${BLUE}Files in each folder:${NC}"
for folder in */; do
    if [ -d "$folder" ]; then
        folder_name=$(basename "$folder")
        file_count=$(find "$folder" -name "*.mp4" | wc -l)
        echo -e "${GREEN}$folder_name/: $file_count MP4 files${NC}"
        if [ $file_count -gt 0 ]; then
            find "$folder" -name "*.mp4" -exec basename {} \; | sed 's/^/  /'
        fi
    fi
done

echo ""
echo -e "${GREEN}Organization complete!${NC}" 