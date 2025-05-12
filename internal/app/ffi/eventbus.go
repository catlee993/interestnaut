package ffi

import (
	"C"
	"interestnaut/internal/app/eventbus"
	"log"
)

//export EventBus_Init
func EventBus_Init() C.int {
	log.Println("Initializing event bus from FFI")
	// Convert int32 to C.int to avoid type mismatch
	return C.int(int32(eventbus.InitEventBus()))
}

//export EventBus_Shutdown
func EventBus_Shutdown() {
	log.Println("Shutting down event bus from FFI")
	eventbus.ShutdownEventBus()
}
