#!/usr/bin/zsh
#
# This script downloads yq 2.4.1 if it does not exist, and unpackages archives, applies changes, and repackages them.
#
# The first parameter is the key, the second is the value, and the third must be the full path to a Chart.yaml file within the rancher/charts repo.
# This script expects to be run inside the charts repo, and will not work if not at the root of that repo.
# Additionally, an older version of yq was explicitly selected due to newer version of yq forcing an indentation level that would produce a large unwanted commit with unidentifiable changes.
# Lastly, this design was influenced by the fact that at the root of the charts repo, it is fairly easy to query a specific range via git diff and pipe it, such as the following:
#
# git diff --name-only HEAD | grep charts | sed 's/\/Chart\.yaml//' | sort -u | xargs -I{} ./modify-and-repackage.sh 'annotations.[catalog.cattle.io/rancher-version]' '"< 2.6.1-0"' {}
#
# Usage: path/to/modify-and-repackage.sh 'annotations.[catalog.cattle.io/rancher-version]' '"< 2.6.1-0"' ./.../Chart.yaml
#

rm -rf /tmp/tar

CWD=$(pwd)

KEY=$1
VALUE=$2
f=$3

while true; do
    cd $CWD

    if [ ! -f ./yq_linux_amd64 ]; then
        echo "Downloading yq:v2.4.1"
        curl -sLO https://github.com/mikefarah/yq/releases/download/2.4.1/yq_linux_amd64
        chmod +x ./yq_linux_amd64
    fi

    echo "Processing $f"

    echo "Extracing paths from $f"

    FOLDER=$(echo "$f" | cut -d '/' -f 2)
    NAME=$(echo "$f" | cut -d '/' -f 3)
    VERSION=$(echo "$f" | cut -d '/' -f 4)

    f="assets/$FOLDER/$NAME-$VERSION.tgz"

    echo "Folder: $FOLDER"
    echo "Name: $NAME"
    echo "Version: $VERSION"

    echo "Extracting $f"
    
    mkdir -p /tmp/tar/assets
    rm -rf /tmp/tar/assets/$NAME
    tar -zxvf $f -C /tmp/tar/assets

    echo "Entering /tmp/tar/assets/$NAME"

    cd /tmp/tar/assets/$NAME

    $CWD/./yq_linux_amd64 write -i ./Chart.yaml $KEY $VALUE
    
    echo "Editing $CWD/charts/$FOLDER/$NAME/$VERSION/Chart.yaml"
    cp ./Chart.yaml $CWD/charts/$FOLDER/$NAME/$VERSION/Chart.yaml

    cd /tmp/tar/assets

    OUT=$(echo "$f" | cut -d '/' -f 3)

    echo "Repackaging archive: $OUT"

    tar -zcvf $OUT $NAME
    echo "cp $OUT $CWD/$f"
    cp $OUT $CWD/$f
    exit
done
