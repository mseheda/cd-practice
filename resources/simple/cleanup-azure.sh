#!/bin/bash

# halt the script on an error
set -e

## In case of an error, print abortion
trap 'echo "Aborting due to error on line $LINENO. Exit code: $?" >&2' ERR

## List all Resource Groups with a tag containing purpose=GitHub Actions Workshop
RESOURCE_GROUPS=$(az group list --query "[?tags.purpose=='GitHub Actions Workshop'].name" -o tsv)

## Print all resources groups and ask the user for confirmation
if [[ -n "$RESOURCE_GROUPS" ]]; then
	echo "The following, action workshop realted Resource Groups will be deleted:"
	echo $RESOURCE_GROUPS
	read -p "Are you sure you want to delete these Resource Groups? (y/n) " -n 1 -r

	## Exit if the user did not confirm
	if [[ ! $REPLY =~ ^[Yy]$ ]]; then
		echo "Aborting..."
		exit 1
	fi

	## Loop over all Resource Groups and delete them
	for RESOURCE_GROUP in $RESOURCE_GROUPS; do
		echo "Deleting Resource Group $RESOURCE_GROUP..."
		az group delete --name $RESOURCE_GROUP --yes --no-wait
	done
else
	echo "No Actions Workshop Resource Groups found. Skipping..."
fi

## Ask the user if they want to delete the Service Principal and Custom Role as well
read -p "Do you also want to delete the Service Principal and Custom Role? (y/n) " -n 1 -r
echo ""

## Exit if the user did not confirm
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
	echo "Skipping Service Principal and Custom Role deletion. You can always delete them at a later time by rerunning this script."
	exit 1
fi

echo "Deleting Service Principal (including it App Registration and Secret)..."

## Get the app by display name
SP_APP_ID=$(az ad app list --display-name "GitHub Actions Workshop Principal" --query '[].appId' -o tsv) 

## Delete the app if it exists
if [[ -n "$SP_APP_ID" ]]; then
	az ad app delete --id $SP_APP_ID
else
	echo "No Service Principal found. Skipping..."
fi


echo "Deleting Role Assignments..."
## List all Role assignments to the GitHub Actions Workshop Role
ROLE_ASSIGNMENT_IDS=$(az role assignment list --role "GitHub Actions Workshop Role" --query '[].id' -o tsv)

## Loop over all Role assignments and delete them
for ROLE_ASSIGNMENT_ID in $ROLE_ASSIGNMENT_IDS; do
	az role assignment delete --assignee $ROLE_ASSIGNMENT_ID --role "GitHub Actions Workshop Role"
done

## Delete the Custom Roel
echo "Deleting Custom Role..."
az role definition delete --name "GitHub Actions Workshop Role"

echo "Cleanup was succesfull."
