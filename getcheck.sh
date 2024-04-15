set -e

_finished=false

eval_str=${1}
check=${2}
target=${3}
depth=0

while ! $_finished; do
    echo "Spawning download worker for ${target} @ depth ${depth}"
    exec $1
    local_hash=$(cat $target | md5)
    echo -n "Computed hash: ${local_hash}"
    if [ $check -eq $local_hash ]; then
        echo "Success!"
        _finished=true
    else
        echo "FAILURE! Deleting corrupt file..."
        rm $target
    fi

    if ! $_finished && [ $depth -lt 3 ]; then
        echo "File was corrupted in transit. Trying again."
        ((depth++))
    else
        echo "Unable to download file ${target} - corrupted checksum"
        exit 1
    fi
done

