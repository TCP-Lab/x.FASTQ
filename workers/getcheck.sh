set -e

eval_str=${1}
check=${2}
target=${3}
depth=0

while true; do
    echo "Spawning download worker for ${target} @ depth ${depth} with check ${check}"
    eval $1
    local_hash=$(cat $target | md5sum | cut -d' ' -f1)
    echo -n "Computed hash: ${local_hash} - "

    if [ "$check" = "$local_hash" ]; then
        echo "Success!"
        exit 0
    else
        echo "FAILURE! Deleting corrupt file..."
        rm $target
    fi

    if [ $depth -lt 3 ]; then
        echo "File was corrupted in transit. Trying again."
        depth=$((depth+1))
    else
        echo "Unable to download file ${target} - corrupted checksum"
        exit 1
    fi
done

