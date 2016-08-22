#!/bin/bash
# SPDX-license-identifier: Apache-2.0
##############################################################################
# Copyright (c) 2016 Orange and others.
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Apache License, Version 2.0
# which accompanies this distribution, and is available at
# http://www.apache.org/licenses/LICENSE-2.0
##############################################################################
set +e
set -o nounset

##
## Functions
##
function exit_on_error {
    RES=$1
    MSG=$2
    if [ $RES != 0 ]; then
        echo "FAILED - $MSG"
        exit $RES
    fi
}

##
## Create LAB_CONFIG folder if not exists
##

mkdir -p $LAB_CONFIG

##
## Set Joid pod config name
##

case $NODE_NAME in
    *virtual*)
        POD=default ;;
    *)
        POD=$NODE_NAME ;;
esac
export POD_NAME=${POD/-}

##
## Redeploy MAAS or recover the previous config
##

cd $WORKSPACE/ci
if [ -e "$LAB_CONFIG/environments.yaml" ] && [ "$MAAS_REINSTALL" == "false" ]; then
    echo "------ Recover Juju environment to use MAAS ------"
    cp $LAB_CONFIG/environments.yaml .
    cp $LAB_CONFIG/deployment.yaml .
    if [ -e $LAB_CONFIG/deployconfig.yaml ]; then
        cp $LAB_CONFIG/deployconfig.yaml .
    fi
else
    echo "------ Redeploy MAAS ------"
    ./00-maasdeploy.sh $POD_NAME
    exit_on_error $? "MAAS Deploy FAILED"
fi

##
## Configure Joid deployment
##

# Based on scenario naming we can get joid options
# naming convention:
#    os-<controller>-<nfvfeature>-<mode>[-<extrastuff>]
# With parameters:
#    controller=(nosdn|odl_l3|odl_l2|onos|ocl)
#       No odl_l3 today
#    nfvfeature=(kvm|ovs|dpdk|nofeature)
#       '_' list separated.
#    mode=(ha|noha)
#    extrastuff=(none)
#       Optional field - Not used today

IFS='-' read -r -a DEPLOY_OPTIONS <<< "${DEPLOY_SCENARIO}--"
#last -- need to avoid nounset error

SDN_CONTROLLER=${DEPLOY_OPTIONS[1]}
NFV_FEATURES=${DEPLOY_OPTIONS[2]}
HA_MODE=${DEPLOY_OPTIONS[3]}
EXTRA=${DEPLOY_OPTIONS[4]}

if [ "$SDN_CONTROLLER" == 'odl_l2' ] || [ "$SDN_CONTROLLER" == 'odl_l3' ]; then
    SDN_CONTROLLER='odl'
fi
if [ "$HA_MODE" == 'noha' ]; then
    HA_MODE='nonha'
fi

# Add extra to features
if [ "$EXTRA" != "" ];then
    NFV_FEATURES="${NFV_FEATURES}_${EXTRA}"
fi

# temporary sfc feature is availble only on onos and trusty
if [ "$NFV_FEATURES" == 'sfc' ] && [ "$SDN_CONTROLLER" == 'onos' ];then
    UBUNTU_DISTRO=trusty
fi

##
## Configure Joid deployment
##

echo "------ Deploy with juju ------"
echo "Execute: ./deploy.sh -t $HA_MODE -o $OS_RELEASE -s $SDN_CONTROLLER -l $POD_NAME -d $UBUNTU_DISTRO -f $NFV_FEATURES"

./deploy.sh -t $HA_MODE -o $OS_RELEASE -s $SDN_CONTROLLER -l $POD_NAME -d $UBUNTU_DISTRO -f $NFV_FEATURES
exit_on_error $? "Main deploy FAILED"

##
## Set Admin RC
##
JOID_ADMIN_OPENRC=$LAB_CONFIG/admin-openrc
echo "------ Create OpenRC file [$JOID_ADMIN_OPENRC] ------"

# get controller IP
case "$SDN_CONTROLLER" in
    "odl")
        SDN_CONTROLLER_IP=$(juju status odl-controller/0 |grep public-address|sed -- 's/.*\: //')
        ;;
    "onos")
        SDN_CONTROLLER_IP=$(juju status onos-controller/0 |grep public-address|sed -- 's/.*\: //')
        ;;
    *)
        SDN_CONTROLLER_IP='none'
        ;;
esac
SDN_PASSWORD='admin'

# export the openrc file by getting the one generated by joid and add SDN
# controller for Functest
cp ./cloud/admin-openrc $JOID_ADMIN_OPENRC
cat << EOF >> $JOID_ADMIN_OPENRC
export SDN_CONTROLLER=$SDN_CONTROLLER_IP
export SDN_PASSWORD=$SDN_PASSWORD
EOF

##
## Backup local juju env
##

echo "------ Backup Juju environment ------"
cp environments.yaml $LAB_CONFIG/
cp deployment.yaml $LAB_CONFIG/
if [ -e deployconfig.yaml ]; then
    cp deployconfig.yaml $LAB_CONFIG
fi

##
## Exit success
##

echo "Deploy success"
exit 0
