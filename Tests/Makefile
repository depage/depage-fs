RM = rm -rf

.PHONY: test server clean

# run the phpunit test suite inside the runner container against the
# mock server container (see docker/docker-compose.yml)
test:
	$(MAKE) -C docker test

# only start the mock server container (useful for debugging)
server:
	$(MAKE) -C docker up

clean:
	$(RM) Report Temp .phpunit.cache docker/ssl/ca.pem
	$(MAKE) clean -C docker
