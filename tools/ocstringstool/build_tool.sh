#!/bin/bash

# Build ocstringstool
xcodebuild \
-project ocstringstool.xcodeproj \
-scheme ocstringstool \
-configuration Release \
-derivedDataPath \
build

cp build/Build/Products/Release/ocstringstool ./tool
rm -rf build
