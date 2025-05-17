#!/usr/bin/env bash

# Copyright 2024 Nils Knieling. All Rights Reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# Create a on-demand self-hosted GitHub Actions Runner in Hetzner Cloud
# https://docs.hetzner.cloud/#servers-create-a-server

# Function to exit the script with a failure message
function exit_with_failure() {
	echo >&2 "FAILURE: $1"  # Print error message to stderr
	exit 1
}

# Define required commands
MY_COMMANDS=(
	base64
	curl
	cut
	envsubst
	jq
)
# Check if required commands are available
for MY_COMMAND in "${MY_COMMANDS[@]}"; do
	if ! command -v "$MY_COMMAND" >/dev/null 2>&1; then
		exit_with_failure "The command '$MY_COMMAND' was not found. Please install it."
	fi
done

# Check if files exist
MY_FILES=(
	"cloud-init.template.yml"
	"create-server.template.json"
	"install.sh"
)
# Check if required commands are available
for MY_FILE in "${MY_FILES[@]}"; do
	if [[ ! -f "$MY_FILE" ]]; then
		exit_with_failure "The file '$MY_FILE' was not found!"
	fi
done

#
# INPUT
#

# GitHub Actions inputs
# https://docs.github.com/en/actions/sharing-automations/creating-actions/metadata-syntax-for-github-actions#inputs
# When you specify an input, GitHub creates an environment variable for the input with the name INPUT_<VARIABLE_NAME>.

# Set the Hetzner Cloud API token.
# Retrieves the value from the INPUT_HCLOUD_TOKEN environment variable.
MY_HETZNER_TOKEN=${INPUT_HCLOUD_TOKEN}
if [[ -z "$MY_HETZNER_TOKEN" ]]; then
	exit_with_failure "Hetzner Cloud API token is not set."
fi

# Set the GitHub Personal Access Token (PAT).
# Retrieves the value from the INPUT_GITHUB_TOKEN environment variable.
MY_GITHUB_TOKEN=${INPUT_GITHUB_TOKEN}
if [[ -z "$MY_GITHUB_TOKEN" ]]; then
	exit_with_failure "GitHub Personal Access Token (PAT) token is required!"
fi

# Set the GitHub repository name.
# This retrieves the value from the GITHUB_ACTION_REPOSITORY environment variable,
# which is automatically set in GitHub Actions workflows.
# https://docs.github.com/en/actions/writing-workflows/choosing-what-your-workflow-does/store-information-in-variables#default-environment-variables
MY_GITHUB_REPOSITORY=${GITHUB_REPOSITORY}
if [[ -z "$MY_GITHUB_REPOSITORY" ]]; then
	exit_with_failure "GitHub repository is required!"
fi
# Set the repository owner's account ID (used for Hetzner Cloud Server label).
MY_GITHUB_REPOSITORY_OWNER_ID=${GITHUB_REPOSITORY_OWNER_ID:-"0"}
# Set The ID of the repository (used for Hetzner Cloud Server label).
MY_GITHUB_REPOSITORY_ID=${GITHUB_REPOSITORY_ID:-"0"}

# Specify here which mode you want to use (default: create):
# - create : Create a new runner
# - delete : Delete the previously created runner
# If INPUT_MODE is set, use its value; otherwise, use "create".
MY_MODE=${INPUT_MODE:-"create"}
if [[ "$MY_MODE" != "create" && "$MY_MODE" != "delete" ]]; then
	exit_with_failure "Mode must be 'create' or 'delete'."
fi

# Enable IPv4 (default: false)
# If INPUT_ENABLE_IPV4 is set, use its value; otherwise, use "false".
MY_ENABLE_IPV4=${INPUT_ENABLE_IPV4:-"true"}
if [[ "$MY_ENABLE_IPV4" != "true" && "$MY_ENABLE_IPV4" != "false" ]]; then
	exit_with_failure "Enable IPv4 must be 'true' or 'false'."
fi

# Enable IPv6 (default: true)
# If INPUT_ENABLE_IPV6 is set, use its value; otherwise, use "true".
MY_ENABLE_IPV6=${INPUT_ENABLE_IPV6:-"true"}
if [[ "$MY_ENABLE_IPV6" != "true" && "$MY_ENABLE_IPV6" != "false" ]]; then
	exit_with_failure "Enable IPv6 must be 'true' or 'false'."
fi

# Set the image to use for the instance (default: ubuntu-24.04)
# If INPUT_IMAGE is set, use its value; otherwise, use "ubuntu-24.04".
MY_IMAGE=${INPUT_IMAGE:-"ubuntu-24.04"}
# Check allowed characters
if [[ ! "$MY_IMAGE" =~ ^[a-zA-Z0-9\._-]{1,63}$ ]]; then
	exit_with_failure "'$MY_IMAGE' is not a valid OS image name!"
fi

# Set the location/region for the instance (default: nbg1)
# If INPUT_LOCATION is set, use its value; otherwise, use "nbg1".
MY_LOCATION=${INPUT_LOCATION:-"nbg1"}

# Set the name of the instance (default: gh-runner-$RANDOM)
# If INPUT_NAME is set, use its value; otherwise, generate a random name using "gh-runner-$RANDOM".
MY_NAME=${INPUT_NAME:-"gh-runner-$RANDOM"}
# Check allowed characters
if [[ ! "$MY_NAME" =~ ^[a-zA-Z0-9_-]{1,64}$ ]]; then
	exit_with_failure "'$MY_NAME' is not a valid hostname or label!"
fi
if [[ "$MY_NAME" == "hetzner" ]]; then
	exit_with_failure "'hetzner' is not allowed as hostname!"
fi

# Set the network for the instance (default: null)
# If INPUT_NETWORK is set, use its value; otherwise, use "null".
MY_NETWORK=${INPUT_NETWORK:-"null"}
# Check if MY_NETWORK is an integer
if [[ "$MY_NETWORK" != "null" && ! "$MY_NETWORK" =~ ^[0-9]+$ ]]; then
	exit_with_failure "The network ID must be 'null' or an integer!"
fi

# Set bash commands to run before the runner starts.
# If INPUT_PRE_RUNNER_SCRIPT is set, use its value; otherwise, use "".
MY_PRE_RUNNER_SCRIPT=${INPUT_PRE_RUNNER_SCRIPT:-""}

# Set the primary IPv4 address for the instance (default: null)
# If INPUT_PRIMARY_IPV4 is set, use its value; otherwise, use "null".
MY_PRIMARY_IPV4=${INPUT_PRIMARY_IPV4:-"null"}
# Check if MY_PRIMARY_IPV4 is an integer
if [[ "$MY_PRIMARY_IPV4" != "null" && ! "$MY_PRIMARY_IPV4" =~ ^[0-9]+$ ]]; then
	exit_with_failure "The primary IPv4 ID must be 'null' or an integer!"
fi

# Set the primary IPv6 address for the instance (default: null)
# If INPUT_PRIMARY_IPV6 is set, use its value; otherwise, use "null".
MY_PRIMARY_IPV6=${INPUT_PRIMARY_IPV6:-"null"}
# Check if MY_PRIMARY_IPV6 is an integer
if [[ "$MY_PRIMARY_IPV6" != "null" && ! "$MY_PRIMARY_IPV6" =~ ^[0-9]+$ ]]; then
	exit_with_failure "The primary IPv6 ID must be 'null' or an integer!"
fi

# Set the server type/instance type (default: cx22)
# If INPUT_SERVER_TYPE is set, use its value; otherwise, use "cx22".
MY_SERVER_TYPE=${INPUT_SERVER_TYPE:-"cx22"}

# Set maximal wait time (retries * 10 sec) for Hetzner Cloud Server (default: 30 [5 min])
# If INPUT_SERVER_WAIT is set, use its value; otherwise, use "30".
MY_SERVER_WAIT=${INPUT_SERVER_WAIT:-"30"}
# Check if MY_RUNNER_WAIT is an integer
if [[ ! "$MY_SERVER_WAIT" =~ ^[0-9]+$ ]]; then
	exit_with_failure "The maximum wait time (reties) for a running Hetzner Cloud Server must be an integer!"
fi

# Set the SSH key to use for the instance (default: null)
# If INPUT_SSH_KEY is set, use its value; otherwise, use "null".
MY_SSH_KEY=${INPUT_SSH_KEY:-"null"}
# Check if MY_SSH_KEY is an integer
if [[ "$MY_SSH_KEY" != "null" && ! "$MY_SSH_KEY" =~ ^[0-9]+$ ]]; then
	exit_with_failure "The SSH key ID must be 'null' or an integer!"
fi

# Set default GitHub Actions Runner installation directory (default: /actions-runner)
# If INPUT_RUNNER_DIR is set, its value is used. Otherwise, the default value "/actions-runner" is used.
MY_RUNNER_DIR=${INPUT_RUNNER_DIR:-"/actions-runner"}
# Check allowed characters
if [[ ! "$MY_RUNNER_DIR" =~ ^/([^/]+/)*[^/]+$ ]]; then
	exit_with_failure "'$MY_RUNNER_DIR' is not a valid absolute directory path without a trailing slash!"
fi

# Set default GitHub Actions Runner version (default: latest)
# If INPUT_RUNNER_VERSION is set, its value is used. Otherwise, the default value "latest" is used.
# Releases: https://github.com/actions/runner/releases
MY_RUNNER_VERSION=${INPUT_RUNNER_VERSION:-"latest"}
# Check allowed values
if [[ "$MY_RUNNER_VERSION" != "latest" && "$MY_RUNNER_VERSION" != "skip" && ! "$MY_RUNNER_VERSION" =~ ^[0-9\.]{1,63}$ ]]; then
	exit_with_failure "'$MY_RUNNER_VERSION' is not a valid GitHub Actions Runner version! Enter 'latest', 'skip' or the version without 'v'."
fi

# Set maximal wait time (retries * 10 sec) for GitHub Actions Runner registration (default: 60 [10 min])
# If INPUT_RUNNER_WAIT is set, use its value; otherwise, use "60".
MY_RUNNER_WAIT=${INPUT_RUNNER_WAIT:-"60"}
# Check if MY_RUNNER_WAIT is an integer
if [[ ! "$MY_RUNNER_WAIT" =~ ^[0-9]+$ ]]; then
	exit_with_failure "The maximum wait time (retries) for GitHub Action Runner registration must be an integer!"
fi

# Set maximal wait time (retries * 10 sec) for Hetzner Server creation (default: 360 [1 hour])
# If INPUT_CREATE_WAIT is set, use its value; otherwise, use "360".
MY_CREATE_WAIT=${INPUT_CREATE_WAIT:-360}
if [[ ! "$MY_CREATE_RETRIES" =~ ^[0-9]+$ ]]; then
	exit_with_failure "The maximum wait time (retries) for Hetzner Server creation must be an integer!"
fi

# Set Hetzner Cloud Server ID
MY_HETZNER_SERVER_ID=${INPUT_SERVER_ID}


#
# DELETE
#

if [[ "$MY_MODE" == "delete" ]]; then
	# Check if MY_HETZNER_SERVER_ID is an integer
	if [[ ! "$MY_HETZNER_SERVER_ID" =~ ^[0-9]+$ ]]; then
		exit_with_failure "Failed to get ID of the Hetzner Cloud Server!"
	fi

	# Send a DELETE request to the Hetzner Cloud API to delete the server.
	# https://docs.hetzner.cloud/#servers-delete-a-server
	echo "Delete server..."
	curl \
		-X DELETE \
		--fail-with-body \
		-H "Content-Type: application/json" \
		-H "Authorization: Bearer ${MY_HETZNER_TOKEN}" \
		"https://api.hetzner.cloud/v1/servers/$MY_HETZNER_SERVER_ID" \
		|| exit_with_failure "Error deleting server!"
	echo "Hetzner Cloud Server deleted successfully."

	# List self-hosted runners for repository
	# https://docs.github.com/en/rest/actions/self-hosted-runners?apiVersion=2022-11-28#list-self-hosted-runners-for-a-repository
	echo "List self-hosted runners..."
	curl -L \
		--fail-with-body \
		-o "github-runners.json" \
		-H "Accept: application/vnd.github+json" \
		-H "Authorization: Bearer ${MY_GITHUB_TOKEN}" \
		-H "X-GitHub-Api-Version: 2022-11-28" \
		"https://api.github.com/repos/${MY_GITHUB_REPOSITORY}/actions/runners" \
		|| exit_with_failure "Failed to list GitHub Actions runners from repository!"

	MY_GITHUB_RUNNER_ID=$(jq -er ".runners[] | select(.name == \"$MY_NAME\") | .id" < "github-runners.json")
	# Check if MY_GITHUB_RUNNER_ID is an integer
	if [[ ! "$MY_GITHUB_RUNNER_ID" =~ ^[0-9]+$ ]]; then
		exit_with_failure "Failed to get ID of the GitHub Actions Runner!"
	fi

	# Delete a self-hosted runner from repository
	# https://docs.github.com/en/rest/actions/self-hosted-runners?apiVersion=2022-11-28#delete-a-self-hosted-runner-from-a-repository
	echo "Delete GitHub Actions Runner..."
	curl -L \
		-X DELETE \
		--fail-with-body \
		-H "Accept: application/vnd.github+json" \
		-H "Authorization: Bearer ${MY_GITHUB_TOKEN}" \
		-H "X-GitHub-Api-Version: 2022-11-28" \
		"https://api.github.com/repos/${MY_GITHUB_REPOSITORY}/actions/runners/${MY_GITHUB_RUNNER_ID}" \
		|| exit_with_failure "Failed to delete GitHub Actions Runner from repository! Please delete manually: https://github.com/${MY_GITHUB_REPOSITORY}/settings/actions/runners"
	echo "GitHub Actions Runner deleted successfully."
	echo
	echo "The Hetzner Cloud Server and its associated GitHub Actions Runner have been deleted successfully."
	# Add GitHub Action job summary 
	# https://docs.github.com/en/actions/writing-workflows/choosing-what-your-workflow-does/workflow-commands-for-github-actions#adding-a-job-summary
	echo "The Hetzner Cloud Server and its associated GitHub Actions Runner have been deleted successfully 🗑️" >> "$GITHUB_STEP_SUMMARY"
	exit 0
fi

#
# CREATE
#

# Create GitHub Actions registration token for registering a self-hosted runner to a repository
# https://docs.github.com/en/rest/actions/self-hosted-runners#create-a-registration-token-for-a-repository
echo "Create GitHub Actions Runner registration token..."
curl -L \
	-X "POST" \
	--fail-with-body \
	-o "registration-token.json" \
	-H "Accept: application/vnd.github+json" \
	-H "Authorization: Bearer ${MY_GITHUB_TOKEN}" \
	-H "X-GitHub-Api-Version: 2022-11-28" \
	"https://api.github.com/repos/${MY_GITHUB_REPOSITORY}/actions/runners/registration-token" \
	|| exit_with_failure "Failed to retrieve GitHub Actions Runner registration token!"

# Read the GitHub Runner registration token from a file (assuming valid JSON)
MY_GITHUB_RUNNER_REGISTRATION_TOKEN=$(jq -er '.token' < "registration-token.json")

# Encode the contents of the "install.sh" and runner script into base64
# BSD
if [[ "$OSTYPE" == "darwin"* || "$OSTYPE" == "freebsd"* ]]; then
	MY_INSTALL_SH_BASE64=$(base64 < "install.sh")
	MY_PRE_RUNNER_SCRIPT_BASE64=$(echo "$MY_PRE_RUNNER_SCRIPT" | base64)
# GNU Core tools
else
	MY_INSTALL_SH_BASE64=$(base64 --wrap=0 < "install.sh")
	MY_PRE_RUNNER_SCRIPT_BASE64=$(echo "$MY_PRE_RUNNER_SCRIPT" | base64 --wrap=0)
fi
# Split repository into owner and repository name
MY_GITHUB_OWNER="${MY_GITHUB_REPOSITORY%/*}"   # Extract the part before the last /
MY_GITHUB_REPO_NAME="${MY_GITHUB_REPOSITORY##*/}"   # Extract the part after the last /

# Export environment variables for use in the cloud-init template
export MY_GITHUB_OWNER
export MY_GITHUB_REPO_NAME
export MY_GITHUB_REPOSITORY
export MY_GITHUB_RUNNER_REGISTRATION_TOKEN
export MY_INSTALL_SH_BASE64
export MY_NAME
export MY_PRE_RUNNER_SCRIPT_BASE64
export MY_RUNNER_DIR
export MY_RUNNER_VERSION
# Substitute environment variables in the cloud-init template and create the final cloud-init configuration
if [[ ! -f "cloud-init.template.yml" ]]; then
	exit_with_failure "cloud-init.template.yml not found!"
fi
envsubst < cloud-init.template.yml > cloud-init.yml

# Generate the create-server.json file by populating the create-server.template.json template with variables.
# This uses jq to construct a JSON object based on the template and provided arguments.
# Optimize values for valid labels: https://docs.hetzner.cloud/#labels
echo "Generate server configuration..."
jq -n \
	--arg     location        "$MY_LOCATION" \
	--arg     runner_version  "$MY_RUNNER_VERSION" \
	--arg     github_owner_id "$MY_GITHUB_REPOSITORY_OWNER_ID" \
	--arg     github_repo_id  "$MY_GITHUB_REPOSITORY_ID" \
	--arg     image           "$MY_IMAGE" \
	--arg     server_type     "$MY_SERVER_TYPE" \
	--arg     name            "$MY_NAME" \
	--argjson enable_ipv4     "$MY_ENABLE_IPV4" \
	--argjson enable_ipv6     "$MY_ENABLE_IPV6" \
	--rawfile cloud_init_yml  "cloud-init.yml" \
	-f create-server.template.json > create-server.json \
	|| exit_with_failure "Failed to generate create-server.json!"
# Add the primary IPv4 address if available (not "null")
if [[ "$MY_PRIMARY_IPV4" != "null" ]]; then
	cp create-server.json create-server-ipv4.json && \
	jq ".public_net.ipv4 = $MY_PRIMARY_IPV4" < create-server-ipv4.json > create-server.json && \
	echo "Primary IPv4 ID added to create-server.json."
fi
# Add the primary IPv6 address if available (not "null")
if [[ "$MY_PRIMARY_IPV6" != "null" ]]; then
	cp create-server.json create-server-ipv6.json && \
	jq ".public_net.ipv6 = $MY_PRIMARY_IPV6" < create-server-ipv6.json > create-server.json && \
	echo "Primary IPv6 ID added to create-server.json."
fi
# Add SSH key configuration to the create-server.json file if MY_SSH_KEY is not "null".
if [[ "$MY_SSH_KEY" != "null" ]]; then
	cp create-server.json create-server-ssh.json && \
	jq ".ssh_keys += [$MY_SSH_KEY]" < create-server-ssh.json > create-server.json && \
	echo "SSH key added to create-server.json."
fi
# Add network configuration to the create-server.json file if MY_NETWORK is not "null".
if [[ "$MY_NETWORK" != "null" ]]; then
	cp create-server.json create-server-network.json && \
	jq ".networks += [$MY_NETWORK]" < create-server-network.json > create-server.json && \
	echo "Network added to create-server.json."
fi

# Send a POST request to the Hetzner Cloud API to create a server.
# https://docs.hetzner.cloud/#servers-create-a-server
MAX_RETRIES=$MY_CREATE_WAIT
RETRY_COUNT=0
WAIT_SEC=10
while [[ $RETRY_COUNT -lt $MAX_RETRIES ]]; do
	echo "Create Server..."
	if curl \
	-X POST \
	--fail-with-body \
	-o "servers.json" \
	-H "Content-Type: application/json" \
	-H "Authorization: Bearer ${MY_HETZNER_TOKEN}" \
	-d @create-server.json \
	"https://api.hetzner.cloud/v1/servers"; then
		echo "Server created successfully."
		break
	else
		# Check if the error is related to resource unavailability
		if grep -q -E "resource_unavailable|resource_limit_exceeded" "servers.json"; then
  			echo "Resource limitation detected."
                # If error is not resource-related, don't retry
	 	else
            		cat "servers.json"
  			exit_with_failure "Failed to create Server in Hetzner Cloud!"
        	fi
	fi

	RETRY_COUNT=$((RETRY_COUNT + 1)) # Increment retry counter

	echo "Failed to create Server. Wait $WAIT_SEC seconds... (Attempt $RETRY_COUNT/$MAX_RETRIES)"
	sleep "$WAIT_SEC"
done

# Get the Hetzner Server ID from the JSON response (assuming valid JSON)
MY_HETZNER_SERVER_ID=$(jq -er '.server.id' < "servers.json")

# Check if MY_HETZNER_SERVER_ID is an integer
if [[ ! "$MY_HETZNER_SERVER_ID" =~ ^[0-9]+$ ]]; then
	exit_with_failure "Failed to get ID of the Hetzner Cloud Server!"
fi

# Set GitHub Action output
# https://github.blog/changelog/2022-10-11-github-actions-deprecating-save-state-and-set-output-commands/
#echo "::set-output name=label::$MY_NAME"
#echo "::set-output name=server_id::$MY_HETZNER_SERVER_ID"
echo "label=$MY_NAME" >> "$GITHUB_OUTPUT"
echo "server_id=$MY_HETZNER_SERVER_ID" >> "$GITHUB_OUTPUT"

# Wait for server
MAX_RETRIES=$MY_SERVER_WAIT
RETRY_COUNT=0
echo "Wait for server..."
while [[ $RETRY_COUNT -lt $MAX_RETRIES ]]; do
	# Download and parse server status
	# https://docs.hetzner.cloud/#servers-get-a-server
	curl -s \
		-o "servers.json" \
		-H "Content-Type: application/json" \
		-H "Authorization: Bearer ${MY_HETZNER_TOKEN}" \
		"https://api.hetzner.cloud/v1/servers/$MY_HETZNER_SERVER_ID" \
		|| exit_with_failure "Failed to get status of the Hetzner Cloud Server!"

	MY_HETZNER_SERVER_STATUS=$(jq -er '.server.status' < "servers.json")

	# Check if server is running
	if [[ "$MY_HETZNER_SERVER_STATUS" == "running" ]]; then
		echo "Server is running."
		break
	fi

	RETRY_COUNT=$((RETRY_COUNT + 1)) # Increment retry counter

	echo "Server is not running yet. Waiting $WAIT_SEC seconds... (Attempt $RETRY_COUNT/$MAX_RETRIES)"
	sleep "$WAIT_SEC"
done
if [[ "$MY_HETZNER_SERVER_STATUS" != "running" ]]; then
	exit_with_failure "Failed to start Hetzner Cloud Server! Please check manually."
fi

# Wait for GitHub Actions Runner registration
MAX_RETRIES=$MY_RUNNER_WAIT
RETRY_COUNT=0
echo "Wait for GitHub Actions Runner registration..."
while [[ $RETRY_COUNT -lt $MAX_RETRIES ]]; do
	# List self-hosted runners for repository
	# https://docs.github.com/en/rest/actions/self-hosted-runners?apiVersion=2022-11-28#list-self-hosted-runners-for-a-repository
	curl -L -s \
		-o "github-runners.json" \
		-H "Accept: application/vnd.github+json" \
		-H "Authorization: Bearer ${MY_GITHUB_TOKEN}" \
		-H "X-GitHub-Api-Version: 2022-11-28" \
		"https://api.github.com/repos/${MY_GITHUB_REPOSITORY}/actions/runners" \
		|| exit_with_failure "Failed to list GitHub Actions runners from repository!"

	MY_GITHUB_RUNNER_ID=$(jq -er ".runners[] | select(.name == \"$MY_NAME\") | .id" < "github-runners.json")
	# Check if MY_GITHUB_RUNNER_ID is an integer
	if [[ "$MY_GITHUB_RUNNER_ID" =~ ^[0-9]+$ ]]; then
		echo "GitHub Actions Runner registered."
		break
	fi

	RETRY_COUNT=$((RETRY_COUNT + 1)) # Increment retry counter

	echo "GitHub Actions Runner is not yet registered. Wait $WAIT_SEC seconds... (Attempt $RETRY_COUNT/$MAX_RETRIES)"
	sleep "$WAIT_SEC"
done
if [[ ! "$MY_GITHUB_RUNNER_ID" =~ ^[0-9]+$ ]]; then
	exit_with_failure "GitHub Actions Runner is not registered. Please check installation manually."
fi

echo
echo "The Hetzner Cloud Server and its associated GitHub Actions Runner are ready for use." 
echo "Runner: https://github.com/${MY_GITHUB_REPOSITORY}/settings/actions/runners/${MY_GITHUB_RUNNER_ID}"
# Add GitHub Action job summary 
# https://docs.github.com/en/actions/writing-workflows/choosing-what-your-workflow-does/workflow-commands-for-github-actions#adding-a-job-summary
echo "The Hetzner Cloud Server and its associated [GitHub Actions Runner](https://github.com/${MY_GITHUB_REPOSITORY}/settings/actions/runners/${MY_GITHUB_RUNNER_ID}) are ready for use 🚀" >> "$GITHUB_STEP_SUMMARY"
exit 0
