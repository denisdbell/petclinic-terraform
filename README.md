# Terraform Azure ADO Deployment  –  Setup Guide

This document describes the **production-grade setup** for a Terraform remote backend using **Azure Storage**, integrated with **Azure DevOps Pipelines** via a secure **Service Connection**.

The goal is to:

* Create a secure, globally unique Terraform state backend  
* Follow least-privilege RBAC principles  
* Enable reliable, repeatable CI/CD deployments  

---

## Architecture Overview

Terraform state is stored remotely in an **Azure Storage Account (Blob Container)**.  
Azure DevOps pipelines authenticate using a **Service Principal–based Service Connection** with scoped RBAC permissions.

```
Azure DevOps Pipeline
        │
        ▼
Azure Service Connection (Service Principal)
        │
        ▼
Azure Subscription / Resource Group
        │
        ▼
Storage Account (Blob Container: terraform-state)
```

---

## Prerequisites

* Azure Subscription (Owner or User Access Administrator permissions)
* Azure CLI (`az`) installed and authenticated
* Azure DevOps Project with permissions to create:
  * Service Connections
  * Pipelines
  * Repositories

---

## Step 0: Install the Terraform Extension (Organization Level)

Azure DevOps does **not** include Terraform tasks by default. You must install the official Terraform extension at the **organization level** before any pipeline can use Terraform tasks.

### Option A: Install via Azure DevOps UI (Recommended)

1. Sign in to **Azure DevOps**
2. In the top-left, click **Organization settings**
3. Go to **Extensions**
4. Click **Browse marketplace**
5. In the search box, search for:

   ```text
   Terraform
   ```

6. Select **Terraform by Microsoft DevLabs**
7. Click **Get it free**
8. Choose the **Organization** you want to install it into
9. Click **Install**

### Verify Installation

1. Go to **Organization settings → Extensions**
2. Confirm **Terraform** appears in the installed extensions list
3. Open a pipeline YAML editor and verify tasks such as:
   * `TerraformInstaller@1`
   * `TerraformTaskV4@4`  
   are available (they should appear via autocomplete)

### Why This Is Required

Without this extension:

* Pipelines will fail with **“Task not found”**
* You won’t have the official Terraform tasks available
* You’ll be forced to script Terraform manually

Installing it at the **organization level** ensures:

* All projects can use Terraform tasks
* Consistent tooling across teams
* Cleaner, more maintainable pipelines

---

## Step 1: Create Terraform Backend Resources

The following ARM template creates:

* A dedicated **Resource Group**
* A **Storage Account** (globally unique)
* A **private Blob Container** for Terraform state

### Deployment Notes

* Storage account name is generated using `uniqueString()` to ensure global uniqueness
* Public access is disabled
* Suitable for production Terraform backends

### Deploy the Template

Download the backend,json file (Bash)

```bash
curl -L -o backend.json https://raw.githubusercontent.com/denisdbell/petclinic-terraform/main/backend.json
```

Deploy at **subscription scope**:

```bash
az deployment sub create \
  --name terraform-backend \
  --location westus3 \
  --template-file backend.json
```

Capture the outputs:

* `resourceGroupName`
* `storageAccountName`
* `containerName`

These values are required later for the pipeline.

---

## Step 2: Create Azure DevOps Service Connection (Improved & Secure)

### Recommended Authentication Method

✅ **Azure Resource Manager – Service Principal (Automatic)**  
This ensures:

* Credential rotation handled by Azure
* No secrets committed to source control
* Simplified management

### Step-by-Step

1. Navigate to **Azure DevOps**
2. Go to **Project Settings → Service Connections**
3. Select **New Service Connection**
4. Choose **Azure Resource Manager**
5. Select **Service Principal (automatic)**
6. Scope Level:
   * **Subscription** (recommended for shared Terraform backends)
7. Select the target subscription
8. Check **Grant access permission to all pipelines** (or restrict explicitly)
9. Name the connection clearly:

```
azurerm-terraform-backend
```

10. Create the service connection

---

## Step 3: Assign RBAC Permissions (Least Privilege)

Retrieve the **Service Principal Object ID**:

```bash
az ad sp list --display-name "<service-connection-name>" --query "[0].id" -o tsv
```

> Replace `<service-connection-name>` with the actual name created by Azure DevOps.

---

### 3.1 Contributor – Resource Group Scope

Allows Terraform to create and manage infrastructure within the backend resource group.

```bash
az role assignment create \
  --assignee <SP_OBJECT_ID> \
  --role "Contributor" \
  --scope "/subscriptions/<SUB_ID>/resourceGroups/rg-tfstate"
```

---

### 3.2 Storage Blob Data Contributor – Storage Account Scope

Required for **read/write access** to the Terraform state file.

```bash
az role assignment create \
  --assignee <SP_OBJECT_ID> \
  --role "Storage Blob Data Contributor" \
  --scope "/subscriptions/<SUB_ID>/resourceGroups/rg-tfstate/providers/Microsoft.Storage/storageAccounts/<STORAGE_ACCOUNT_NAME>"
```

---

### 3.3 (Optional) Contributor – Subscription Scope

Only required if Terraform manages **multiple resource groups** or subscription-level resources.

```bash
az role assignment create \
  --assignee <SP_OBJECT_ID> \
  --role "Contributor" \
  --scope "/subscriptions/<SUB_ID>"
```

> ⚠️ Avoid this unless absolutely necessary.

---

## Step 4: Create the Repository

1. Create a new Azure DevOps Git repository
2. Add the provided files:
   * Terraform configuration
   * Backend configuration
   * Pipeline YAML
3. Commit and push to `main`

---

## Step 5: Create the Azure DevOps Pipeline

1. Navigate to **Pipelines → New Pipeline**
2. Select **Azure Repos Git**
3. Choose the repository
4. Select **Existing Azure Pipelines YAML file**
5. Point to the pipeline YAML

---

## Step 6: Configure Pipeline Variables

Define the following variables in the pipeline (Library or Pipeline UI):

```text
azureServiceConnection = azurerm-terraform-backend
resourceGroup           = rg-tfstate
storageAccount          = <storage-account-name>
container               = terraform-state
tfStateKey              = terraform.tfstate
```

Mark sensitive values as **secret** where applicable.

---

## Step 7: Execute and Validate

Run the pipeline and verify:

* Backend initialization succeeds
* State file is created in Blob Storage
* Subsequent runs reuse the same state
