#!/usr/bin/env bash

set -eou pipefail

temp_file="temp_inventory_data.txt"
gcloud compute instances list --format="table[no-heading](NAME,EXTERNAL_IP)" > "$temp_file"

inventory_file="ansible/inventory.ini"
echo "" > "$inventory_file"

while IFS= read -r line; do
    name=$(echo $line | awk '{print $1}')
    ip=$(echo $line | awk '{print $2}')
    group_name=$(echo $name | cut -d'-' -f1)
    if ! grep -q "^\[$group_name\]" "$inventory_file"; then
        echo "[$group_name]" >> "$inventory_file"
    fi
    echo "$name ansible_host=$ip" >> "$inventory_file"
done < "$temp_file"

rm "$temp_file"
cat "$inventory_file"
