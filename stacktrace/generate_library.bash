#!/bin/bash

set -e

_PKGS=$(go list -f '{{printf "\t%q,\n" .ImportPath}}' "$@" | grep -v vendor/golang_org)

cat > library.go <<EOF
// Code generated by "go generate". DO NOT EDIT.

package stacktrace

import (
	"strings"

	"github.com/armon/go-radix"
)

var libraryPackages = newLibraryPackagesRadixTree(
	"vendor/golang_org",
$_PKGS
)

func newLibraryPackagesRadixTree(k ...string) *radix.Tree {
	tree := radix.New()
	for _, k := range k {
		tree.Insert(k, true)
	}
	return tree
}

// RegisterLibraryPackage registers the given packages as being
// well-known library path prefixes. This must not be called
// concurrently with any other functions or methods in this
// package; it is expected to be used by init functions.
func RegisterLibraryPackage(pkg ...string) {
	for _, pkg := range pkg {
		libraryPackages.Insert(pkg, true)
	}
}

// RegisterApplicationPackage registers the given packages as being
// an application path. This must not be called concurrently with
// any other functions or methods in this package; it is expected
// to be used by init functions.
//
// It is not typically necessary to register application paths. If
// a package does not match a registered *library* package path
// prefix, then the path is considered an application path. This
// function exists for the unusual case that an application exists
// within a library (e.g. an example program).
func RegisterApplicationPackage(pkg ...string) {
	for _, pkg := range pkg {
		libraryPackages.Insert(pkg, false)
	}
}

// IsLibraryPackage reports whether or not the given package path is
// a library package. This includes known library packages
// (e.g. stdlib or apm-agent-go), vendored packages, and any packages
// with a prefix registered with RegisterLibraryPackage but not
// RegisterApplicationPackage.
func IsLibraryPackage(pkg string) bool {
	if strings.HasSuffix(pkg, "_test") {
		return false
	}
	if strings.Contains(pkg, "/vendor/") {
		return true
	}
	prefix, v, ok := libraryPackages.LongestPrefix(pkg)
	if !ok || v == false {
		return false
	}
	return prefix == pkg || pkg[len(prefix)] == '/'
}
EOF

gofmt -w library.go
