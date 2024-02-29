# Overview
In this folder, create a mac address folder and place the encrypted token files for each service. The
script that encodes this data takes the encrypted output and base64 encodes
it before returning it to the console. The decryption script expects to 
receive base64 data and parses it before performing the decryption on the
TPM module.

# Process

To prepare a machine for use, a few steps must be taken. In the provided grub config, an entry exists called `Fedora CoreOS 39 with TPM Scripts`. This entry loads the public SSH key provided, which should allow you to connect to the target machine. The TPM related scripts will also be downloaded. Once in the machine, perform the following steps:

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

# Examples
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

# Notes
The base64 encoded key resides on a single line, but may appear to wrap in your text editor.

Any filenames containing the string "token" are excluded from the repo via .gitignore.

# Troubleshooting

### Problem: `Persistent handle 0x8101FFFF already exists.`

If this occurs on your first run, then something else is already using that handle, and it is probably important. Your best bet is to run `sudo tpm2_getcap handles-persistent` to see the full list of handles in use. Choose one that is not taken, and update the scripts to use your new value.

### Problem: TPM is locked

If you receive messages about your TPM being locked, this can mean one of a few things:
1. You've locked yourself out of the TPM. TPMs have an inherent security feature that prevents dictionary attacks, and will lock for a period of time if non-root users try to execute commands against them. If you forget to run the scripts as `sudo`, you'll hit this. You can either wait for the timeout to lapse, or run `sudo tpm2_dictionarylockout -c` to free the lock.
1. Your TPM has a password set. If this is the case, you'll need to remove the TPM password in your BIOS. **Proceed at your own risk**.