# Simple Azure Deployment Environment

This is the simplest possible deployment environment that can be created for the workshop. It consists of an Azure Service Principal using Secret authentication that has the required permissions to deploy a Web-App to a given Resource Group.

## 1 Prepare the Azure Account

### Overview: Required Azure Resources

| Azure Resource | Name | Additional Info |
| ---- | ------ | ------ |
| [AD App Registration & Service Principal][ad-docs-create-service-principal] | GitHub Actions Workshop Principal | This is the 'main' Service Principal used by this repository to create new participant specific Service Principals that allow them to deploy |
| [Client secrets][ad-docs-create-client-secret] | GitHub Actions Workshop Principal | A client secret for the created Service Principal |
| [Custom Role][ad-docs-create-custom-role-json] | GitHub Actions Workshop Role | Using [these permissions](./resources/simple/prepare-azure.sh#L30) (allowed in the scope of the subscription), this role allows the participants to create Resource Groups and conduct Azure Web App Deployments |
| [Role Assignment][ad-docs-create-role-assignment] | GitHub Actions Workshop Role | Assigned to the GitHub Actions Workshop Principal |

### How to create these resources

If you want to use the Azure Portal, click on the links in the overview above for detailed instructions.

However, the easiest way to create all of the above is to use the [./resources/simple/prepare-azure.sh](../resources/simple/prepare-azure.sh) script. To run it, spin up a Codespace and execute the following:

1. Login to Azure with

    ```shell
    az login --use-device-code
    ```

2. Define the Subscription Id to be used

    ```shell
    export AZ_SUBSCRIPTION_ID=<your-subscription-id>
    ```

3. Execute the script:

    ```shell
    ./resources/simple/prepare-azure.sh
    ```

4. Make sure to store all the output values as Organization-Secrets as advised in the log output:

    | Secret Name        | Value                                                    |
    | ------------------ | -------------------------------------------------------- |
    | AZ_SUBSCRIPTION_ID | The Azure Subscription ID used above                     |
    | AZ_TENANT_ID       | The Azure Tenant ID used above                           |
    | AZ_CLIENT_ID       | The Azure Client ID of the created Service Principal     |
    | AZ_CLIENT_SECRET   | The Azure Client Secret of the created Service Principal |

## 2 Create a GitHub Organization

Execute the following steps:

1. [Create a (free) GitHub Organization](https://docs.github.com/en/github/setting-up-and-managing-organizations-and-teams/creating-a-new-organization-from-scratch)
2. [Add all the IDs from above as organization action secrets](https://docs.github.com/en/actions/reference/encrypted-secrets#creating-encrypted-secrets-for-an-organization)
3. [Invite all participants to the organization](https://docs.github.com/en/organizations/managing-membership-in-your-organization/inviting-users-to-join-your-organization) and advice them to put their [Actions Workshop Template Copy](https://github.com/actions-workshop/actions-workshop) into this organization

## 3 Conduct the Workshop

Let the participants follow the [005-deployment-azure-webapp.md Deployment step](https://github.com/actions-workshop/actions-workshop/tree/main/docs/005-deployment-azure-webapp.md) for the workshop. It contains all explanations in how to use the created Service Principal to deploy to Azure.

## 4 Cleanup

After the workshop, you can easily cleanup all created resources by executing the [./resources/simple/cleanup-azure.sh](../resources/simple/cleanup-azure.sh) script:

1. Login to Azure (if not already logged in)

    ```shell
    az login --use-device-code
    ```

2. Execute the script:

    ```shell
    ./resources/simple/cleanup-azure.sh
    ```

This script will:

1. Delete all Resource Groups that participants created (identified by the tag `purpose=GitHub Actions Workshop`) and all deployed services
2. It will prompt you to also delete the Service Principal and Custom Role that was created for the workshop. You can keep them if you want to use them for future workshops.

[ad-docs-create-service-principal]: <https://learn.microsoft.com/en-us/azure/active-directory/develop/howto-create-service-principal-portal>
[ad-docs-create-client-secret]: <https://learn.microsoft.com/en-us/azure/active-directory/develop/howto-create-service-principal-portal#option-3-create-a-new-application-secret>
[ad-docs-create-custom-role-json]: <https://learn.microsoft.com/en-us/azure/role-based-access-control/custom-roles-portal#start-from-json>
[ad-docs-create-role-assignment]: <https://learn.microsoft.com/en-us/azure/role-based-access-control/role-assignments-portal>
