#!/usr/bin/bash
set -e

if [ $# -ne 1 ]; then
    cat README
    exit 1
fi

root=$1
wd=/tmp

list_suffixes() {
    gh repo list \
        -L 100 --json name \
        --jq ".[] | .name | select(startswith(\"$root\")) | ltrimstr(\"$root\") | select(length>0)"
}

init_local() {
    rm -rf $wd/$root
    mkdir $wd/$root && cd $_
    git init
    git commit --allow-empty -m "Add empty root commit."
}

merge2local() {
    suffix=$1
    leaf=$root$suffix
    echo -n "Merging $leaf to $wd/$root/$suffix... "

    cd $wd
    rm -rf $wd/$leaf
    gh repo clone $leaf -- --single-branch --quiet

    cd $wd/$leaf
    git filter-repo --to-subdirectory-filter $suffix --quiet > /dev/null

    cd $wd/$root
    git remote add $suffix ../$leaf
    git fetch $suffix --tags --quiet
    git merge --allow-unrelated-histories --no-ff --no-edit --quiet $suffix/master

    diff -r $wd/$leaf/$suffix $wd/$root/$suffix
    if [ $? -ne 0 ]; then
        echo "Bad merge."
        exit 1
    fi
    echo "Done."
}

push_local() {
    gh repo create --source $wd/$root --push --private
}

delete_remote() {
    gh repo delete $root$1 --confirm
}

init_local

suffixes=$(list_suffixes)
for suffix in $suffixes; do
    merge2local $suffix
done

push_local

echo "The following repos are merged to $root as subdirectories:"
for suffix in $suffixes; do
    echo -n "$root$suffix "
done
echo

read -p "Do you want to delete them? "
case $REPLY in
    Y|y|Yes|yes)
        for suffix in $suffixes; do
            delete_remote $suffix
        done
        ;;
    *)
        echo "Canceled."
        ;;
esac
