.PHONY: test test/acceptance install-deps install
build: docs.json
	rm -rf release/*
	mkdir -p release/VirtualSpaces.spoon
	cp ./*.lua docs.json release/VirtualSpaces.spoon/
	cd release && zip -r VirtualSpaces.spoon.zip VirtualSpaces.spoon

install: build
	mkdir -p ~/.hammerspoon/Spoons
	rm -rf ~/.hammerspoon/Spoons/VirtualSpaces.spoon
	sed -i '' "s/Telemetry.new('VirtualSpaces', 'warning')/Telemetry.new('VirtualSpaces', 'debug')/" release/VirtualSpaces.spoon/init.lua
	cp -r release/VirtualSpaces.spoon ~/.hammerspoon/Spoons/

docs.json: init.lua
	mkdir -p .tmp
	cp *.lua .tmp/
	hs -c "hs.doc.builder.genJSON(\"$$(pwd)/.tmp\")" | grep -v "^--" > $@
	rm -rf .tmp

install-deps:
	luarocks install --local --only-deps virtualspaces-1.0-1.rockspec
	luarocks install --local luaunit

test:
	eval $$(luarocks --local path) && lua tests/test.lua -o TAP

.tags: **/*.lua
	ctags -R --exclude=.git --exclude=*.md --exclude=release --exclude=tests --exclude=docs.json -f .tags .

test/acceptance:
	./tests/acceptance.sh
