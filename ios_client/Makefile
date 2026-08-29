# Makefile for compiling AuthGate.dylib (Clang or Theos)

TARGET = iphone:clang:latest:14.0
ARCHS = arm64

CC = xcrun -sdk iphoneos clang
CFLAGS = -arch arm64 -isysroot $(shell xcrun -sdk iphoneos --show-sdk-path) -miphoneos-version-min=14.0 -fobjc-arc -O3
LDFLAGS = -dynamiclib -framework Foundation -framework UIKit -framework Security -framework CoreGraphics

OUTPUT = AuthGate.dylib

all: $(OUTPUT)

$(OUTPUT): AuthGate.m
	$(CC) $(CFLAGS) $(LDFLAGS) -o $@ $<
	@echo "[+] Built $@ successfully."

clean:
	rm -f $(OUTPUT)
