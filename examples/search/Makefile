# The tests of the guide "Add search to a Dream app"

.PHONY: test record

# Run the tests from the recordings, with no OpenSearch (CI runs the same
# script)
test:
	@sh scripts/playback.sh

# Record the OpenSearch calls again, with an OpenSearch node in Docker,
# which stops at the end
record:
	@sh scripts/record.sh
