# UEFI-PXE-AGENTS

<!-- TOC start (generated with https://github.com/derlin/bitdowntoc) -->

 - [Overview](#overview)
 - [UEFI and SecureBoot](#uefi-and-secureboot)
 - [TFTP](#tftp)
 - [HTTP](#http)
 - [DHCP](#dhcp)
 - [Machine Prep](#machine-prep)
     * [Process](#process)
     * [Examples](#examples)
     * [Notes](#notes)
     * [Troubleshooting](#troubleshooting)
<!--         + [Problem: `Persistent handle 0x8101FFFF already exists.`](#problem-persistent-handle-0x8101ffff-already-exists)
         + [Problem: TPM is locked](#problem-tpm-is-locked) -->

<!-- TOC end -->

<!-- TOC --><a name="overview"></a>
## Overview

This project exists to guide users through the process of bootstrapping machines from bare-metal to fully-authenticated container-based agents using basic networking protocols and hardware authentication.

This is one solution to a problem commonly referred to as the [Secret Zero Dilemma](https://www.hashicorp.com/resources/starbucks-secrets-at-the-retail-edge-with-hashicorp-vault).

Once initial setup is complete, a new machine can be provisioned to securely communicate with services such as GitHub Actions or Terraform Cloud in minutes, all running directly from RAM.

The bootstrapping process is outlined in the following diagram, assuming that a UDM Pro is used for DHCP and a Synology NAS is used for serving the TFTP and HTTP requests:

```mermaid
flowchart TB
    Machine[Machine<br>MAC: 00:00:00:00:00:00]
    UDM[UDM Pro]
    Synology[Synology NAS]
    subgraph DHCP_Options["DHCP Options"]
        direction LR
        IP["DHCP 50: IP of Machine"]
        TFTP_IP["DHCP 66: IP of TFTP Server"]
        Filename["DHCP 67: Filename (shim.efi)"]
    end
    subgraph TFTP_Requests["TFTP Requests"]
        direction TB
        shim["shim.efi"]
        grubx64["grubx64.efi"]
        grubcfg["grub.cfg"]
        kernel["Kernel (vmlinuz)"]
        initrd["Initial Ramdisk<br>(initrd.img)"]
        rootfs["Root Filesystem<br>(rootfs.img)"]
        shim --> grubx64 --> grubcfg --> kernel --> initrd --> rootfs
    end
    subgraph Ignition["Ignition"]
        direction LR
        ssh["Place SSH Public Key"]
        scripts["Download Scripts"]
        data["Download Encrypted Keys"]
        subgraph tf["TF Service"]
            direction TB
            decrypttf["Decrypt TF Key"]
            starttf["Start TF Agent<br>Podman Container"]
            decrypttf --> starttf
        end
        subgraph gh["GH Service"]
            direction TB
            decryptgh["Decrypt GH Key"]
            startgh["Start GH Agent<br>Podman Container"]
            decryptgh --> startgh
        end
    end
    Machine <--> DHCP_Options <--> UDM
    Machine <--> TFTP_Requests <--> Synology[Synology NAS]
    Machine <--> Ignition <--> Synology[Synology NAS]
```

<!-- TOC --><a name="uefi-and-secureboot"></a>
## UEFI and SecureBoot

Provided in this repository are `shim.efi` and `grubx64.efi`, pulled with yum on an x86_64 Fedora 39 container. No other linux distributions have been tested with these files, and you may encounter issues with SecureBoot if you use another distro, as grub checks the certificate of the kernel before booting. This process is described in this article: https://access.redhat.com/articles/5254641

To retrieve these files on your own, you can refer to this guide from RedHat: https://www.redhat.com/sysadmin/pxe-boot-uefi

The process is intended for RHEL, but works with Fedora as well. I've modified and consolidated these steps here:

On a machine with podman (or docker):
```bash
# Start and attach to a Fedora container
podman run -it --rm --name fedora fedora:latest
```

Inside of the container:
```bash
# Change to an empty directory
cd tmp/

# Check for package updates
yum check-update

# Install shim (which also installs grub2 as a dependency)
yum install -y shim-x64.x86_64
```

In a new terminal on the host machine:
```bash
# Copy shim.efi to the host machine
podman cp fedora:/boot/efi/EFI/fedora/shim.efi .

# Copy grubx64.efi to the host machine
podman cp fedora:/boot/efi/EFI/fedora/grubx64.efi .
```

The shim and grub efi files should now exist in your current directory on the host machine.

I am uncertain of the redistribution rights of these binaries, given that they are open-source but owned by RedHat. @redhat, ping me if they need to be removed. These binaries are signed by Microsoft, which is why they work with SecureBoot. I did not have any luck compiling them myself, however the projects responsible for their maintenance are:

 - shim: https://github.com/rhboot/shim
 - grub: https://git.savannah.gnu.org/cgit/grub.git
 - Fedora CoreOS: https://github.com/coreos/fedora-coreos-config
    
<!-- TOC --><a name="tftp"></a>
## TFTP

The process of setting up TFTP varies depending on hardware/software, but settings remain consistent across implementations. For a Synology Diskstation, you'll need to create a file share (I named mine `pxeboot`) and populate it with the contents of this repository, and place the Fedora ISO in the `isos` folder.

Under `Control Panel -> File Services -> Advanced`, you'll need to designate this file share as your TFTP root and enable read-only access across the network:

![Synology TFTP](/docs/synology-tftp.png)

Once those settings are established, you'll need to set up HTTP file access to the same directory.

<!-- TOC --><a name="http"></a>
## HTTP

You can host these files anywhere, however I found it to be easiest to just tack another Synology service on to the same file share.

Under `Web Station -> Web Service`, create a web service that points to the pxeboot share:

![Synology Web Service](/docs/synology-web-service.png)

You'll then need to create a web portal that corresponds to this service.

Under `Web Station -> Web Portal`, create an HTTP portal pointing to the previously made Web Service. You'll need to specify a port different from the default. For this example, I've chosen 9876.

![Synology Web Portal](/docs/synology-web-portal.png)

Once established, you should be able to access the files in the pxeboot file share through a browser request.

Example: http://10.0.0.100:9876/ignition/_default.ign

Note: HTTP is used because Ignition rejects self-signed certs by default. This can be fixed, but I've not yet prioritized it, as the sensitive tokens are encrypted on the share.

<!-- TOC --><a name="dhcp"></a>
## DHCP

DHCP provisions the IP address of the machine, and in PXE setups, also provides the address of the TFTP server and the path of the bootloader file on that server. Each DHCP server implementation may be slightly different, but the general principles remain consistent. In short, you'll need to update your DHCP settings to serve two values:

1. Option 66: The IP of your TFTP Server
1. Option 67: The bootfile path from that TFTP server

On a UDM Pro, the settings appear like this:

![UDM Pro Settings](docs/udm-pro.png)

Inside of the settings for a particular network, you'll need to check the Network Boot flag, specify the IP of the TFTP server, and specify shim.efi as the file name. You will also need to check the TFTP Server box, and again enter the IP of the TFTP server.

<!-- TOC --><a name="machine-prep"></a>
## Machine Prep

Each machine that uses encrypted data requires a brief setup process to prepare it. At a high level, these steps are: 
1. Populate config files with your environment-specific values
1. PXE boot the machine to a helper distro (`Fedora CoreOS 39 with TPM Scripts`)
1. Create a persistent TPM key on the machine
1. Encrypt and save the tokens
1. In the `/data` directory, create a folder for the machine
1. Place the encrypted token files for each service within it
1. Create an ignition file for the machine
1. Add a menuentry to the grub config for the machine

<!-- TOC --><a name="process"></a>
### Process

If this is your first time preparing a machine, you will need to update the [/ignition/_default.ign](/ignition/_default.ign) and [/grub.cfg](/grub.cfg) files with details from your environment.

1. Insert your SSH key into `_default.ign`
    - If you do not have a public key, you can generate one on a machine with openssh:
        ```bash
        ssh-keygen -t ed25519
        # Your responses to the prompts will determine whether the
        # key has a password, and will determine the output file names.
        # Please handle the private key responsibly. By default, the private key
        # file will be ~/.ssh/id_ed25519 and the public key file will be
        # ~/.ssh/id_ed25519.pub

        # A comment with the username@machinename will automatically appended
        # to the public key file. Run the following command to get the key
        # without that comment for use in the ignition file.
        cat id_ed25519.pub | cut -d ' ' -f 1,2
        ```
    - Copy the public key without the username@machine comment at the end, and replace the existing entry under `sshAuthorizedKeys` in [/ignition/_default.ign](/ignition/_default.ign)
    - This entry loads the public SSH key provided, which should allow you to connect to the target machine for initial setup
1. Update the file URLs in `_default.ign`
    - The default value is `http://10.0.0.100:9876`
    - `Ctrl+H` to find and replace this value with the IP and port from the HTTP setup step
1. Update the Ignition URL in `grub.cfg` - `Fedora CoreOS 39 with TPM Scripts`
    - In the provided grub config, an entry exists called `Fedora CoreOS 39 with TPM Scripts`
    - Update the `ignition.config.url=http://10.0.0.100:9876/ignition/_default.ign` line to match the IP and port from the HTTP setup step

 To prepare a machine for use, a few steps must be taken:

1. PXE Boot the machine to the FCOS TPM Scripts option
    - Ensure you have UEFI IPv4 PXE Booting + SecureBoot enabled
    
1. Create a TPM "persistent handle"
    - This is the TPM term for a private-key pair that persists across reboots
    - Unfortunately, these keys are referenced via hex value between 0x81000000 - 0x817FFFFF, not by name
    - In my research, I did not find a definitive guide for how to choose a handle value; rather, the suggestion was to just choose one that was not taken by the system. It seems that Windows uses the lower range, so I picked an easy value to remember higher in the range. Hard coding this is certainly not ideal, but for bare-metal machines with a single purpose it won't pose an issue. I would certainly not suggest messing with the TPM on a machine that has an active OS installed, however. **Use at your own risk.**
    - With those details out of the way, we can create the handle. The scripts are placed in the home directory of the systemUser.
    - `sudo ./create_tpm_0x8101FFFF.sh`
    - Success looks like this, preceded by details about the key:
    - `Persistent handle 0x8101FFFF created successfully.`
1. Encrypt your API keys
    - Execute the encryption script once for each key you want to encrypt
    - `sudo ./encrypt_with_tpm_0x8101FFFF.sh`
    - Paste your API key
    - Below the API key, you will see your encrypted, base64 encoded key
1. Save your encrypted key
    - In `/data`, make a folder for the mac of your machine's NIC, with underscores instead of colons
    - Inside of that folder, create the corresponding files for your keys
    - The `00_00_00_00_00_00` folder exists solely for reference

<!-- TOC --><a name="examples"></a>
### Examples
The TPM encrypted keys for GitHub Actions and Terraform Cloud
would similar to the following:

**encrypted_ghaction_token.txt**
```
gw0xdb35GXjgiF9eVCNYGxxFdZzmNvY7m4TE519CGU0Dt7B3/RvTRsMgXyE83NLtspDjInqZQy04QfZVZwiS4V9oOkzI7McjahlUExYPmjI+DsgARm/rhA2gpeqz+BiTeuHM5ASDF7823648opXK/VueHTENiaxa+TeII615YHUmPfD5mi1GWcnpcTQhKa3K9CfrHO2e+ai2dZZdnjFrWp9dmy001amB+TZT5/aCvXr4OfGp6mMsH5z3kSYxcOLR9YLwRcvX5K/caNEnbA7wMFDu/qeYI234/BKJLHKLJHJKjrICz/ob/FXyYfxy39mOb+ocYsz/cj4Z09A==
```

**encrypted_tfcagent_token.txt**
```
gOzMBfSpMvb5F6o6y9OU1qyZaYyS4aOfRa3cRR8/E5wJPL12kuTNZrQqoh+BphgMw4tV82153685146a1asdfajhsdfjkNkrepDIPzDCezBar2h9uusnHMLajV3LmZ5emBhL1r4CcKdPSkRpfjtuR3eeltA+eXoEdfte3cdNq9Xk6GAv8/hvJpXpiajuhsdikjuhr234/wliIs8WCyXcDE6svq/CLjtQ0skBQlVkJYSZ6ILrT62Al6kEPhv6x9O5MRoobEkJo8pVXgW0JawJAlpRlPuMwX2ZQyqYmKQnmJkNR1ydpdxXRQ5qpGlrXv7w==
```

<!-- TOC --><a name="notes"></a>
### Notes
The base64 encoded key resides on a single line, but may appear to wrap in your text editor.

Any filenames containing the string "token" are excluded from the repo via .gitignore.

<!-- TOC --><a name="troubleshooting"></a>
### Troubleshooting

<!-- TOC --><a name="problem-persistent-handle-0x8101ffff-already-exists"></a>
#### Problem: `Persistent handle 0x8101FFFF already exists.`

If this occurs on your first run, then something else is already using that handle, and it is probably important. Your best bet is to run `sudo tpm2_getcap handles-persistent` to see the full list of handles in use. Choose one that is not taken, and update the scripts to use your new value.

<!-- TOC --><a name="problem-tpm-is-locked"></a>
#### Problem: TPM is locked

If you receive messages about your TPM being locked, this can mean one of a few things:
1. You've locked yourself out of the TPM. TPMs have an inherent security feature that prevents dictionary attacks, and will lock for a period of time if non-root users try to execute commands against them. If you forget to run the scripts as `sudo`, you'll hit this. You can either wait for the timeout to lapse, or run `sudo tpm2_dictionarylockout -c` to free the lock.
1. Your TPM has a password set. If this is the case, you'll need to remove the TPM password in your BIOS. **Proceed at your own risk**.