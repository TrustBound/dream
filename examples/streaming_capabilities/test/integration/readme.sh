# The requests of the README. integration/run-scenarios.sh runs them against
# the server, in an empty folder, and compares the output with
# readme_output.txt. Each "echo" ends the line of a response that has no
# line break at its end.
# Create a test file
echo "Hello World from a large file" > test.txt

# Upload (streaming - no buffering)
curl -X POST --data-binary @test.txt http://localhost:3000/upload
echo

curl http://localhost:3000/download > output.txt
head -n 3 output.txt

curl -X POST -d "hello world" http://localhost:3000/echo_transform
echo

curl http://localhost:3000/proxy
echo

# The broken upload of docs/guides/streaming.md: a chunked body whose second
# chunk size is not a hex number. The server reads the first chunk, then
# fails the read, and the controller answers 400.
exec 3<>/dev/tcp/localhost/3000
printf 'POST /upload HTTP/1.1\r\nHost: localhost\r\nTransfer-Encoding: chunked\r\nConnection: close\r\n\r\n5\r\nhello\r\nzz\r\n' >&3
cat <&3
echo

# The files of the project structure in README.md
cd "$EXAMPLE"
find src -type f | sort
