#!/bin/bash
set -e

versions=( "$@" )
if [ ${#versions[@]} -eq 0 ]; then
	versions=( */ )
fi
versions=( "${versions[@]%/}" )

packagesUrl='http://apt.postgresql.org/pub/repos/apt/dists/wheezy-pgdg/main/binary-amd64/Packages'
packages='postgres-packages.tmp'
curl -sSL "${packagesUrl}.bz2" | bunzip2 > "$packages"

for version in "${versions[@]}"; do
	fullVersion="$(grep -A10 "^Package: postgresql-$version\$" "$packages" | grep -m1 '^Version: ' | cut -d' ' -f2)"
	(
		set -x
		cp docker-entrypoint.sh Dockerfile.template "$version/"
		mv "$version/Dockerfile.template" "$version/Dockerfile"
		sed -i '' 's/%%PG_MAJOR%%/'$version'/g; s/%%PG_VERSION%%/'$fullVersion'/g' "$version/Dockerfile"
	)
done

rm "$packages"
