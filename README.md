# A12N

`a12n` is a toolchain we use to load `kops`-created Kubernetes cluster CAs into
hashicorp [vault][1], fetch user TLS certificates, and subsequently configure
our `kubectl` context.

## Configure Vault

We will assume you already have a working Vault service.

* `ca_setup.sh`

    # create the cluster in Vault
    $ ca_setup.sh create [clustername]
    # load cluster CA into Vault
    $ ca_setup.sh load [clustername]
    # configure a role...
    $ ca_setup.sh config [clustername] [rolename]

## Configure kubectl

    $ a12n [clustername]

Optionally, you may need to set the following environment variables.

    * `A12N_ORG_NAME` will influence the name of the kubectl context
    * `A12N_ROOT_DN` will set the domain name the cluster is known under

`A12N_ROOT_DN` is important because some organization may delegate DNS authority.
In our case, Operations uses the root domain, while Product and Test use a `dev`
subdomain.
