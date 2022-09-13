#!/usr/bin/bash
set -e

if [ $# -ne 1 ]
then
    cat README
    exit 1
fi

root=$1
wd=/tmp

list_suffixes() {
    gh repo list -L 100 --json name --jq ".[] | .name | select(startswith(\"$root\")) | ltrimstr(\"$root\") | select(length>0)"
}

init_local() {
    rm -rf $wd/$root
    mkdir $wd/$root && cd $_
    git init
    git commit --allow-empty -m "Initialize $root"
}

merge2local() {
    suffix=$1
    leaf=$root$suffix

    cd $wd
    rm -rf $wd/$leaf
    gh repo clone $leaf -- --single-branch --quiet

    cd $wd/$leaf
    git filter-repo --to-subdirectory-filter $suffix --quiet > /dev/null

    cd $wd/$root
    git remote add $suffix ../$leaf
    git fetch $suffix --tags --quiet
    git merge --allow-unrelated-histories --no-ff --no-edit --quiet $suffix/master
}

push_local() {
    gh repo create --source $wd/$root --push --private
}

init_local
for suffix in $(list_suffixes)
do
    echo -n "Merging $root$suffix to $wd/$root... "
    merge2local $suffix
    echo "Done."
done
echo "Pushing $wd/$root to remote... "
push_local
