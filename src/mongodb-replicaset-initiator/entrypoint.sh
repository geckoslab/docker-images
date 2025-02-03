#!/bin/bash

sleep 10;
echo "Initiating MongoDB replica set..."

PRIMARY_NODE=$MONGO_PRIMARY;
SECONDARY_NODES=();

# Utils
get_env_key() {
  local ENV=$1;
  local key=$(echo $ENV | cut -d'=' -f1);
  echo $key;
}

get_env_value() {
  local ENV=$1;
  local value=$(echo $ENV | cut -d'=' -f2);
  echo $value;
}

get_host() {
  local NODE=$1;
  local HOST=$(echo $NODE | cut -d':' -f1);
  echo $HOST;
}

get_port() {
  local NODE=$1;
  local PORT=$(echo $NODE | cut -d':' -f2);
  echo $PORT;
}

# Check if replica set name is provided or throw error
if [ -z "REPLICASET_NAME" ]; then
  echo "Replica set name not found!";
  exit 1;
fi

# Prepare primary node mongo shell or throw error
if [ -z "$PRIMARY_NODE" ]; then
  echo "Primary node not found!";
  exit 1;
else
  PRIMARY_HOST=$(get_host $PRIMARY_NODE);
  PRIMARY_PORT=$(get_port $PRIMARY_NODE);
  PRIMARY_MONGOSH="mongosh --host $PRIMARY_HOST --port $PRIMARY_PORT";
fi

# Test connection to primary node
rs=$($PRIMARY_MONGOSH --eval "db" 2>&1);
if [ $? -ne 0 ]; then
  echo "Failed to connect to primary node with error: [$rs]";
  exit 0;
else
  echo "Connected to primary node successfully!";
fi

# Scanning all environment variables for finding secondary nodes
for ENV in $(env)
  do
    key=$(get_env_key $ENV);
    value=$(get_env_value $ENV);

    if [[ $key =~ MONGO_SECONDARY_[0-9]* ]]; then
      SECONDARY_NODES+=($value);
      echo "Found secondary node: $value";
    fi
  done

# Check status of replica set, if not initiated then initiate it, otherwise exit
echo "Checking replica set status...";
rsStatus=$($PRIMARY_MONGOSH --eval "rs.status()" 2>&1);
if [[ $rsStatus =~ "no replset config has been received" ]]; then
  echo "Replica set is not initiated, initiating replica set...";
  rs=$($PRIMARY_MONGOSH --eval "rs.initiate({_id: '$REPLICASET_NAME', members: [{_id: 0, host: '$PRIMARY_HOST:$PRIMARY_PORT'}]})" 2>&1);

  # Re-check status of replica set
  rsStatus=$($PRIMARY_MONGOSH --eval "rs.status()" 2>&1);
  if [[ $rsStatus =~ "no replset config has been received" ]]; then
    echo "Failed to initiate replica set!";
    exit 0;
  else
    echo "Replica set initiated successfully!";

    # Add secondary nodes to replica set
    for NODE in "${SECONDARY_NODES[@]}"
      do
        HOST=$(get_host $NODE);
        PORT=$(get_port $NODE);
        rs=$($PRIMARY_MONGOSH --eval "rs.add('$HOST:$PORT')" 2>&1);
      done
  fi
else
  echo "Replica set is already initiated!";
  exit 0;
fi
