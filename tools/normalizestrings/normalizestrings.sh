#!/bin/bash

# Build ocstringstool
cd ../ocstringstool
./build_tool.sh
cd ../normalizestrings
mv ../ocstringstool/tool ./ocstringstool

# Perform normalization
./ocstringstool normalize ../../ownCloudSDK/Resources/ ../../ownCloudUI/Resources/

# Remove ocstringstool build
rm ./ocstringstool
