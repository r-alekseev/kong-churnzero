DEV_ROCKS = "luacheck 0.20.0" "lua-llthreads2 0.1.4"
OPENSSL_DIR ?= /usr/local/opt/openssl

.PHONY: install dev lint test test-integration test-plugins test-all

install:
	@luarocks make OPENSSL_DIR=$(OPENSSL_DIR)

dev: install
	@for rock in $(DEV_ROCKS) ; do \
	  if luarocks list --porcelain $$rock | grep -q "installed" ; then \
	    echo $$rock already installed, skipping ; \
	  else \
	    echo $$rock not found, installing via luarocks... ; \
	    luarocks install $$rock ; \
	  fi \
	done;

lint:
	@luacheck -q .