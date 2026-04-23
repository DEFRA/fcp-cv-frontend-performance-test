#!/bin/sh
set -x

echo "run_id: $RUN_ID in $ENVIRONMENT"

NOW=$(date +"%Y%m%d-%H%M%S")

if [ -z "${JM_HOME}" ]; then
  JM_HOME=/opt/perftest
fi

JM_SCENARIOS=${JM_HOME}/scenarios
JM_REPORTS=${JM_HOME}/reports
JM_LOGS=${JM_HOME}/logs

# Get an auth token
#auth_url=https://login.microsoftonline.com/${TENANT_ID:?required secret not set!}/oauth2/v2.0/token
#client_auth=`echo -n "${CLIENT_ID:?required secret not set!}:${CLIENT_SECRET:?required secret not set!}" | base64  | tr -d '\n'`

#content=`curl -s \
#  --connect-timeout 5 \
#  -x ${HTTP_PROXY:?required env var not set!} \
#  -L ${auth_url} \
# # -H "Authorization: Basic ${client_auth}" \
#  -H 'content-type: application/x-www-form-urlencoded' \
#  --data "username=${USER_NAME:?required username not set!}" \
#  --data "password=${USER_PASSWORD:?required user password not set!}" \
#  --data "client_id=${CLIENT_ID:?required client id not set!}" \
#  --data "client_secret=${CLIENT_SECRET:?required client secret not set!}" \
#  --data "grant_type=password" \
#  --data "scope=${CLIENT_SCOPE:?required secret not set!}"`
#auth_token=$( jq -r  '.access_token' <<< "${content}" )
#identity_token=$( jq -r  '.id_token' <<< "${content}" )

## fast-fail when no token available!
#if [ -z "${auth_token}" ] ; then
#  echo ERROR! Exiting because an auth token could not be retrieved
#  exit 2
#fi

mkdir -p ${JM_REPORTS} ${JM_LOGS}

TEST_SCENARIO=${TEST_SCENARIO:-test}
SCENARIOFILE=${JM_SCENARIOS}/${TEST_SCENARIO}.jmx
REPORTFILE=${NOW}-perftest-${TEST_SCENARIO}-report.csv
LOGFILE=${JM_LOGS}/perftest-${TEST_SCENARIO}.log

# Before running the suite, replace 'service-name' with the name/url of the service to test.
# ENVIRONMENT is set to the name of th environment the test is running in.
SERVICE_ENDPOINT=${SERVICE_ENDPOINT:-fcp-cv-frontend.${ENVIRONMENT}.cdp-int.defra.cloud}
# PORT is used to set the port of this performance test container
SERVICE_PORT=${SERVICE_PORT:-443}
SERVICE_URL_SCHEME=${SERVICE_URL_SCHEME:-https}

# Create file paths for environments
test_data_file_path="data/${ENVIRONMENT}/jmeter.config.testdata.csv"
test_paireddata_file_path="data/${ENVIRONMENT}/jmeter.config.pairedtestdata.csv"
land_data_file_path="data/${ENVIRONMENT}/jmeter.config.landdata.csv"

# Run the test suite
jmeter -n -t ${SCENARIOFILE} -e -l "${REPORTFILE}" -q user.properties -o ${JM_REPORTS} -j ${LOGFILE} -f \
-Jenv="${ENVIRONMENT}" \
-Jdomain="${SERVICE_ENDPOINT}" \
-Jport="${SERVICE_PORT}" \
-Jprotocol="${SERVICE_URL_SCHEME}" \
-JtestPairedDataFilePath="${test_paireddata_file_path}" \
-JlandDataFilePath="${land_data_file_path}" \
-JtestDataFilePath="${test_data_file_path}"
#-JauthToken="${auth_token}" \
#-JidentityToken="${identity_token}" \

# Publish the results into S3 so they can be displayed in the CDP Portal
if [ -n "$RESULTS_OUTPUT_S3_PATH" ]; then
  # Copy the CSV report file and the generated report files to the S3 bucket
   if [ -f "$JM_REPORTS/index.html" ]; then
      aws --endpoint-url=$S3_ENDPOINT s3 cp "$REPORTFILE" "$RESULTS_OUTPUT_S3_PATH/$REPORTFILE"
      aws --endpoint-url=$S3_ENDPOINT s3 cp "$JM_REPORTS" "$RESULTS_OUTPUT_S3_PATH" --recursive
      if [ $? -eq 0 ]; then
        echo "CSV report file and test results published to $RESULTS_OUTPUT_S3_PATH"
      fi
   else
      echo "$JM_REPORTS/index.html is not found"
      exit 1
   fi
else
   echo "RESULTS_OUTPUT_S3_PATH is not set"
   exit 1
fi

exit $test_exit_code
