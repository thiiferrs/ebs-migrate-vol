#!/bin/bash
# Script for migrate ebs volumes from gp2* to gp3*

aws ec2 describe-volumes --filters Name=volume-type,Values=gp2 > describe_volumes.json
ID_VOL_LIST=$(jq '.Volumes[].Attachments[].VolumeId' describe_volumes.json | sed 's/"//g')

for VOL_ID in $ID_VOL_LIST; do
  echo "Criando snapshot do volume $VOL_ID"
  SNAPSHOT_ID=$(aws ec2 create-snapshot --volume-id $VOL_ID --description "gp3 migrate - snapshot from volume $VOL_ID" --no-cli-pager | jq '.SnapshotId' | sed 's/"//g')
  while [ "$exit_status" != "0" ]; do
    SNAPSHOT_STATE="$(aws ec2 describe-snapshots --filters Name=snapshot-id,Values=$SNAPSHOT_ID --query 'Snapshots[0].State')"
    SNAPSHOT_PROGRESS="$(aws ec2 describe-snapshots --filters Name=snapshot-id,Values=$SNAPSHOT_ID --query 'Snapshots[0].Progress')"
	echo "### Snapshot-id $SNAPSHOT_ID creation: state is $SNAPSHOT_STATE, $SNAPSHOT_PROGRESS"
    aws ec2 wait snapshot-completed --snapshot-ids "$SNAPSHOT_ID"
    exit_status="$?"
  done
  exit_status=""
  aws ec2 modify-volume --volume-type gp3 --volume-id $VOL_ID --no-cli-pager >> migrate.output
  echo "$VOL_ID - migrado!"
done
