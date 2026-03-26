.PHONY: build run clean bundle dist

PRODUCT_NAME = Dictate
BUILD_DIR = .build/release
APP_BUNDLE = $(BUILD_DIR)/$(PRODUCT_NAME).app
BINARY = $(BUILD_DIR)/$(PRODUCT_NAME)

# Signing identity
SIGNING_IDENTITY = Developer ID Application: Masatoshi Toku (S4ZJX576ZP)
TEAM_ID = S4ZJX576ZP
BUNDLE_ID = io.dictate.app

build:
	swift build -c release -Xlinker -sectcreate -Xlinker __TEXT -Xlinker __info_plist -Xlinker Dictate/Info.plist

run:
	swift build -Xlinker -sectcreate -Xlinker __TEXT -Xlinker __info_plist -Xlinker Dictate/Info.plist && .build/debug/$(PRODUCT_NAME)

test:
	swift test

bundle: build
	mkdir -p "$(APP_BUNDLE)/Contents/MacOS"
	mkdir -p "$(APP_BUNDLE)/Contents/Resources"
	mkdir -p "$(APP_BUNDLE)/Contents/Frameworks"
	cp "$(BINARY)" "$(APP_BUNDLE)/Contents/MacOS/$(PRODUCT_NAME)"
	cp Dictate/Info.plist "$(APP_BUNDLE)/Contents/"
	cp Dictate/Resources/icon.icns "$(APP_BUNDLE)/Contents/Resources/AppIcon.icns" 2>/dev/null || true
	# Copy SPM resource bundle into Resources (for Bundle.module fallback)
	cp -R "$(BUILD_DIR)/Dictate_Dictate.bundle" "$(APP_BUNDLE)/Contents/Resources/" 2>/dev/null || true
	# Copy Sparkle framework into the app bundle
	cp -R "$(BUILD_DIR)/Sparkle.framework" "$(APP_BUNDLE)/Contents/Frameworks/"
	# Add Frameworks rpath so the binary finds Sparkle at runtime
	install_name_tool -add_rpath "@executable_path/../Frameworks" "$(APP_BUNDLE)/Contents/MacOS/$(PRODUCT_NAME)" 2>/dev/null || true
	# Sign with Developer ID + Hardened Runtime (required for notarization)
	codesign --force --deep --sign "$(SIGNING_IDENTITY)" --entitlements Dictate/Dictate.entitlements --options runtime "$(APP_BUNDLE)"
	@echo "Built $(APP_BUNDLE)"

# Distribution: sign, notarize, create DMG
dist: bundle
	@echo "Creating DMG..."
	hdiutil create -volname "$(PRODUCT_NAME)" -srcfolder "$(APP_BUNDLE)" -ov -format UDZO "$(BUILD_DIR)/$(PRODUCT_NAME).dmg"
	codesign --force --sign "$(SIGNING_IDENTITY)" "$(BUILD_DIR)/$(PRODUCT_NAME).dmg"
	@echo "Submitting for notarization..."
	xcrun notarytool submit "$(BUILD_DIR)/$(PRODUCT_NAME).dmg" --keychain-profile "notarytool-profile" --wait
	xcrun stapler staple "$(BUILD_DIR)/$(PRODUCT_NAME).dmg"
	@echo "Distribution ready: $(BUILD_DIR)/$(PRODUCT_NAME).dmg"

install: bundle
	cp -R "$(APP_BUNDLE)" /Applications/
	@echo "Installed to /Applications/$(PRODUCT_NAME).app"

clean:
	swift package clean
	rm -rf .build
