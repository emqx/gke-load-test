#!/usr/bin/env bash

set -eou pipefail

ip_alias_base=$1
ip_alias_count=$2
temp_file="temp_inventory_data.txt"
gcloud compute instances list --format="table[no-heading](NAME,EXTERNAL_IP)" --filter="name ~ loadgen" > "$temp_file"

inventory_file="ansible/inventory.ini"
echo "[loadgen]" > "$inventory_file"

i=1
while IFS= read -r line; do
    name=$(echo $line | awk '{print $1}')
    ip=$(echo $line | awk '{print $2}')
    echo "$name ansible_host=$ip ip_alias_subnet=\"$ip_alias_base.$i.0/24\" ip_alias_count=$ip_alias_count" >> "$inventory_file"
    # echo "$name ansible_host=$ip" >> "$inventory_file"
    i=$((i+1))
done < "$temp_file"

rm "$temp_file"
cat "$inventory_file"
