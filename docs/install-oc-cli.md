# Installing OpenShift CLI (oc)

This guide provides instructions for installing the OpenShift CLI (`oc`) command on various operating systems.

---

## Quick Install Methods

### Method 1: Download from OpenShift Console (Easiest)

1. **Log in to your OpenShift Console**
   - Navigate to your OpenShift cluster web console
   - Example: `https://console-openshift-console.apps.rm2.thpm.p1.openshiftapps.com`

2. **Access Command Line Tools**
   - Click the **"?"** (help) icon in the top-right corner
   - Select **"Command Line Tools"**

3. **Download for Your OS**
   - Choose your operating system (Linux, macOS, or Windows)
   - Click the download link
   - Extract the archive
   - Move `oc` to your PATH

### Method 2: Direct Download from Red Hat

Visit: https://mirror.openshift.com/pub/openshift-v4/clients/ocp/stable/

Choose your platform and download the appropriate archive.

---

## Installation by Operating System

### macOS

#### Option 1: Homebrew (Recommended)

```bash
# Install using Homebrew
brew install openshift-cli

# Verify installation
oc version
```

#### Option 2: Manual Installation

```bash
# Download the latest stable release
curl -LO https://mirror.openshift.com/pub/openshift-v4/clients/ocp/stable/openshift-client-mac.tar.gz

# Extract the archive
tar xvzf openshift-client-mac.tar.gz

# Move to PATH
sudo mv oc /usr/local/bin/

# Make executable
sudo chmod +x /usr/local/bin/oc

# Verify installation
oc version
```

#### Option 3: Using the downloaded file from OpenShift Console

```bash
# If you downloaded from OpenShift Console
cd ~/Downloads

# Extract
tar xvzf oc-*.tar.gz

# Move to PATH
sudo mv oc /usr/local/bin/

# Make executable
sudo chmod +x /usr/local/bin/oc

# Verify
oc version
```

### Linux

#### Option 1: Download and Install

```bash
# Download the latest stable release
curl -LO https://mirror.openshift.com/pub/openshift-v4/clients/ocp/stable/openshift-client-linux.tar.gz

# Extract the archive
tar xvzf openshift-client-linux.tar.gz

# Move to PATH
sudo mv oc /usr/local/bin/

# Make executable
sudo chmod +x /usr/local/bin/oc

# Verify installation
oc version
```

#### Option 2: Using Package Manager (RHEL/Fedora)

```bash
# For RHEL 8/9 or Fedora
sudo dnf install openshift-clients

# Verify installation
oc version
```

### Windows

#### Option 1: Download and Install

1. **Download the Windows client:**
   - Visit: https://mirror.openshift.com/pub/openshift-v4/clients/ocp/stable/
   - Download `openshift-client-windows.zip`

2. **Extract the archive:**
   - Right-click the downloaded file
   - Select "Extract All..."
   - Choose a destination folder

3. **Add to PATH:**
   - Move `oc.exe` to a directory in your PATH
   - Or add the directory to your PATH:
     - Open "System Properties" → "Environment Variables"
     - Edit "Path" variable
     - Add the directory containing `oc.exe`

4. **Verify installation:**
   ```powershell
   oc version
   ```

#### Option 2: Using Chocolatey

```powershell
# Install using Chocolatey
choco install openshift-cli

# Verify installation
oc version
```

---

## Logging In to OpenShift

After installing `oc`, you need to log in to your cluster:

### Method 1: Using Login Command from Console

1. **Get Login Command:**
   - Log in to OpenShift Console
   - Click your username in top-right
   - Select **"Copy login command"**
   - Click **"Display Token"**
   - Copy the `oc login` command

2. **Run the Command:**
   ```bash
   oc login --token=sha256~xxxxx --server=https://api.rm2.thpm.p1.openshiftapps.com:6443
   ```

### Method 2: Using Username and Password

```bash
oc login https://api.rm2.thpm.p1.openshiftapps.com:6443 -u username -p password
```

### Method 3: Using Token Directly

```bash
# Set the token
export KUBECONFIG=/path/to/kubeconfig

# Or use token directly
oc login --token=YOUR_TOKEN --server=https://api.example.com:6443
```

---

## Verifying Installation

### Check Version

```bash
oc version
```

Expected output:
```
Client Version: 4.14.x
Kustomize Version: v5.0.x
Server Version: 4.14.x
Kubernetes Version: v1.27.x
```

### Check Connection

```bash
# Check current context
oc whoami

# Check current project
oc project

# List all projects
oc projects
```

---

## Finding AAP Controller Route (Your Use Case)

Once `oc` is installed and you're logged in:

```bash
# List all routes in the AAP namespace
oc get route -n ansible-automation-platform

# Filter for controller route
oc get route -n ansible-automation-platform | grep controller

# Get detailed info about controller route
oc describe route -n ansible-automation-platform | grep -A 5 controller

# Get just the controller URL
oc get route -n ansible-automation-platform -o jsonpath='{.items[?(@.metadata.name=="sandbox-aap-controller")].spec.host}'
```

Example output:
```
NAME                      HOST/PORT
sandbox-aap-controller    sandbox-aap-controller.apps.rm2.thpm.p1.openshiftapps.com
sandbox-aap-eda           sandbox-aap-eda.apps.rm2.thpm.p1.openshiftapps.com
```

The Controller URL would be:
```
https://sandbox-aap-controller.apps.rm2.thpm.p1.openshiftapps.com/
```

---

## Alternative: Find Controller URL Without oc CLI

If you can't install `oc`, you can find the Controller URL through the OpenShift Console:

### Using OpenShift Web Console

1. **Log in to OpenShift Console**
   - Navigate to your cluster's web console

2. **Navigate to Routes**
   - Click **"Networking"** → **"Routes"**
   - Select project: `ansible-automation-platform`

3. **Find Controller Route**
   - Look for a route named like:
     - `sandbox-aap-controller`
     - `aap-controller`
     - `automation-controller`
   - Click on it to see details

4. **Copy the Location/URL**
   - The "Location" field shows the full URL
   - Example: `https://sandbox-aap-controller.apps.rm2.thpm.p1.openshiftapps.com`

### Using AAP Console

1. **Log in to AAP Controller**
   - The URL you use to access AAP Controller IS the Controller URL
   - Copy it from your browser's address bar
   - Example: `https://sandbox-aap-controller.apps.example.com/`

2. **Verify it's the Controller (not EDA)**
   - Controller UI shows: Jobs, Templates, Inventories, Projects
   - EDA UI shows: Rulebook Activations, Event Streams, Decision Environments

---

## Troubleshooting

### Issue: "oc: command not found"

**Solutions:**
1. Verify `oc` is in your PATH:
   ```bash
   which oc
   echo $PATH
   ```
2. Restart your terminal
3. Re-run installation steps

### Issue: "Unable to connect to the server"

**Solutions:**
1. Check you're using the correct server URL
2. Verify you're logged in:
   ```bash
   oc whoami
   ```
3. Re-login if needed

### Issue: "Forbidden" or "Unauthorized"

**Solutions:**
1. Check your token hasn't expired
2. Verify you have access to the namespace:
   ```bash
   oc get projects
   ```
3. Request access from cluster admin if needed

### Issue: Can't find ansible-automation-platform namespace

**Solutions:**
1. List all namespaces:
   ```bash
   oc get namespaces | grep -i ansible
   oc get namespaces | grep -i aap
   ```
2. The namespace might have a different name:
   - `aap`
   - `ansible`
   - `automation-platform`
   - `redhat-ansible-automation-platform`

---

## Quick Reference Commands

```bash
# Login
oc login --token=TOKEN --server=SERVER_URL

# Check current user
oc whoami

# List projects/namespaces
oc projects

# Switch project
oc project ansible-automation-platform

# List routes
oc get routes

# Get specific route
oc get route sandbox-aap-controller

# Describe route (detailed info)
oc describe route sandbox-aap-controller

# Get route URL
oc get route sandbox-aap-controller -o jsonpath='{.spec.host}'

# List all resources in namespace
oc get all -n ansible-automation-platform

# Get pods
oc get pods -n ansible-automation-platform

# View logs
oc logs -n ansible-automation-platform POD_NAME
```

---

## Additional Resources

- [OpenShift CLI Documentation](https://docs.openshift.com/container-platform/latest/cli_reference/openshift_cli/getting-started-cli.html)
- [OpenShift CLI Download Page](https://mirror.openshift.com/pub/openshift-v4/clients/ocp/)
- [OpenShift CLI Cheat Sheet](https://developers.redhat.com/cheat-sheets/red-hat-openshift-container-platform)

---

**Made with Bob** 🤖