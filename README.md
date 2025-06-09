# Self-Hosted GitHub Actions Runner on Hetzner Cloud

[![Badge: Hetzer](https://img.shields.io/badge/Hetzner-D50C2D.svg?logo=hetzner&logoColor=white)](#readme)
[![Badge: GitHub](https://img.shields.io/badge/GitHub-181717.svg?logo=github&logoColor=white)](#readme)
[![Badge: Linux](https://img.shields.io/badge/Linux-FCC624.svg?logo=linux&logoColor=black)](#readme)
[![Badge: Debian](https://img.shields.io/badge/Debian-A81D33.svg?logo=debian&logoColor=white)](#readme)
[![Badge: Ubuntu](https://img.shields.io/badge/Ubuntu-E95420.svg?logo=ubuntu&logoColor=white)](#readme)
[![Badge: Fedora](https://img.shields.io/badge/Fedora-51A2DA.svg?logo=fedora&logoColor=white)](#readme)
[![Badge: Rocky Linux](https://img.shields.io/badge/Rocky%20Linux-10B981.svg?logo=rockylinux&logoColor=white)](#readme)
[![Badge: openSUSE](https://img.shields.io/badge/openSUSE-73BA25.svg?logo=opensuse&logoColor=white)](#readme)
[![Badge: GNU Bash](https://img.shields.io/badge/GNU%20Bash-4EAA25.svg?logo=gnubash&logoColor=white)](#readme)
[![Badge: License](https://img.shields.io/github/license/cyclenerd/hcloud-github-runner)](https://github.com/Cyclenerd/hcloud-github-runner/blob/master/LICENSE)

A GitHub Action to automatically create Hetzner Cloud servers and register them as self-hosted GitHub Actions runners.

Launch a Hetzner Cloud Server as a self-hosted GitHub Actions Runner just before your job starts.
Execute your workflow, and then automatically terminate the server upon completion.
All within your GitHub Actions workflow.

This [GitHub Action](./action.sh) is written in Bash (Shell Script).
Everything was carefully documented and kept as simple as possible.
The aim is to enable quick and easy auditability of the code.

## Use Cases

This section highlights how using Hetzner Cloud with self-hosted runners for your GitHub Actions CI/CD workflows can lead to significant cost savings and predictable billing compared to relying solely on GitHub-managed runners.

### Cost Control and Predictability

> [!IMPORTANT]
> As per [GitHub's documentation](https://docs.github.com/en/actions/hosting-your-own-runners/managing-self-hosted-runners/about-self-hosted-runners), self-hosted runners are free to use with GitHub Actions.
> Therefore, you won't be charged by GitHub for the execution time of jobs on your self-hosted runners.
> You'll only pay Hetzner for the server hours itself, which can be a more economical option than GitHub-hosted runners, particularly for resource-intensive or frequent workflows.
> Hetzner always round up the hourly usage of a server.
> If you create a server just for a few minutes, we will still bill you for one whole hour. ([FAQ](https://docs.hetzner.com/cloud/billing/faq)).

* **Potentially Lower Costs for High Usage:** For organizations with consistently high CI/CD usage, self-hosting on Hetzner Cloud can be significantly more cost-effective than paying for GitHub Actions minutes, especially for larger jobs or parallel execution.
* **No Usage Limits (Within Server Capacity):** You're not restricted by GitHub Actions usage limits (within the capacity of your Hetzner Cloud Server). This is beneficial for large builds, extensive testing, or frequent deployments.

The following table provides a comparison of pricing between GitHub-managed Actions runners and Hetzner Cloud with self-hosted runners (information provided without guarantee; prices exclude VAT):

| Runner | [GitHub](https://docs.github.com/en/billing/managing-billing-for-your-products/managing-billing-for-github-actions/about-billing-for-github-actions) | [Hetzner ](https://www.hetzner.com/cloud/) | Cost Saving | Cost Saving (%) |
|---|---|---|---|---|
| 2 Core (Intel) | $0.48 USD/hr | $0.0074 USD/hr | $0.4726 USD/hr | 98.46 % |
| 4 Core (Intel) | $0.96 USD/hr | $0.0127 USD/hr | $0.9473 USD/hr | 98.68 % |
| 8 Core (Intel) | $1.92 USD/hr | $0.0304 USD/hr | $1.8896 USD/hr | 98.42 % |
| 16 Core (Intel) | $3.84 USD/hr | $0.0611 USD/hr | $3.7789 USD/hr | 98.41 % |
| 2 Core (Arm) | $0.30 USD/hr | $0.0074 USD/hr | $0.2926 USD/hr | 97.53 % |
| 4 Core (Arm) | $0.60 USD/hr | $0.0122 USD/hr | $0.5878 USD/hr | 97.97 % |
| 8 Core (Arm) | $1.20 USD/hr | $0.0226 USD/hr | $1.1774 USD/hr | 98.12 % |
| 16 Core (Arm) | $2.40 USD/hr | $0.0443 USD/hr | $2.3557 USD/hr | 98.15 % |

### Customization and Control

* **Custom Hardware and Software:** You have complete control over the hardware (CPU, RAM, storage) and software environment of your runners. This allows you to:
    * Instead of the default Ubuntu-based GitHub Actions Runner image, use a specific Linux operating system image. This runner has been tested with Debian (`debian-12`), Ubuntu (`ubuntu-24.04`), Fedora Linux (`fedora-41`), Rocky Linux (`rocky-9`), openSUSE Leap (`opensuse-15`) and custom image (snapshot).
    * Install specific dependencies or tools that might not be available on GitHub-managed runners.
    * Optimize performance for your specific workloads.
* **ARM architecture:** If you need to build for architectures other than `x86_64` (Intel, AMD), you have full control to set up the appropriate  Arm-based `arm64` (Ampere Altra) runner environment.
* **Network Access and Security:** You have more control over network access and security. You can access private resources within your Hetzner Cloud network or other private networks via VPNs.
* **Larger Disk Space:** If your builds require a lot of disk space for dependencies, build artifacts, or large files, you can easily provision servers with larger disks (up to 960 GB) on Hetzner Cloud. GitHub-managed runners have limited disk space.

## Usage

Prepare your workflow for Hetzner Cloud self-hosted runners:

1. **Create a fine-grained GitHub Personal Access Token (PAT)** with "Read and write" access to "Administration"
    * [GitHub](https://github.com/settings/personal-access-tokens) → Settings → Developer Settings → Personal access tokens →
Fine-grained personal access tokens
    * [More Help](https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/managing-your-personal-access-tokens)
1. **Generate an Hetzner Cloud API token** with "Read & Write" permissions in the Hetzner Cloud Console
    * [Hetzner Cloud Console](https://console.hetzner.cloud/) → Select project → Security → API Tokens
    * [More Help](https://docs.hetzner.com/cloud/api/getting-started/generating-api-token)
1. **Add both tokens as repository secrets:**
    * GitHub → Select repository → Settings → Secrets and variables → Actions → New repository secrets
        * `PERSONAL_ACCESS_TOKEN`: Your GitHub Personal Access Token
        * `HCLOUD_TOKEN`: Your Hetzner Cloud API Token
    * [More Help](https://docs.github.com/actions/security-guides/encrypted-secrets)
1. **Create or adapt your workflow** following the example below.

## Example

Example GitHub Actions Workflow:

```yml
name: "Example"
on:
  workflow_dispatch:

jobs:
  create-runner:
    name: Create Hetzner Cloud runner
    runs-on: ubuntu-latest
    outputs:
      label: ${{ steps.create-hcloud-runner.outputs.label }}
      server_id: ${{ steps.create-hcloud-runner.outputs.server_id }}
    steps:
      - name: Create runner
        id: create-hcloud-runner
        uses: Cyclenerd/hcloud-github-runner@v1
        with:
          mode: create
          github_token: ${{ secrets.PERSONAL_ACCESS_TOKEN }}
          hcloud_token: ${{ secrets.HCLOUD_TOKEN }}
          server_type: cx22
          location: nbg1  # Nuremberg, Germany
          image: rocky-9 # Rocky Linux 9

  do-the-job:
    name: Do the job on the runner
    needs: create-runner # required to start the main job when the runner is ready
    runs-on: ${{ needs.create-runner.outputs.label }} # run the job on the newly created runner
    steps:
      - name: Hello from runner
        run: |
          dnf install podman -y
          podman run "quay.io/podman/hello:latest"

  delete-runner:
    name: Delete Hetzner Cloud runner
    needs:
      - create-runner # required to get output from the create-runner job
      - do-the-job # required to wait when the main job is done
    runs-on: ubuntu-latest
    if: ${{ always() }} # required to stop the runner even if the error happened in the previous jobs
    steps:
      - name: Delete runner
        uses: Cyclenerd/hcloud-github-runner@v1
        with:
          mode: delete
          github_token: ${{ secrets.PERSONAL_ACCESS_TOKEN }}
          hcloud_token: ${{ secrets.HCLOUD_TOKEN }}
          name: ${{ needs.create-runner.outputs.label }}
          server_id: ${{ needs.create-runner.outputs.server_id }}
```

## Inputs

> [!TIP]
> Use an SSH key ID (`ssh_key`) to disable root password generation and Hetzner Cloud email notifications.

| Name                | Required | Description | Default |
|---------------------|----------|-------------|---------|
| `create_wait`       |   | Wait up to `create_wait` retries (10 sec each) to create the Server resource via the Hetzner Cloud API. Retry if: Resource is not available ([Limited availability of Cloud plans](https://status.hetzner.com/incident/aa5ce33b-faa5-4fd0-9782-fde43cd270cf)). | `360` (1 hour) |
| `delete_wait`       |   | Wait up to `delete_wait` retries (10 sec each) to delete the Server resource via the Hetzner Cloud API. Retry if: Temporary outage of the API ([Fault report on Cloud API and Cloud Console](https://status.hetzner.com/incident/440e6b5f-249c-45fd-8074-e5d79cc4e2a6)). | `360` (1 hour) |
| `enable_ipv4`       |   | Attach an IPv4 on the public NIC (true/false). If false, no IPv4 address will be attached. Warning: The GitHub API requires IPv4. Disabling it will result in connection failures. | `true` |
| `enable_ipv6`       |   | Attach an IPv6 on the public NIC (true/false). If false, no IPv6 address will be attached. | `true` |
| `github_token`      | ✓ (always) | Fine-grained GitHub Personal Access Token (PAT) with 'Read and write' access to 'Administration' assigned. |  |
| `hcloud_token`      | ✓ (always) | Hetzner Cloud API token with 'Read & Write' permissions assigned. |  |
| `image`             |   | Name or ID (integer) of the Image the Server is created from. | `ubuntu-24.04` (Ubuntu 24.04) |
| `location`          |   | Name of Location to create Server in. | `nbg1` (Nürnberg 1) |
| `mode`              | ✓ (always) | Choose either `create` to create a new GitHub Actions Runner or `delete` to delete a previously created one. |  |
| `name`              | ✓ (mode `delete`, optional for mode `create`) | The name for the server and label for the GitHub Actions Runner (must be unique within the project and conform to hostname rules: `^[a-zA-Z0-9_-]{1,64}`). | `gh-runner-[RANDOM-INT]` |
| `network`           |   | Network ID (integer) which should be attached to the Server private network interface at the creation time. | `null` |
| `pre_runner_script` |   | Specifies bash commands to run before the GitHub Actions Runner starts. It's useful for installing dependencies with apt-get, dnf, zypper etc. |  |
| `primary_ipv4`      |   | ID (integer) of the IPv4 Primary IP to use. If omitted and `enable_ipv4` is true, a new IPv4 Primary IP will automatically be created. | `null` |
| `primary_ipv6`      |   | ID (integer) of the IPv6 Primary IP to use. If omitted and `enable_ipv6` is true, a new IPv6 Primary IP will automatically be created. | `null` |
| `runner_dir`        |   | GitHub Actions Runner installation directory (created automatically; no trailing slash). | `/actions-runner` |
| `runner_version`    |   | GitHub Actions Runner version (omit "v"; e.g., "2.321.0"). "latest" will install the latest version. "skip" will skip the installation. A working installation is expected in the `runner_dir`. | `latest` |
| `runner_wait`       |   | Wait up to `runner_wait` retries (10 sec each) for runner registration. | `60` (10 min) |
| `server_id`         | ✓ (mode `stop`) | ID (integer) of Hetzner Cloud Server to delete. | |
| `server_type`       |   | Name of the Server type this Server should be created with. | `cx22` (Intel x86, 2 vCPU, 4GB RAM, 40GB SSD) |
| `server_wait`       |   | Wait up to `server_wait` retries (10 sec each) for the Hetzner Cloud Server to start. | `30` (5 min) |
| `ssh_key`           |   | SSH key ID (integer) which should be injected into the Server at creation time. | `null` |

## Outputs

| Name        | Description |
|-------------|-------------|
| `label`     | This label uniquely identifies a GitHub Actions runner, used both to specify which runner a job should execute on via the `runs-on` property and to delete the runner when it's no longer needed. |
| `server_id` | This is the Hetzner Cloud Server ID of the runner, used to delete the server when the runner is no longer required. |

## Snippets

The following `hcloud` CLI commands can help you find the required input values.

**List Locations:**

```bash
hcloud location list --output "columns=NAME,DESCRIPTION,NETWORK_ZONE,COUNTRY,CITY" --sort "name"
```

```text
NAME   DESCRIPTION             NETWORK ZONE   COUNTRY   CITY
ash    Ashburn, VA             us-east        US        Ashburn, VA
fsn1   Falkenstein DC Park 1   eu-central     DE        Falkenstein
hel1   Helsinki DC Park 1      eu-central     FI        Helsinki
hil    Hillsboro, OR           us-west        US        Hillsboro, OR
nbg1   Nuremberg DC Park 1     eu-central     DE        Nuremberg
sin    Singapore               ap-southeast   SG        Singapore
```

**List Server Types:**

```bash
hcloud server-type list --output "columns=NAME,CORES,CPU_TYPE,ARCHITECTURE,MEMORY,DISK"
```

```text
NAME    CORES   CPU TYPE    ARCHITECTURE   MEMORY     DISK
cpx11   2       shared      x86            2.0 GB     40 GB
cpx21   3       shared      x86            4.0 GB     80 GB
cpx31   4       shared      x86            8.0 GB     160 GB
cpx41   8       shared      x86            16.0 GB    240 GB
cpx51   16      shared      x86            32.0 GB    360 GB
cax11   2       shared      arm            4.0 GB     40 GB
cax21   4       shared      arm            8.0 GB     80 GB
cax31   8       shared      arm            16.0 GB    160 GB
cax41   16      shared      arm            32.0 GB    320 GB
ccx13   2       dedicated   x86            8.0 GB     80 GB
ccx23   4       dedicated   x86            16.0 GB    160 GB
ccx33   8       dedicated   x86            32.0 GB    240 GB
ccx43   16      dedicated   x86            64.0 GB    360 GB
ccx53   32      dedicated   x86            128.0 GB   600 GB
ccx63   48      dedicated   x86            192.0 GB   960 GB
cx22    2       shared      x86            4.0 GB     40 GB
cx32    4       shared      x86            8.0 GB     80 GB
cx42    8       shared      x86            16.0 GB    160 GB
cx52    16      shared      x86            32.0 GB    320 GB
```

**List x86_64 Images:**

```bash
hcloud image list --architecture "x86" --output "columns=NAME,DESCRIPTION" --type "system" --sort "name"
```

```text
NAME              DESCRIPTION
alma-8            AlmaLinux 8
alma-9            AlmaLinux 9
centos-stream-9   CentOS Stream 9
debian-11         Debian 11
debian-12         Debian 12
fedora-39         Fedora 39
fedora-40         Fedora 40
fedora-41         Fedora 41
opensuse-15       openSUSE Leap 15
rocky-8           Rocky Linux 8
rocky-9           Rocky Linux 9
ubuntu-20.04      Ubuntu 20.04
ubuntu-22.04      Ubuntu 22.04
ubuntu-24.04      Ubuntu 24.04
```

**List ARM Images:**

```bash
hcloud image list --architecture "arm" --output "columns=NAME,DESCRIPTION" --type "system" --sort "name"
```

**Create custom Image:**

Before you create a custom image of your Hetzner Cloud Server, [clean](https://cloudinit.readthedocs.io/en/latest/reference/cli.html#clean) up the server by running on the server:

```bash
cloud-init clean --logs --machine-id --seed --configs all
```

Important: Do not shut down the server.

Create Image:

```bash
hcloud server create-image --type "snapshot" --description "github-runner-image" "[SERVER-ID]"
```

Tip: Create custom images with HashiCorp [Packer](https://github.com/hetznercloud/packer-plugin-hcloud).

**List custom Images:**

```bash
hcloud image list --output "columns=ID,DESCRIPTION,ARCHITECTURE,DISK_SIZE" --type "snapshot" --sort "name"
```

**List Primary IPs:**

```bash
hcloud primary-ip list --output "columns=ID,TYPE,NAME,IP,ASSIGNEE"
```

**List Networks:**

```bash
hcloud network list --output "columns=ID,NAME,IP_RANGE,SERVERS"
```

**List SSH Keys:**

```bash
hcloud ssh-key list --output "columns=ID,NAME"
```

## Security

> We recommend that you only use self-hosted runners with private repositories.
> This is because forks of your public repository can potentially run dangerous code on your self-hosted runner machine by creating a pull request that executes the code in a workflow.

For security considerations, see the [GitHub documentation](https://docs.github.com/en/actions/hosting-your-own-runners/managing-self-hosted-runners/about-self-hosted-runners#self-hosted-runner-security).

## Contributing

Have a patch that will benefit this project?
Awesome! Follow these steps to have it accepted.

1. Please read [how to contribute](CONTRIBUTING.md).
1. Fork this Git repository and make your changes.
1. Create a Pull Request.
1. Incorporate review feedback to your changes.
1. Accepted!

## Credits

This GitHub Action is based on the idea and implementation of [Volodymyr Machula](https://github.com/machulav) for [AWS EC2 runner](https://github.com/machulav/ec2-github-runner).

Two additional implementations for GitHub Actions runners on Hetzner Cloud are also worth noting:

* [GitHub Action for Hetzner Cloud Self-Hosted Runners](https://github.com/stonemaster/hetzner-github-runner) from [André Stein](https://github.com/stonemaster)
* [Ephemeral GitHub runners on Hetzner Cloud](https://github.com/Kwarf/hetzner-ephemeral-runner) from [Jimmy Bergström](https://github.com/Kwarf)

## License

All files in this repository are under the [Apache License, Version 2.0](LICENSE) unless noted otherwise.
