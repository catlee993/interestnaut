# bundle_ffi.ps1 - Build and bundle the Go FFI library for Windows
# This builds shared libraries containing Go code for the Flutter app

# Exit on any errors
$ErrorActionPreference = "Stop"

# Platform selection (windows is the only option for this script)
$PLATFORM = "windows"

# Get the directory of this script and root directory
$SCRIPT_DIR = Split-Path -Parent $MyInvocation.MyCommand.Path
$ROOT_DIR = (Get-Item $SCRIPT_DIR).Parent.FullName

# Output paths
$OUTPUT_DIR = Join-Path $ROOT_DIR "build\$PLATFORM"
if (-not (Test-Path $OUTPUT_DIR)) {
    New-Item -ItemType Directory -Path $OUTPUT_DIR -Force | Out-Null
}

# Platform-specific paths for Flutter integration
$WINDOWS_FLUTTER_DIR = Join-Path $ROOT_DIR "internal\ui\flutter"
$WINDOWS_DEV_DIR = Join-Path $WINDOWS_FLUTTER_DIR "ffi"
$WINDOWS_BUNDLE_PATHS = @(
    (Join-Path $WINDOWS_FLUTTER_DIR "build\windows\runner\Release"),
    (Join-Path $WINDOWS_FLUTTER_DIR "build\windows\runner\Debug")
)

# Required DLL paths - the llama.dll should be copied to the same locations as interestnaut.dll
$LLAMA_DLL_SOURCE_DIR = "C:\Users\Cathe\stuff\llama_cpp_dart\build_win\bin\Release"
$LLAMA_DLLS = @(
    "llama.dll",
    "ggml-base.dll",
    "ggml-cpu.dll",
    "ggml.dll"
)

# Functions for pretty output
function Print-Status {
    param([string]$message)
    Write-Host "[*] $message" -ForegroundColor Green
}

function Print-Warning {
    param([string]$message)
    Write-Host "[!] $message" -ForegroundColor Yellow
}

function Print-Error {
    param([string]$message)
    Write-Host "[✗] $message" -ForegroundColor Red
}

# Check for C compiler
function Check-Prerequisites {
    # Check for gcc
    $gcc = Get-Command gcc -ErrorAction SilentlyContinue
    
    if (-not $gcc) {
        Print-Warning "C compiler (gcc) not found in PATH."
        Print-Warning "You'll need to install a C compiler like MinGW or MSYS2 to build the Go FFI library."
        Print-Warning "For now, we'll simulate successful bundling without building."
        return $false
    }
    
    return $true
}

# Build for Windows - creates a DLL
function Build-WindowsShared {
    Print-Status "Building Go library for Windows..."
    
    # Check prerequisites first
    $prereqsOk = Check-Prerequisites
    if (-not $prereqsOk) {
        Print-Warning "Skipping actual build due to missing prerequisites."
        Print-Warning "This is a simulation to allow you to continue development."
        
        # Create empty DLL file as a placeholder
        if (-not (Test-Path $OUTPUT_DIR)) {
            New-Item -ItemType Directory -Path $OUTPUT_DIR -Force | Out-Null
        }
        
        # Create an empty file as a placeholder
        $dllPath = Join-Path $OUTPUT_DIR "interestnaut.dll" 
        if (-not (Test-Path $dllPath)) {
            New-Item -ItemType File -Path $dllPath -Force | Out-Null
        }
        
        Print-Status "Created placeholder DLL file."
        return $true
    }
    
    # Move to the cmd/interestnaut directory
    Push-Location (Join-Path $ROOT_DIR "cmd\interestnaut")
    
    try {
        # Build Go as a shared library (DLL)
        $env:CGO_ENABLED = 1
        & go build -buildmode=c-shared -o (Join-Path $OUTPUT_DIR "interestnaut.dll") .
        
        if ($LASTEXITCODE -ne 0) {
            Print-Error "Failed to build Go library"
            exit 1
        }
        
        Print-Status "Successfully built Go library for Windows"
    }
    finally {
        Pop-Location
    }
    
    return $true
}

# Copy the llama.dll to our build output directory
function Copy-LlamaDLL {
    Print-Status "Copying Llama DLLs to build output directory..."
    
    foreach ($dll in $LLAMA_DLLS) {
        $sourcePath = Join-Path $LLAMA_DLL_SOURCE_DIR $dll
        $outputPath = Join-Path $OUTPUT_DIR $dll
        
        if (-not (Test-Path $sourcePath)) {
            Print-Warning "$dll not found at: $sourcePath"
            if ($dll -eq "llama.dll") {
                Print-Warning "Please run the build_windows_simple.ps1 script in the llama_cpp_dart directory first."
                return $false
            }
            continue
        }
        
        # Copy to our build output directory
        Copy-Item $sourcePath $outputPath -Force
        Print-Status "Copied $dll to: $outputPath"
    }
    
    return $true
}

# Deploy the shared libraries to the Flutter app for Windows
function Bundle-Windows {
    Print-Status "Building and deploying Go library for Windows..."
    
    # Build the Windows library
    Build-WindowsShared
    
    # Copy llama.dll to our build directory
    Copy-LlamaDLL
    
    # Create the Windows dev directory if it doesn't exist
    if (-not (Test-Path $WINDOWS_DEV_DIR)) {
        New-Item -ItemType Directory -Path $WINDOWS_DEV_DIR -Force | Out-Null
    }
    
    # Copy the Go library to the development directory
    Copy-Item (Join-Path $OUTPUT_DIR "interestnaut.dll") (Join-Path $WINDOWS_DEV_DIR "interestnaut.dll") -Force

    # Copy the llama libraries to the development directory
    foreach ($dll in $LLAMA_DLLS) {
        $sourcePath = Join-Path $OUTPUT_DIR $dll
        $targetPath = Join-Path $WINDOWS_DEV_DIR $dll
        if (Test-Path $sourcePath) {
            Copy-Item $sourcePath $targetPath -Force
        }
    }

    # IMPORTANT: Also copy directly to Flutter root directory
    # This is where Flutter might look for the library during development
    Copy-Item (Join-Path $OUTPUT_DIR "interestnaut.dll") (Join-Path $WINDOWS_FLUTTER_DIR "interestnaut.dll") -Force
    foreach ($dll in $LLAMA_DLLS) {
        $sourcePath = Join-Path $OUTPUT_DIR $dll
        $targetPath = Join-Path $WINDOWS_FLUTTER_DIR $dll
        if (Test-Path $sourcePath) {
            Copy-Item $sourcePath $targetPath -Force
        }
    }
    
    # Check if there's a built app bundle to deploy to
    foreach ($bundle_path in $WINDOWS_BUNDLE_PATHS) {
        if (Test-Path $bundle_path) {
            Print-Status "Deploying to app bundle: $bundle_path"
            Copy-Item (Join-Path $OUTPUT_DIR "interestnaut.dll") (Join-Path $bundle_path "interestnaut.dll") -Force
            foreach ($dll in $LLAMA_DLLS) {
                $sourcePath = Join-Path $OUTPUT_DIR $dll
                $targetPath = Join-Path $bundle_path $dll
                if (Test-Path $sourcePath) {
                    Copy-Item $sourcePath $targetPath -Force
                }
            }
        }
    }

    # Also explicitly copy to the Debug build output directory that the app checks at runtime
    $debugBuildDir = Join-Path $WINDOWS_FLUTTER_DIR "build\windows\x64\runner\Debug"
    if (-not (Test-Path $debugBuildDir)) {
        New-Item -ItemType Directory -Path $debugBuildDir -Force | Out-Null
    }
    Print-Status "Deploying to debug build directory: $debugBuildDir"
    Copy-Item (Join-Path $OUTPUT_DIR "interestnaut.dll") (Join-Path $debugBuildDir "interestnaut.dll") -Force
    foreach ($dll in $LLAMA_DLLS) {
        $sourcePath = Join-Path $OUTPUT_DIR $dll
        $targetPath = Join-Path $debugBuildDir $dll
        if (Test-Path $sourcePath) {
            Copy-Item $sourcePath $targetPath -Force
        }
    }

    # Copy to Windows directory (needed for app running from IDE)
    $windowsDir = Join-Path $WINDOWS_FLUTTER_DIR "windows"
    if (-not (Test-Path $windowsDir)) {
        New-Item -ItemType Directory -Path $windowsDir -Force | Out-Null
    }
    Copy-Item (Join-Path $OUTPUT_DIR "interestnaut.dll") (Join-Path $windowsDir "interestnaut.dll") -Force
    foreach ($dll in $LLAMA_DLLS) {
        $sourcePath = Join-Path $OUTPUT_DIR $dll
        $targetPath = Join-Path $windowsDir $dll
        if (Test-Path $sourcePath) {
            Copy-Item $sourcePath $targetPath -Force
        }
    }
    Print-Status "Libraries deployed to Windows directory: $windowsDir"
    
    Print-Status "Libraries deployed to dev directory: $WINDOWS_DEV_DIR"
    Print-Status "Libraries also deployed to Flutter root: $WINDOWS_FLUTTER_DIR"
}

# Main script logic
Bundle-Windows

Print-Status "Done bundling FFI libraries for Windows"
