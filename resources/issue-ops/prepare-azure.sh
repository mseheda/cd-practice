#!/bin/bash

# halt the script on an error
set -e

## In case of an error, print abortion
trap 'echo "Aborting due to error on line $LINENO. Exit code: $?" >&2' ERR

## Check if the user is logged into Azure, error out if not
if [ -z "$(az account show)" ]; then
	echo "You are not logged into Azure. Please run 'az login' before running this script."
	exit 1
fi

if [ -z "$GITHUB_REPOSITORY" ]; then
	echo "GITHUB_REPOSITORY is missing. Please enter it below:"
	read GITHUB_REPOSITORY
fi

# Check if GitHub Repository is of format <owner>/<repo>
if [[ ! $GITHUB_REPOSITORY =~ ^[a-z0-9-]+/[a-z0-9-]+$ ]]; then
	echo "GITHUB_REPOSITORY is not of format <owner>/<repo>. Exiting..."
	exit 1
fi

## Split the $GITHUB_REPOSITORY by the '/' delimiter and get the first element (owner)
GITHUB_OWNER=$(echo $GITHUB_REPOSITORY | cut -d'/' -f1)

if [ -z "$AZ_SUBSCRIPTION_ID" ]; then
	echo "AZ_SUBSCRIPTION_ID is missing. Please enter it below:"
	read AZ_SUBSCRIPTION_ID
fi

SERVICE_PRINCIPAL_NAME="GitHub Actions Workshop Administrator"
FEDERATED_CREDENTIALS_NAME="app-registration-credentials"
AD_ROLE_NAME="Cloud Application Administrator"
ADMIN_ROLE_NAME="GitHub Actions Workshop Administrator Role"
PARTICIPANTS_ROLE_NAME="GitHub Actions Workshop Participants Role"


##
# CREATE APP AND SERVICE PRINCIPAL
##
echo "Creating AD App and Service Principal '${SERVICE_PRINCIPAL_NAME}'..."
AZURE_ADMIN_APP=$(az ad app create --display-name "${SERVICE_PRINCIPAL_NAME}" --sign-in-audience "AzureADMyOrg")

APP_OBJECT_ID=$(echo $AZURE_ADMIN_APP | jq -r '.id')
APP_ID=$(echo $AZURE_ADMIN_APP | jq -r '.appId')

SERVICE_PRINCIPAL=$(az ad sp list --filter "appId eq '$APP_ID'")
if [ "${SERVICE_PRINCIPAL}" == "[]" ]; then
	echo "Adding Servie Principal to App..."
	SERVICE_PRINCIPAL=$(az ad sp create --id $APP_ID) 
	SERVICE_PRINCIPAL_ID=$(echo ${SERVICE_PRINCIPAL} | jq -r '.id')
	AZ_TENANT_ID=$(echo ${SERVICE_PRINCIPAL} | jq -r '.appOwnerOrganizationId')
else
	echo "Service Principal already exists. Skipping..."
	SERVICE_PRINCIPAL_ID=$(echo ${SERVICE_PRINCIPAL} | jq -r '.[0].id')
	AZ_TENANT_ID=$(echo ${SERVICE_PRINCIPAL} | jq -r '.[0].appOwnerOrganizationId')
fi

##
# GET THE ROLE ID OF THE AD ROLE "Cloud Application Administrator"
##
CLOUD_APPLICATION_ADMINISTRATOR=$(az rest --method GET --uri "https://graph.microsoft.com/v1.0/roleManagement/directory/roleDefinitions?\$filter=DisplayName eq '${AD_ROLE_NAME}'")
CLOUD_APPLICATION_ADMINISTRATOR_ID=$(echo ${CLOUD_APPLICATION_ADMINISTRATOR} | jq -r '.value[0].id')


##
# ASSIGN THE ROLE "Cloud Application Administrator" TO THE SERVICE PRINCIPAL IN THE SCOPE OF THE APP
##
ROLE_ASSIGNMENT_BODY=$(cat <<EOF
{
  "@odata.type": "#microsoft.graph.unifiedRoleAssignment",
  "principalId": "${SERVICE_PRINCIPAL_ID}",
  "roleDefinitionId": "${CLOUD_APPLICATION_ADMINISTRATOR_ID}",
  "directoryScopeId": "/"
}
EOF
)

ROLE_ASSIGNMENT=$(az rest --method GET --uri "https://graph.microsoft.com/v1.0/roleManagement/directory/roleAssignments?\$filter=principalId eq '${SERVICE_PRINCIPAL_ID}' and roleDefinitionId eq '${CLOUD_APPLICATION_ADMINISTRATOR_ID}' and directoryScopeId eq '/'")
ROLE_ASSIGNMENT_VALUE=$(echo ${ROLE_ASSIGNMENT} | jq -r '.value')

## If ROLE_ASSIGNMENT.value is [], then the Role Assignment does not exist
if [ "$ROLE_ASSIGNMENT_VALUE" == "[]" ]; then
  echo "Assigning Role '${AD_ROLE_NAME}' to Service Principal '${SERVICE_PRINCIPAL_NAME}'..."
  az rest --method POST --uri "https://graph.microsoft.com/v1.0/roleManagement/directory/roleAssignments" --body "$ROLE_ASSIGNMENT_BODY" --headers "Content-Type=application/json"
else
  echo "Role Assignment for '${AD_ROLE_NAME}' to Service Principal '${SERVICE_PRINCIPAL_NAME}' already exists. Skipping..."
fi

##
# CREATE FEDERATED CREDENTIALS FOR OIDCS ACCESS OF THE REPOSITORY
##
OIDC_JSON_BODY=$(cat <<EOF
{
	"name": "${FEDERATED_CREDENTIALS_NAME}",
	"issuer": "https://token.actions.githubusercontent.com",
	"subject": "repo:${GITHUB_REPOSITORY}:ref:refs/heads/main", 
	"description": "These credentials allow actions of the main branch to create new App Registration and Service-principals as part of the GitHub Actions Workshop (https://github.com/actions-workshop/actions-workshop)",
	"audiences": [
		"api://AzureADTokenExchange"
	]
}
EOF
)

EXISTING_FC=$(az ad app federated-credential list --id $APP_ID --query "[?name=='${FEDERATED_CREDENTIALS_NAME}']")
if [ "$EXISTING_FC" == "[]" ]; then
	echo "Creating OIDC Acceess through federated credentials '${FEDERATED_CREDENTIALS_NAME}' for the ${GITHUB_REPOSITORY}..."
	az ad app federated-credential create --id ${APP_ID} --parameters "${OIDC_JSON_BODY}"
else 
	echo "Federated credential already exists. Skipping..."
fi


##
# CREATE A ROLE FOR THE ADMINISTRATOR TO BE ABLE TO CREATE RESOURCE GROUPS AND DELETE DEPLOYMENTS
##
ADMIN_ROLE_JSON=$(cat <<EOF
{
	"Name": "${ADMIN_ROLE_NAME}",
	"Description": "This role is used by the GitHub Actions Workshop Administrator to allow all actions, mostly creating a resource group.",
	"Actions": [
		"Microsoft.Resources/subscriptions/resourceGroups/read",
		"Microsoft.Resources/subscriptions/resourceGroups/write",
		"Microsoft.Resources/subscriptions/resourceGroups/delete",
		"Microsoft.Authorization/roleAssignments/read",
		"Microsoft.Authorization/roleAssignments/write",
		"Microsoft.Web/serverfarms/read",
		"Microsoft.Web/serverfarms/write",
		"Microsoft.Web/serverfarms/delete",
		"Microsoft.Resources/deployments/validate/action",
		"Microsoft.Web/sites/write",
		"Microsoft.Web/sites/read",
		"Microsoft.Web/sites/delete",
		"Microsoft.Resources/deployments/read",
		"Microsoft.Resources/deployments/write",
		"Microsoft.Resources/deployments/delete",
		"Microsoft.Resources/deployments/operationstatuses/read"
	],
	"AssignableScopes": ["/subscriptions/${AZ_SUBSCRIPTION_ID}"]
}
EOF
)

EXISTING_ADMIN_ROLE=$(az role definition list --custom-role-only --query "[?roleName=='${ADMIN_ROLE_NAME}']")

if [ "${EXISTING_ADMIN_ROLE}" == "[]" ]; then
	echo "Creating Custom Role '${ADMIN_ROLE_NAME}'..."
	az role definition create --role-definition "${ADMIN_ROLE_JSON}" --only-show-errors
else
	echo "Custom Role already exists. Skipping..."
fi

echo "Assigning Custom Role '${ADMIN_ROLE_NAME}' to Service Principal '${SERVICE_PRINCIPAL_NAME}'..."
az role assignment create --assignee ${APP_ID} --role "${ADMIN_ROLE_NAME}" --scope "/subscriptions/${AZ_SUBSCRIPTION_ID}" --only-show-errors

##
# CREATE A CUSTOM ROLE FOR THE WORKSHOP PARTICIPANTS TO BE ABLE TO DEPLOY WEB APPS
##
ROLE_JSON=$(cat <<EOF
{
	"Name": "${PARTICIPANTS_ROLE_NAME}",
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
	"AssignableScopes": ["/subscriptions/${AZ_SUBSCRIPTION_ID}"]
}
EOF
)

EXISTING_ROLE=$(az role definition list --custom-role-only --query "[?roleName=='${PARTICIPANTS_ROLE_NAME}']")

if [ "${EXISTING_ROLE}" == "[]" ]; then
	echo "Creating Custom Role '${PARTICIPANTS_ROLE_NAME}'..."
	az role definition create --role-definition "$ROLE_JSON" --only-show-errors
else
	echo "Custom Role '${PARTICIPANTS_ROLE_NAME}' already exists. Skipping..."
fi

echo ""
echo "Azure Account Preparation was succesfull.
The following resources were created:
  - AD App Registration & Service Principal '${SERVICE_PRINCIPAL_NAME}'
  - Federeated Credentaisl '${FEDERATED_CREDENTIALS_NAME}' for the Service Principal
  - AD Role Assignment '${AD_ROLE_NAME}' for the Service Principal
  - Custom Role '${ADMIN_ROLE_NAME}'
  - Role Assignment for the Custom Role '${ADMIN_ROLE_NAME}' to the Service Principal
  - Custom Role '${PARTICIPANTS_ROLE_NAME}'
"

echo "Next Steps: Place the following secrets in your repository and organization:
REPOSITORY SECRET (https://github.com/${GITHUB_REPOSITORY}/settings/secrets/actions)
  AZ_CLIENT_ID:       ${APP_ID}

ORGANIZATION LEVEL SECRETS (https://github.com/${GITHUB_OWNER}/settings/secrets/actions)
  AZ_TENANT_ID:       ${AZ_TENANT_ID}
  AZ_SUBSCRIPTION_ID: ${AZ_SUBSCRIPTION_ID}
"
