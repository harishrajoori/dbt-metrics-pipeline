#!/bin/bash

helpFunction()
{
   echo ""
   echo "Usage: $0 -u username"
   echo -e "\t-u your username"
   exit 1 # Exit script after printing help
}

while getopts "u:" opt
do
   case "$opt" in
      u ) username="$OPTARG" ;;
      ? ) helpFunction ;; # Print helpFunction in case parameter is non-existent
   esac
done

# Print helpFunction in case parameters are empty
if [ -z "$username" ]
then
   echo "Some or all of the username is empty";
   helpFunction
fi

echo "Username is $username"

export ARTIFACTORY_HTTP_URL=https://artifactory.example.com
ARTIFACTORY_USERNAME=$username
TEMP_PASSWORD=$(curl -X POST 'https://tokens.internal.services' -H 'content-type: application/json' -d '{ "username": "'"$ARTIFACTORY_USERNAME"'", "scope": "pypi" }')
ARTIFACTORY_PASSWORD=$TEMP_PASSWORD"%"
echo "Temparory token valid for 1 hour is: $ARTIFACTORY_PASSWORD"
echo -e "\n"

echo "Setting environment variables ARTIFACTORY_USERNAME, ARTIFACTORY_PASSWORD and ARTIFACTORY_URL"
export ARTIFACTORY_USERNAME=$ARTIFACTORY_USERNAME
export ARTIFACTORY_PASSWORD=$ARTIFACTORY_PASSWORD

echo -e "\n"
echo "Done."