#!/bin/bash

# Script to replace white font colors with .fin1FontColor throughout the codebase
# This ensures consistency with the FontColor asset (#F5F5F5)

set -e

echo "🎨 Replacing white font colors with .fin1FontColor..."

# Directory to search (FIN1 source code)
SOURCE_DIR="FIN1"

# Find all Swift files (excluding build directories and backups)
find "$SOURCE_DIR" -type f -name "*.swift" ! -path "*/build/*" ! -name "*.backup" ! -path "*Tests/*" -print0 | while IFS= read -r -d '' file; do
    # Check if file contains white color usage for foreground
    if grep -q -E "(\.white|Color\.white)" "$file" && grep -q "foregroundColor" "$file"; then
        echo "  📝 Processing: $file"

        # Create a temporary file
        temp_file=$(mktemp)

        # Replace patterns:
        # 1. .foregroundColor(.white) → .foregroundColor(.fin1FontColor)
        # 2. .foregroundColor(.white.opacity(X)) → .foregroundColor(.fin1FontColor.opacity(X))
        # 3. .foregroundColor(Color.white) → .foregroundColor(.fin1FontColor)
        # 4. .foregroundColor(Color.white.opacity(X)) → .foregroundColor(.fin1FontColor.opacity(X))
        # 5. .foregroundColor(.white.opacity(X)) → .foregroundColor(.fin1FontColor.opacity(X))

        sed -E '
            # Handle .white with opacity
            s/\.foregroundColor\((\.white|Color\.white)\.opacity\(([^)]+)\)\)/.foregroundColor(.fin1FontColor.opacity(\2))/g

            # Handle .white without opacity (but only in foregroundColor context)
            s/\.foregroundColor\((\.white|Color\.white)\)/.foregroundColor(.fin1FontColor)/g

            # Handle standalone .white in foregroundColor that we might have missed
            s/foregroundColor\(\.white\)/foregroundColor(.fin1FontColor)/g
            s/foregroundColor\(Color\.white\)/foregroundColor(.fin1FontColor)/g
        ' "$file" > "$temp_file"

        # Check if file was actually modified
        if ! cmp -s "$file" "$temp_file"; then
            mv "$temp_file" "$file"
            echo "    ✅ Updated: $file"
        else
            rm "$temp_file"
            echo "    ⏭️  No changes needed: $file"
        fi
    fi
done

echo ""
echo "✨ Done! All white font colors have been replaced with .fin1FontColor"
echo "⚠️  Please review the changes and test the app to ensure proper contrast."



