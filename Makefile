# pam_watchid — universal-binary build for macOS 11+ (Apple Silicon + Intel)
#
# Edited from upstream insidegui/pam-watchid @ 64e64dd by hisgarden 2026-05-09:
#  - Original target was x86_64-apple-macosx10.15 only.
#  - Now builds a universal binary (arm64 + x86_64) for macOS 11.0+ (Big Sur,
#    the first arm64-capable macOS) via two `swiftc` passes + `lipo -create`.
#  - Adds `verify`, `sign`, `uninstall`, `clean` targets.
#  - Default `all` ad-hoc-signs the output so it loads under SIP without
#    requiring a Developer ID.
#
# Inputs:  watchid-pam-extension.swift
# Output:  pam_watchid.so (Mach-O fat: arm64 + x86_64), ad-hoc signed
# Install: /usr/local/lib/pam/pam_watchid.so.2 (root:wheel 0444)

VERSION = 2
LIBRARY_NAME = pam_watchid.so
DESTINATION = /usr/local/lib/pam
SOURCE = watchid-pam-extension.swift

# macOS 11.0 (Big Sur) is the floor — first arm64-capable macOS — and keeps both
# slices ABI-aligned on the LocalAuthentication framework surface.
MIN_MACOS = 11.0
TARGET_ARM64  = arm64-apple-macosx$(MIN_MACOS)
TARGET_X86_64 = x86_64-apple-macosx$(MIN_MACOS)

SWIFTFLAGS = -emit-library

all: $(LIBRARY_NAME)

$(LIBRARY_NAME): $(SOURCE)
	swiftc $(SOURCE) $(SWIFTFLAGS) -target $(TARGET_ARM64)  -o $(LIBRARY_NAME).arm64
	swiftc $(SOURCE) $(SWIFTFLAGS) -target $(TARGET_X86_64) -o $(LIBRARY_NAME).x86_64
	lipo -create $(LIBRARY_NAME).arm64 $(LIBRARY_NAME).x86_64 -output $(LIBRARY_NAME)
	rm -f $(LIBRARY_NAME).arm64 $(LIBRARY_NAME).x86_64
	codesign --force --sign - --timestamp=none $(LIBRARY_NAME)

verify: $(LIBRARY_NAME)
	@echo "── lipo -info ──"
	@lipo -info $(LIBRARY_NAME)
	@echo
	@echo "── codesign -dv ──"
	@codesign -dv $(LIBRARY_NAME) 2>&1 | head -10
	@echo
	@echo "── PAM symbols (arm64 slice) ──"
	@nm -arch arm64 -gU $(LIBRARY_NAME) 2>/dev/null | grep -E "pam_sm_" || echo "(no PAM symbols visible)"

install: $(LIBRARY_NAME)
	mkdir -p $(DESTINATION)
	install -m 0444 -o root -g wheel $(LIBRARY_NAME) $(DESTINATION)/$(LIBRARY_NAME).$(VERSION)

uninstall:
	rm -f $(DESTINATION)/$(LIBRARY_NAME).$(VERSION)

clean:
	rm -f $(LIBRARY_NAME) $(LIBRARY_NAME).arm64 $(LIBRARY_NAME).x86_64

.PHONY: all verify install uninstall clean
