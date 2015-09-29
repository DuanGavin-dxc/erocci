REBAR_ROOT_DIR ?= .
REBAR_BUILD_DIR ?= _build/default

REBAR = $(REBAR_ROOT_DIR)/rebar3

PLUGIN = _build/default/plugins/econfig/ebin/econfig.app
REGISTRY = $(HOME)/.cache/rebar3/hex/default/registry

CONFIG ?= priv/configs/default.conf

all: compile

run:
	$(REBAR) shell --config $(CONFIG)

compile: template
	$(REBAR) compile

template: rebar.config rebar.lock
	$(REBAR) econfig template

configure: rebar.config rebar.lock
	$(REBAR) econfig configure

rebar.lock: rebar.config $(REGISTRY)
	$(REBAR) lock

$(REGISTRY):
	$(REBAR) update

clean:
	$(REBAR) clean
	$(REBAR) econfig clean
	-rm -f rebar.config.script

distclean:
	-rm -rf _build
	-rm -f rebar.lock

.PHONY: all template configure compile clean distclean