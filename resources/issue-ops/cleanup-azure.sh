#!/bin/bash

# halt the script on an error
set -e

## In case of an error, print abortion
trap 'echo "Aborting due to error on line $LINENO. Exit code: $?" >&2' ERR

## Make sure thse are the same as in ./prepare-azure.sh
SERVICE_PRINCIPAL_NAME="GitHub Actions Workshop Administrator"
FEDERATED_CREDENTIALS_NAME="app-registration-credentials"
AD_ROLE_NAME="Cloud Application Administrator"
ADMIN_ROLE_NAME="GitHub Actions Workshop Administrator Role"
PARTICIPANTS_ROLE_NAME="GitHub Actions Workshop Participants Role"

function removeActionWorkshopDeployments() {
	# Find all Resource Groups of the workshop by Tag
	RESOURCE_GROUPS=$(az group list --query "[?tags.purpose=='GitHub Actions Workshop'].name" -o tsv)

	if [[ -n "${RESOURCE_GROUPS}" ]]; then
		echo "The following, action workshop realted Resource Groups will be deleted:"
		echo ${RESOURCE_GROUPS}
		read -p "Are you sure you want to delete these Resource Groups? (y/n) " -n 1 -r

		## Exit if the user did not confirm
		if [[ ! $REPLY =~ ^[Yy]$ ]]; then
			echo "Aborting..."
			exit 1
		fi
		
		echo ""

		## Loop over all Resource Groups and delete them
		for RESOURCE_GROUP in $RESOURCE_GROUPS; do
			echo "Deleting Resource Group ${RESOURCE_GROUP}..."
			az group delete --name $RESOURCE_GROUP --yes --no-wait
		done
	else
		echo "No Actions Workshop Resource Groups found. Skipping..."
	fi
}

removeActionWorkshopDeployments

## Get all App Registrations that start with `aw-`
APP_REGISTRATIONS_JSON=$(az ad app list --query "[?starts_with(displayName, 'aw-')].{displayName:displayName,appId:appId}" -o json)
LOOPABLE_APP_REGISTRATIONS=$(echo $APP_REGISTRATIONS_JSON | jq -c '.[]')

## Iterate through all app registrations and print the name of them in a list that all those will be deleted:
echo "The following App Registrations will be deleted:"
for APP_REGISTRATION in $LOOPABLE_APP_REGISTRATIONS; do
	APP_REGISTRATION_DISPLAY_NAME=$(echo $APP_REGISTRATION | jq -r '.displayName')
	APP_REGISTRATION_APP_ID=$(echo $APP_REGISTRATION | jq -r '.appId')
	echo " - ${APP_REGISTRATION_DISPLAY_NAME} (${APP_REGISTRATION_APP_ID})"
done

read -p "Do you want to delete these App Registrations? (y/n) " -n 1 -r

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
	echo "Aborting..."
	exit 1
fi

echo ""
for APP_REGISTRATION in $LOOPABLE_APP_REGISTRATIONS; do
	APP_REGISTRATION_DISPLAY_NAME=$(echo $APP_REGISTRATION | jq -r '.displayName')
	APP_REGISTRATION_APP_ID=$(echo $APP_REGISTRATION | jq -r '.appId')
	echo "Deleting App Registration '${APP_REGISTRATION_DISPLAY_NAME}' with App ID '${APP_REGISTRATION_APP_ID}'..."
	az ad app delete --id $APP_REGISTRATION_APP_ID
done


## Ask the user if they want to delete the Service Principal and Custom Role as well
read -p "Do you also want to delete the Service Principal '${SERVICE_PRINCIPAL_NAME}' and the Custom Roles '${ADMIN_ROLE_NAME}' and '${PARTICIPANTS_ROLE_NAME}'? (y/n) " -n 1 -r
echo ""

## Exit if the user did not confirm
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
	echo "Skipping Service Principal and Custom Role deletion. You can always delete them at a later time by rerunning this script."
	exit 1
fi

function deleteCustomRole() {
	ROLE_NAME=$1
	echo "Deleting Role Assignments for '${ROLE_NAME}'..."
	## List all Role assignments to the GitHub Actions Workshop Role
	ROLE_ASSIGNMENT_IDS=$(az role assignment list --role "${ROLE_NAME}" --query '[].principalId' -o tsv)

	## Loop over all Role assignments and delete them
	for ROLE_ASSIGNMENT_ID in ${ROLE_ASSIGNMENT_IDS}; do
		az role assignment delete --assignee ${ROLE_ASSIGNMENT_ID} --role "${ROLE_NAME}"
	done

	## Delete the Custom Roel
	echo "Deleting Custom Role '${ROLE_NAME}'..."
	az role definition delete --name "${ROLE_NAME}"
}

deleteCustomRole "${PARTICIPANTS_ROLE_NAME}"
deleteCustomRole "${ADMIN_ROLE_NAME}"

## Get the app by display name
SP_APP_ID=$(az ad app list --display-name "${SERVICE_PRINCIPAL_NAME}" --query '[].appId' -o tsv) 

## Delete the app if it exists
if [[ -n "$SP_APP_ID" ]]; then
	echo "Deleting App ${SERVICE_PRINCIPAL_NAME}' (including it's Service Principal and Federated Credentials '${FEDERATED_CREDENTIALS_NAME}')..."
	az ad app delete --id $SP_APP_ID
else
	echo "Service Principal '${SERVICE_PRINCIPAL_NAME}' not found. Skipping..."
fi

echo "Cleanup was succesfull."
