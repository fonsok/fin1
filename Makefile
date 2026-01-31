.PHONY: format lint build test testplan

format:
	swiftformat . --lint || true

lint:
	swiftlint --strict || true

build:
	DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project FIN1.xcodeproj -scheme FIN1 -sdk iphonesimulator -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 15 Pro' build | cat

test:
	DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project FIN1.xcodeproj -scheme FIN1 -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 15 Pro' test | cat

testplan:
	DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project FIN1.xcodeproj -scheme FIN1 -testPlan FIN1 -destination 'platform=iOS Simulator,name=iPhone 15 Pro' test | cat

coverage:
	DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer ./scripts/generate-code-coverage.sh
