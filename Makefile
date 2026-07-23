.PHONY: build run install clean

build:
	./scripts/build-app.sh

run: build
	open ./build/TabFlow.app

install: build
	pkill -f '/TabFlow.app/Contents/MacOS/TabFlow' 2>/dev/null || true
	rm -rf /Applications/TabFlow.app
	cp -R ./build/TabFlow.app /Applications/TabFlow.app
	open /Applications/TabFlow.app

clean:
	swift package clean
	rm -rf build
