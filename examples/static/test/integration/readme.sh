# The requests of the README. integration/run-scenarios.sh runs them against
# the server and compares the output with readme_output.txt.
# All of these return 404
curl --path-as-is -s -o /dev/null -w "%{http_code}\n" http://localhost:3000/public/../../../etc/passwd
curl --path-as-is -s -o /dev/null -w "%{http_code}\n" http://localhost:3000/public/../../secrets
curl --path-as-is -s -o /dev/null -w "%{http_code}\n" http://localhost:3000/public/.env

curl http://localhost:3000/public/images/

# The requests of docs/guides/responses.md. "echo" ends a response that has
# no line break at its end.
echo
curl -s -D - -o /dev/null http://localhost:3000/public/styles.css
curl -i http://localhost:3000/public/missing.css
echo
curl -i http://localhost:3000/custom/missing.css
echo

# The files that the guide serves, listed from the example's folder
cd "$EXAMPLE"
find public -type f | sort

# The files of the project structure in README.md
cd "$EXAMPLE"
find src assets -type f | sort
