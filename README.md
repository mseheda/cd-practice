# Actions Workshop Deployment Environment

This repository contains preparation resources and script for the deployment step of the [GitHub Actions Workshop](https://github.com/actions-workshop/actions-workshop). It's for trainers of this workshop to allow participants to deploy to any kind of infrastructure (currently only Azure) without having them create or bring their own accounts.

This repository contains all explanations and scripts to easily set up all required infrastructure and be ready to conduct the workshop.

There are currently two ways to create a deployment environment:

1. [Simple Azure Web-App with Secret Authentication](./docs/simple-azure.md):
    This is the simplest possible deployment environment that can be created for the workshop. It consists of an Azure Service Principal using Secret authentication that has the required permissions to deploy a Web-App to a given Resource Group. The necessary secrets are placed as organization secrets within the organization the actions-workshop is conducted in.

    Go to [Simple Azure Web-App with Secret Authentication](./docs/simple-azure.md) for a step-by-step guide.
2. [Issue-Ops Azure Web-App with OIDC Authentication](./docs/issue-ops-azure.md)
    This is a more sophisticated way for deployment, in that it uses GitHub Issues to trigger the creation of a full deployment environment on Azure (hence the term 'Issue Ops'). Additionally, rather than relying on secrets, it will use OIDC Authentication to conduct the deployment in a secure manner.

    Go to [Issue-Ops Azure Web-App with OIDC Authentication](./docs/issue-ops-azure.md) for a step-by-step guide.

## Azure Costs

You might be wondering: What will it cost to run this workshop in Azure the way?
**The answer: Most likely only a few cents.**

Participants will each create a single [Azure Web App Service](https://azure.microsoft.com/en-us/pricing/details/app-service/linux/) under a **Basic B1 Service Plan** which currently comes at €0.017/hour - so roughly 2 Cents / participant / hour.

As the Deployment Step is the last part of the workshop, participants will only have this service running for a few minutes or maximum hours - depending on how fast you will execute the cleanup scripts.

## Contributions

Please see [CONTRIBUTING.md](./CONTRIBUTING.md) for details.

## Licensing

This repo is licensed under MIT. See the [LICENSE](./LICENSE) File for more information.

## Maintainer(s)

- [David Losert](https://github.com/davelosert)
