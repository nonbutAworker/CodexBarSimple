.PHONY: build test check package run

build:
	swift build

test:
	swift test

check:
	swift format lint --recursive --strict Sources Tests
	swift build
	swift test

package:
	./Scripts/package_app.sh

run: package
	pkill -x CodexBarSimple || true
	open -n "$(CURDIR)/CodexBarSimple.app"
