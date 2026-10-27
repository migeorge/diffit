APP      = DiffIt
BUNDLE   = dev.diffit.app
BUILD    = .build/release
APPDIR   = build/$(APP).app
VERSION ?= 0.1.0

.PHONY: build app install git-config test run

build:            ## release build of both executables
	swift build -c release

app: build        ## assemble build/DiffIt.app
	rm -rf $(APPDIR)
	mkdir -p $(APPDIR)/Contents/MacOS $(APPDIR)/Contents/Helpers $(APPDIR)/Contents/Resources
	cp $(BUILD)/DiffItApp $(APPDIR)/Contents/MacOS/$(APP)
	# The CLI lives in Helpers/: on a case-insensitive volume MacOS/diffit would clobber MacOS/DiffIt.
	cp $(BUILD)/diffit    $(APPDIR)/Contents/Helpers/diffit
	sed -e 's/@VERSION@/$(VERSION)/g' -e 's/@BUNDLE@/$(BUNDLE)/g' Resources/Info.plist > $(APPDIR)/Contents/Info.plist
	[ -f Resources/AppIcon.icns ] && cp Resources/AppIcon.icns $(APPDIR)/Contents/Resources/ || true
	codesign --force --deep --sign - $(APPDIR)

install: app      ## copy to /Applications and symlink the CLI
	rm -rf /Applications/$(APP).app && cp -R $(APPDIR) /Applications/
	mkdir -p $(HOME)/.local/bin
	ln -sf /Applications/$(APP).app/Contents/Helpers/diffit $(HOME)/.local/bin/diffit

git-config:       ## point git at the tool
	$(HOME)/.local/bin/diffit --git-config

# The Command Line Tools ship Swift Testing outside the default search path;
# without Xcode, `swift test` needs to be told where it is (see DECISIONS.md).
CLT_FRAMEWORKS = /Library/Developer/CommandLineTools/Library/Developer/Frameworks
TEST_FLAGS = -Xswiftc -F$(CLT_FRAMEWORKS) -Xswiftc -Xfrontend -Xswiftc -disable-cross-import-overlays -Xlinker -rpath -Xlinker $(CLT_FRAMEWORKS)

test:             ## run the unit tests (pass FILTER=Perf to select a suite)
	swift test $(TEST_FLAGS) $(if $(FILTER),--filter $(FILTER),)

run: app          ## launch the bundled app
	open $(APPDIR)
