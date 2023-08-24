#!/bin/bash

# Build ocstringstool
cd ../ocstringstool
./build_tool.sh
cd ../normalizestrings
mv ../ocstringstool/tool ./ocstringstool
chmod u+x ./ocstringstool

# Perform normalization
echo "Normalizing…"
./ocstringstool normalize ../../ownCloudSDK/Resources/ ../../ownCloudUI/Resources/ 

# Remove ocstringstool build
rm ./ocstringstool

echo "Done."

