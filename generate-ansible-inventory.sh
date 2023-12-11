#!/usr/bin/env bash

set -eou pipefail

temp_file="temp_inventory_data.txt"
inventory_file="ansible/inventory.ini"

gcloud compute instances list --format="table[no-heading](NAME,EXTERNAL_IP)" --filter="name ~ gke" > "$temp_file"
echo "[gke]" > "$inventory_file"
while IFS= read -r line; do
    name=$(echo $line | awk '{print $1}')
    ip=$(echo $line | awk '{print $2}')
    echo "$name ansible_host=$ip" >> "$inventory_file"
done < "$temp_file"

if [ $# -eq 2 ]; then
    ip_alias_base=$1
    ip_alias_count=$2

    gcloud compute instances list --format="table[no-heading](NAME,EXTERNAL_IP)" --filter="name ~ loadgen" > "$temp_file"
    echo "[loadgen]" >> "$inventory_file"
    i=2
    while IFS= read -r line; do
        name=$(echo $line | awk '{print $1}')
        ip=$(echo $line | awk '{print $2}')
        echo "$name ansible_host=$ip ip_alias_subnet=\"$ip_alias_base.$i.0/24\" ip_alias_count=$ip_alias_count" >> "$inventory_file"
        # echo "$name ansible_host=$ip" >> "$inventory_file"
        i=$((i+1))
    done < "$temp_file"
fi

rm "$temp_file"
cat "$inventory_file"
