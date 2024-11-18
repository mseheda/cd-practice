#!/bin/bash

# halt the script on an error
set -e

## In case of an error, print abortion
trap 'echo "Aborting due to error on line $LINENO. Exit code: $?" >&2' ERR


## Check if the ENV Variable AZ_SUBSCRIPTION_ID is set, error out if not
if [ -z "$AZ_SUBSCRIPTION_ID" ]; then
	echo "AZ_SUBSCRIPTION_ID is missing. Please set it using 'export AZ_SUBSCRIPTION_ID=<PLACE YOUR ID HERE>' and run this script again."
	exit 1
fi

## Check if the user is logged into Azure, error out if not
if [ -z "$(az account show)" ]; then
	echo "You are not logged into Azure. Please run 'az login' before running this script."
	exit 1
fi

echo "Creating Service Principal..."
AZURE_CREDENTIALS=$(az ad sp create-for-rbac --name "GitHub Actions Workshop Principal" --only-show-errors)

ROLE_JSON=$(cat <<EOF
{
	"Name": "GitHub Actions Workshop Role",
	"Description": "This role is used by the GitHub Actions Workshop to allow a Deployment in Azure Web Apps.",
	"Actions": [
		"Microsoft.Resources/subscriptions/resourceGroups/read",
		"Microsoft.Resources/subscriptions/resourceGroups/write",
		"Microsoft.Web/serverfarms/Read",
		"Microsoft.Web/serverfarms/Write",
		"Microsoft.Resources/deployments/validate/action",
		"Microsoft.Web/sites/Write",
		"Microsoft.Web/sites/Read",
		"Microsoft.Resources/deployments/write",
		"Microsoft.Resources/deployments/read",
		"Microsoft.Resources/deployments/operationstatuses/read"
	],
	"AssignableScopes": ["/subscriptions/$AZ_SUBSCRIPTION_ID"]
}
EOF
)

echo "Creating Custom Role..."
az role definition create --role-definition "$ROLE_JSON" --only-show-errors

echo "Assigning Role to Service Principal..."
az role assignment create --assignee $(echo $AZURE_CREDENTIALS | jq -r .appId) --role "GitHub Actions Workshop Role" --scope "/subscriptions/$AZ_SUBSCRIPTION_ID" --only-show-errors

echo ""
echo "Azure Account Preparation was succesfull.
The following resources were created:
  - A Service Principal with the name 'GitHub Actions Workshop Tenant' (from the portal, you can find it in Entra Id under App registrations -> All applications)
  - A Custom Role with the name 'GitHub Actions Workshop Role' (from the portal, you can find it under your Subscription -> IAM -> Roles)
  - A Role Assignment for the Service Principal to the Custom Role
"

echo "Next Steps: Create the following GitHub Organization Secrets in your Workshop Organization:
  AZ_CLIENT_ID:       $(echo $AZURE_CREDENTIALS | jq -r .appId)
  AZ_CLIENT_SECRET:   $(echo $AZURE_CREDENTIALS | jq -r .password)
  AZ_TENANT_ID:       $(echo $AZURE_CREDENTIALS | jq -r .tenant)
  AZ_SUBSCRIPTION_ID: $AZ_SUBSCRIPTION_ID
"
