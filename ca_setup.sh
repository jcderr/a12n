#!/bin/bash
USAGE="usage: ca_setup.sh [-h | --help] [command] [args]"

show_usage() {
  echo $USAGE
}

create() {
  CLUSTER_NAME=${1}
  vault mount -path=k8s/${CLUSTER_NAME}/pki pki
  vault mount-tune -max-lease-ttl=2160h -default-lease-ttl=720h k8s/${CLUSTER_NAME}/pki

  vault write k8s/radon/pki/config/urls \
      issuing_certificates="${VAULT_ADDR}/v1/k8s/${CLUSTER_NAME}/pki/ca" \
      crl_distribution_points="${VAULT_ADDR}/v1/k8s/${CLUSTER_NAME}/pki/crl"
}

load() {
  CLUSTER_NAME=${1}

  TMPD=$(mktemp -d -t catemp)
  pushd $TMPD
    set -e
    aws s3 sync ${KOPS_STATE_STORE}/${CLUSTER_NAME}${A12N_ROOT_DN}/pki/private/ca/ .
    aws s3 sync ${KOPS_STATE_STORE}/${CLUSTER_NAME}${A12N_ROOT_DN}/pki/issued/ca/ .
    cat *.crt *.key > ca_bundle.pem

    vault write k8s/${CLUSTER_NAME}/pki/config/ca pem_bundle=@ca_bundle.pem
  popd
}

config() {
  set -x
  CLUSTER_NAME=${1}
  GROUP_NAME=${2:-developers}
  TMPD=$(mktemp -d -t catemp)

  # ensure group exists before continuing
  vault read -format=json sys/policy/${GROUP_NAME} || exit 1

  pushd $TMPD
    vault read -format=json sys/policy/${GROUP_NAME} | jq -r .data.rules > rules.hcl
    cat <<EOT >> rules.hcl
path "k8s/${CLUSTER_NAME}/pki/issue/${GROUP_NAME}" {
  policy = "write"
}
EOT
  vault policy-write ${GROUP_NAME} rules.hcl
  popd
}

ACTION=""

while [[ $# -gt 0 ]]; do
    case $1 in
        -h | --help)
        show_usage "$2"
        ;;

        create)
        [[ -z "${ACTION}" ]] && ACTION=create
        ;;

        load)
        [[ -z "${ACTION}" ]] && ACTION=load
        ;;

        config)
        [[ -z "${ACTION}" ]] && ACTION=config
        ;;

        --)
        break
        ;;

        --*)
        error "invalid long option: $1"
        ;;

        -?)
        error "invalid option: $1"
        ;;

        # Split apart combined short options
        -*)
        split=$1
        shift
        set -- $(echo "$split" | cut -c 2- | sed 's/./-& /g') "$@"
        continue
        ;;

        # Done with options
        *)
        break
        ;;
    esac

  shift
done

"$ACTION" $@
