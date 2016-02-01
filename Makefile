PACKAGE = ca-certificates
ORG = amylum

BUILD_DIR = /tmp/$(PACKAGE)-build
RELEASE_DIR = /tmp/$(PACKAGE)-release
RELEASE_FILE = /tmp/$(PACKAGE).tar.gz

VERSION_FILE = /tmp/ca-certificates/version
PACKAGE_VERSION = $$(cat $(VERSION_FILE))
PATCH_VERSION = $$(cat version)
VERSION = $(PACKAGE_VERSION)-$(PATCH_VERSION)

.PHONY : default build-container manual container build version push local

default: container

build-container:
	docker build -t ca-certificates-pkg meta/

manual: build-container
	./meta/launch /bin/bash || true

container: build-container
	./meta/launch

build: 
	rm -rf $(BUILD_DIR)
	mkdir -p $(BUILD_DIR)
	curl -so $(BUILD_DIR)/update-ca-trust 'https://projects.archlinux.org/svntogit/packages.git/plain/trunk/update-ca-trust?h=packages/ca-certificates'
	curl -so $(BUILD_DIR)/update-ca-trust.8.txt 'https://projects.archlinux.org/svntogit/packages.git/plain/trunk/update-ca-trust.8.txt?h=packages/ca-certificates'
	cd $(BUILD_DIR) && asciidoc.py -v -d manpage -b docbook update-ca-trust.8.txt
	cd $(BUILD_DIR) && xsltproc --nonet -o update-ca-trust.8 /etc/asciidoc/docbook-xsl/manpage.xsl update-ca-trust.8.xml
	mkdir -p $(RELEASE_DIR)/usr/{bin,share/man/man8}
	mkdir -p $(RELEASE_DIR)/{etc,usr/share}/$(PACKAGE)/trust-source/{anchors,blacklist}
	mkdir -p $(RELEASE_DIR)/etc/{ssl/certs/java,$(PACKAGE)/extracted}
	cp $(BUILD_DIR)/update-ca-trust $(RELEASE_DIR)/usr/bin/
	cp $(BUILD_DIR)/update-ca-trust.8 $(RELEASE_DIR)/usr/share/man/man8/
	ln -s ../$(PACKAGE)/extracted/tls-ca-bundle.pem $(RELEASE_DIR)/etc/ssl/cert.pem
	cd $(RELEASE_DIR) && tar -czvf $(RELEASE_FILE) *

version:
	curl -s https://www.archlinux.org/packages/core/any/ca-certificates/ | grep 'meta itemprop="version"' | sed 's/.*content="//;s/-.*//' > $(VERSION_FILE)
	echo $$(($(PATCH_VERSION) + 1)) > version

push: version
	git commit -am "$(VERSION)"
	ssh -oStrictHostKeyChecking=no git@github.com &>/dev/null || true
	git tag -f "$(VERSION)"
	git push --tags origin master
	@sleep 3
	targit -a .github -c -f $(ORG)/$(PACKAGE) $(VERSION) $(RELEASE_FILE)
	@sha512sum $(RELEASE_FILE) | cut -d' ' -f1

local: build push

