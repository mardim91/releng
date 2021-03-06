#!/bin/bash
#  Licensed to the Apache Software Foundation (ASF) under one   *
#  or more contributor license agreements.  See the NOTICE file *
#  distributed with this work for additional information        *
#  regarding copyright ownership.  The ASF licenses this file   *
#  to you under the Apache License, Version 2.0 (the            *
#  "License"); you may not use this file except in compliance   *
#  with the License.  You may obtain a copy of the License at   *
#                                                               *
#    http://www.apache.org/licenses/LICENSE-2.0                 *
#                                                               *
#  Unless required by applicable law or agreed to in writing,   *
#  software distributed under the License is distributed on an  *
#  "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY       *
#  KIND, either express or implied.  See the License for the    *
#  specific language governing permissions and limitations      *
#  under the License.                                           *

set -o errexit
set -o nounset

cd $WORKSPACE/utils/test/$MODULE_NAME/docker/

# Remove previous containers
docker ps -a | grep "opnfv/$MODULE_NAME" | awk '{ print $1 }' | xargs -r docker rm -f

# Remove previous images
docker images | grep "opnfv/$MODULE_NAME" | awk '{ print $3 }' | xargs -r docker rmi -f

# Start build
docker build --no-cache -t opnfv/$MODULE_NAME:$DOCKER_TAG .

# Push Image
docker push opnfv/$MODULE_NAME:$DOCKER_TAG
