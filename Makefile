.PHONY: test test/acceptance install-deps install
build: docs.json
	mkdir -p release/VirtualSpaces.spoon
	cp init.lua SpacesModel.lua WindowCache.lua WindowsSort.lua NativeSpaceManager.lua Telemetry.lua docs.json release/VirtualSpaces.spoon/
	cd release && zip -r VirtualSpaces.spoon.zip VirtualSpaces.spoon

install: build
	mkdir -p ~/.hammerspoon/Spoons
	rm -rf ~/.hammerspoon/Spoons/VirtualSpaces.spoon
	cp -r release/VirtualSpaces.spoon ~/.hammerspoon/Spoons/

docs.json: init.lua
	hs -c "hs.doc.builder.genJSON(\"$$(pwd)\")" | grep -v "^--" > $@

install-deps:
	luarocks install --local --only-deps virtualspaces-1.0-1.rockspec
	luarocks install --local luaunit

test:
	eval $$(luarocks --local path) && lua tests/test.lua -o TAP

.tags: **/*.lua
	ctags -R --exclude=.git --exclude=*.md --exclude=release --exclude=tests --exclude=docs.json -f .tags .

test/acceptance:
	./tests/acceptance.sh
