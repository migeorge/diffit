APP      = DiffIt
BUNDLE   = dev.diffit.app
BUILD    = .build/release
UNIVERSAL = .build/apple/Products/Release
APPDIR   = build/$(APP).app
VERSION ?= 0.2.1
DIST     = build/$(APP)-$(VERSION).zip

.PHONY: build app bundle dist install test run

build:            ## release build of both executables
	swift build -c release

app: build bundle ## assemble build/DiffIt.app

bundle:           ## assemble build/DiffIt.app from $(BUILD) (no compile)
	rm -rf $(APPDIR)
	mkdir -p $(APPDIR)/Contents/MacOS $(APPDIR)/Contents/Helpers $(APPDIR)/Contents/Resources
	cp $(BUILD)/DiffItApp $(APPDIR)/Contents/MacOS/$(APP)
	# The CLI lives in Helpers/: on a case-insensitive volume MacOS/diffit would clobber MacOS/DiffIt.
	cp $(BUILD)/diffit    $(APPDIR)/Contents/Helpers/diffit
	sed -e 's/@VERSION@/$(VERSION)/g' -e 's/@BUNDLE@/$(BUNDLE)/g' Resources/Info.plist > $(APPDIR)/Contents/Info.plist
	[ -f Resources/AppIcon.icns ] && cp Resources/AppIcon.icns $(APPDIR)/Contents/Resources/ || true
	codesign --force --deep --sign - $(APPDIR)

# The CLI symlink and the git config are the user's in-app Install Command Line Tool action.
install: app      ## copy to /Applications
	rm -rf /Applications/$(APP).app && cp -R $(APPDIR) /Applications/

# Ad-hoc signed, not notarized: README explains clearing the quarantine flag after download.
dist:             ## universal (arm64 + x86_64) DiffIt.app zipped for a GitHub release
	swift build -c release --arch arm64 --arch x86_64
	$(MAKE) bundle BUILD=$(UNIVERSAL)
	rm -f $(DIST) && ditto -c -k --keepParent $(APPDIR) $(DIST)
	@echo "wrote $(DIST)"

# The Command Line Tools ship Swift Testing outside the default search path;
# without Xcode, `swift test` needs to be told where it is (see DECISIONS.md).
CLT_FRAMEWORKS = /Library/Developer/CommandLineTools/Library/Developer/Frameworks
TEST_FLAGS = -Xswiftc -F$(CLT_FRAMEWORKS) -Xswiftc -Xfrontend -Xswiftc -disable-cross-import-overlays -Xlinker -rpath -Xlinker $(CLT_FRAMEWORKS)

test:             ## run the unit tests (pass FILTER=Perf to select a suite)
	swift test $(TEST_FLAGS) $(if $(FILTER),--filter $(FILTER),)

run: app          ## launch the bundled app
	open $(APPDIR)
