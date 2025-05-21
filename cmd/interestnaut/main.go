package main

/*
#cgo CFLAGS: -I${SRCDIR}/../../internal/app/ffi
#include <stdlib.h>
*/
import "C"
import (
	_ "interestnaut/internal/app/ffi" // Import for FFI exports
)

func main() {
	// This function is required but does nothing when built as a shared library
}
