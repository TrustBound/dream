# The requests of the README. integration/run-scenarios.sh runs them against
# the server and compares the output with readme_output.txt.
# All of these return 404
curl --path-as-is -s -o /dev/null -w "%{http_code}\n" http://localhost:3000/public/../../../etc/passwd
curl --path-as-is -s -o /dev/null -w "%{http_code}\n" http://localhost:3000/public/../../secrets
curl --path-as-is -s -o /dev/null -w "%{http_code}\n" http://localhost:3000/public/.env

curl http://localhost:3000/public/images/
