# Simple Makefile for building and running the myDay iOS app
#
# Usage:
#   make build   # Build the app
#   make run     # Build, then install+run on a connected iPhone (if available)
#   make clean   # Clean build products
#
# You can override most variables on the command line, e.g.:
#   make build SCHEME=MyOtherScheme CONFIGURATION=Release

# ---- Configuration ----

# Xcode project / workspace
PROJECT       ?= myDay.xcodeproj
# If you switch to a workspace, set WORKSPACE and clear PROJECT, e.g.:
# WORKSPACE   ?= myDay.xcworkspace

# Build settings
SCHEME        ?= myDay
CONFIGURATION ?= Debug
SDK           ?= iphoneos

# App metadata
APP_NAME      ?= myDay
BUNDLE_ID     ?= com.rest.myDay

# DerivedData path for repeatable builds
DERIVED_DATA_PATH ?= build

# Tooling
XCODEBUILD    ?= xcodebuild

# Detect a connected physical iPhone (non-simulator) using xctrace.
# This parses lines like:
#   Shresth (26.2.1) (00008130-001E4CC21E90001C)
# and extracts the UDID (last parenthesized token), ignoring simulators and Macs.
DEVICE_UDID := $(shell xcrun xctrace list devices 2>/dev/null | \
	awk '/^[[:space:]]*[^\[]+ \([0-9.]+\) \([0-9A-F-]+\)/ && $$0 !~ /Simulator/ && $$0 !~ /Mac/ {gsub(/[()]/, ""); print $$NF; exit}')

# Check whether devicectl is available (Xcode 15+)
HAS_DEVICECTL := $(shell xcrun -f devicectl >/dev/null 2>&1 && echo yes || echo no)

.PHONY: build run clean

# ---- Targets ----

build:
	@echo "Building $(SCHEME) for $(SDK) ($(CONFIGURATION))..."
	@set -e; \
	if [ -n "$(WORKSPACE)" ]; then \
		$(XCODEBUILD) -workspace "$(WORKSPACE)" -scheme "$(SCHEME)" -configuration "$(CONFIGURATION)" -sdk "$(SDK)" -derivedDataPath "$(DERIVED_DATA_PATH)" build; \
	else \
		$(XCODEBUILD) -project "$(PROJECT)" -scheme "$(SCHEME)" -configuration "$(CONFIGURATION)" -sdk "$(SDK)" -derivedDataPath "$(DERIVED_DATA_PATH)" build; \
	fi

run:
ifneq ($(DEVICE_UDID),)
	@echo "Found physical iPhone: $(DEVICE_UDID)"
	@$(MAKE) build
ifneq ($(HAS_DEVICECTL),yes)
	@echo "xcrun devicectl not available; built app but cannot auto-install/run."
else
	@echo "Installing $(APP_NAME).app on device $(DEVICE_UDID)..."
	@xcrun devicectl device install app --device "$(DEVICE_UDID)" "$(DERIVED_DATA_PATH)/Build/Products/$(CONFIGURATION)-iphoneos/$(APP_NAME).app"
	@echo "Launching $(BUNDLE_ID) on device $(DEVICE_UDID)..."
	@xcrun devicectl device process launch --device "$(DEVICE_UDID)" "$(BUNDLE_ID)" || true
endif
else
	@echo "No physical iPhone detected. Running build only..."
	@$(MAKE) build
endif

clean:
	@echo "Cleaning Xcode build products..."
	@set -e; \
	if [ -n "$(WORKSPACE)" ]; then \
		$(XCODEBUILD) -workspace "$(WORKSPACE)" -scheme "$(SCHEME)" -configuration "$(CONFIGURATION)" clean; \
	else \
		$(XCODEBUILD) -project "$(PROJECT)" -scheme "$(SCHEME)" -configuration "$(CONFIGURATION)" clean; \
	fi
	@rm -rf "$(DERIVED_DATA_PATH)"
