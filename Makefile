.PHONY: format lint build test testplan

# Default: iPhone 16 + OS typical on current Xcode. Mirror CI exactly:
#   make IOS_SIM_DEST='platform=iOS Simulator,name=iPhone 16,OS=18.6' test
IOS_SIM_DEST ?= platform=iOS Simulator,name=iPhone 16,OS=18.6

format:
	swiftformat FIN1 FIN1Tests FIN1UITests FIN1InvestorTests FIN1CoreRegressionTests --lint || true

lint:
	swiftlint --strict || true

build:
	DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project FIN1.xcodeproj -scheme FIN1 -sdk iphonesimulator -configuration Debug -destination '$(IOS_SIM_DEST)' build | cat

test:
	DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project FIN1.xcodeproj -scheme FIN1 -sdk iphonesimulator -destination '$(IOS_SIM_DEST)' test | cat

testplan:
	DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project FIN1.xcodeproj -scheme FIN1 -testPlan FIN1 -destination '$(IOS_SIM_DEST)' test | cat

coverage:
	DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer ./scripts/generate-code-coverage.sh
