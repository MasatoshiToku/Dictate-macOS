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
	mkdir -p "$(APP_BUNDLE)/Contents/Frameworks"
	cp "$(BINARY)" "$(APP_BUNDLE)/Contents/MacOS/$(PRODUCT_NAME)"
	cp Dictate/Info.plist "$(APP_BUNDLE)/Contents/"
	cp Dictate/Resources/icon.icns "$(APP_BUNDLE)/Contents/Resources/AppIcon.icns" 2>/dev/null || true
	# Copy Sparkle framework into the app bundle
	cp -R "$(BUILD_DIR)/Sparkle.framework" "$(APP_BUNDLE)/Contents/Frameworks/"
	# Add Frameworks rpath so the binary finds Sparkle at runtime
	install_name_tool -add_rpath "@executable_path/../Frameworks" "$(APP_BUNDLE)/Contents/MacOS/$(PRODUCT_NAME)" 2>/dev/null || true
	# Sign
	codesign --force --deep --sign - --entitlements Dictate/Dictate.entitlements "$(APP_BUNDLE)"
	@echo "Built $(APP_BUNDLE)"

install: bundle
	cp -R "$(APP_BUNDLE)" ~/Applications/
	@echo "Installed to ~/Applications/$(PRODUCT_NAME).app"

clean:
	swift package clean
	rm -rf .build
