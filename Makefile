.PHONY: build run clean bundle

PRODUCT_NAME = Dictate
BUILD_DIR = .build/release
APP_BUNDLE = $(BUILD_DIR)/$(PRODUCT_NAME).app
BINARY = $(BUILD_DIR)/$(PRODUCT_NAME)

build:
	swift build -c release

run:
	swift build && .build/debug/$(PRODUCT_NAME)

test:
	swift test

bundle: build
	mkdir -p "$(APP_BUNDLE)/Contents/MacOS"
	mkdir -p "$(APP_BUNDLE)/Contents/Resources"
	cp "$(BINARY)" "$(APP_BUNDLE)/Contents/MacOS/$(PRODUCT_NAME)"
	cp Dictate/Info.plist "$(APP_BUNDLE)/Contents/"
	# Copy entitlements
	codesign --force --sign - --entitlements Dictate/Dictate.entitlements "$(APP_BUNDLE)"
	@echo "Built $(APP_BUNDLE)"

install: bundle
	cp -R "$(APP_BUNDLE)" ~/Applications/
	@echo "Installed to ~/Applications/$(PRODUCT_NAME).app"

clean:
	swift package clean
	rm -rf .build
