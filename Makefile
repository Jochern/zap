APP_NAME = Zap
BUILD_DIR = .build/release
APP_BUNDLE = $(BUILD_DIR)/$(APP_NAME).app

.PHONY: build bundle dmg install clean

build:
	swift build -c release

bundle: build
	rm -rf $(APP_BUNDLE)
	mkdir -p $(APP_BUNDLE)/Contents/MacOS
	mkdir -p $(APP_BUNDLE)/Contents/Resources
	cp $(BUILD_DIR)/$(APP_NAME) $(APP_BUNDLE)/Contents/MacOS/$(APP_NAME)
	cp Info.plist $(APP_BUNDLE)/Contents/Info.plist
	@echo "$(APP_BUNDLE) created"

dmg: bundle
	rm -f $(BUILD_DIR)/$(APP_NAME).dmg
	hdiutil create -volname $(APP_NAME) -srcfolder $(APP_BUNDLE) -ov -format UDZO $(BUILD_DIR)/$(APP_NAME).dmg
	@echo "$(BUILD_DIR)/$(APP_NAME).dmg created"

install: bundle
	cp -r $(APP_BUNDLE) /Applications/$(APP_NAME).app
	@echo "Installed to /Applications/$(APP_NAME).app"

clean:
	swift package clean
	rm -rf $(APP_BUNDLE) $(BUILD_DIR)/$(APP_NAME).dmg
