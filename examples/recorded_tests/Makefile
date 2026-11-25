# The tests of the guides about recorded HTTP calls and recorded queries

.PHONY: test record

# Run the tests from the recordings, with no network and no database (CI
# runs the same script)
test:
	@sh scripts/playback.sh

# Record the HTTP calls and the queries again, with a fake carrier API and
# a PostgreSQL server in Docker, which stops at the end
record:
	@sh scripts/record.sh
