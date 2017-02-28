.PHONY: clean build test

PROJDIR := $(realpath $(CURDIR))
MIX_VERSION := $(shell mix -v)
REBAR ?= $(PROJDIR)/rebar

all: clean test

clean:
	$(REBAR) clean

build:
	$(REBAR) compile xref

test: build
	$(REBAR) -C test.config get-deps compile
	$(REBAR) -C test.config skip_deps=true ct

release: clean build
ifeq ($(VERSION),)
	$(error VERSION must be set to build a release and deploy this package)
endif
ifeq ($(RELEASE_GPG_KEYNAME),)
	$(error RELEASE_GPG_KEYNAME must be set to build a release and deploy this package)
endif
ifeq ($(MIX_VERSION),)
	$(error The mix command is required to publish to hex.pm)
endif
	echo "==> Tagging version $(VERSION)"
	echo -n "$(VERSION)" > VERSION
	git add --force VERSION
	git commit --message="basho-hamcrest $(VERSION)"
	git push
	git tag --sign -a "$(VERSION)" -m "basho-hamcrest $(VERSION)" --local-user "$(RELEASE_GPG_KEYNAME)"
	git push --tags
	mix deps.get
	mix hex.publish
