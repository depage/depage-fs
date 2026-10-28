.PHONY: build up test kill enter clean

COMPOSE ?= docker compose

build:
	$(COMPOSE) build

# start the mock server and copy its CA certificate out, so the tests
# (which run against the CA generated during the server image build)
# can verify it
up: build
	$(COMPOSE) up -d server
	-$(COMPOSE) cp server:/etc/ssl/private/ca.pem $(CURDIR)/ssl/

test: up
	$(COMPOSE) run --rm runner

kill:
	-$(COMPOSE) down --remove-orphans

enter:
	$(COMPOSE) exec server sh -c "export TERM=xterm && bash"

clean:
	-$(COMPOSE) down -v --rmi local --remove-orphans
