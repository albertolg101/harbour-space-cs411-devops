## Debug task

1. Root cause of the problem:
    - main was built using dynamic linking. This is plausible because
    if glibc is statically linked to our binary then it doesn't matter what
    version of glibc the target system has.
    - main was built on a different glibc version. This is plausible because
    if we decide to dinamically link the binary then we need compatible 
    glibc versions to be prensent on both, the builder machine and 
    the target machine
2. One verification step per hypothesis:
    - to know if the file is dynamically linked we can run `ldd ./main`
    - to know what glibc version the current machine is running we run `ldd --version`

3. Your fix.
    - I would prefix the build command with `CGO_ENABLED=0`, it will work because
    it doesn't allow Go to use C libraries (so not dynamic linking to glibc will happen)

4. One sentence explaining what the underlying lesson is for "deploy a Go binary to a different machine."
    - The lesson from here is to not dynamically link my 
    binaries (if I'm deployoing it to a different machine).
    Specifically for Go is to use `CGO_ENABLED=0` to avoid 
    dynamically linking to glibc

