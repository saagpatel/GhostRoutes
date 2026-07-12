.PHONY: generate build test archive export-app-store clean

ARCHIVE_PATH ?= .derivedData/archives/GhostRoutes.xcarchive
EXPORT_PATH ?= .derivedData/exports/app-store-connect
PROVISIONING_UPDATE_FLAG ?=

generate:
	xcodegen generate

build: generate
	xcodebuild build -project GhostRoutes.xcodeproj -scheme GhostRoutes -configuration Debug -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO

test: generate
	SIMULATOR_ID="$$(xcrun simctl list devices available | sed -nE "/iPhone/ s/.*\(([0-9A-F-]{36})\).*/\1/p" | head -1)"; test -n "$$SIMULATOR_ID"; xcodebuild test -project GhostRoutes.xcodeproj -scheme GhostRoutes -destination "platform=iOS Simulator,id=$$SIMULATOR_ID" CODE_SIGNING_ALLOWED=NO

archive: generate
	xcodebuild archive -project GhostRoutes.xcodeproj -scheme GhostRoutes -configuration Release -destination 'generic/platform=iOS' -archivePath '$(ARCHIVE_PATH)'

export-app-store: archive
	xcodebuild -exportArchive -archivePath '$(ARCHIVE_PATH)' -exportPath '$(EXPORT_PATH)' -exportOptionsPlist ExportOptions.plist $(PROVISIONING_UPDATE_FLAG)

clean:
	xcodebuild clean -project GhostRoutes.xcodeproj -scheme GhostRoutes
