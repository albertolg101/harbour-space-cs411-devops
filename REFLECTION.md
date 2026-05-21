# Reflection — introduction-to-builds

## What did I do?

- Created github empty repo and cloned it
- Created main.go
- Installed golang using homebrew
- built the binary using `go build main.go` 
- used curl to check everything was working as expected
- For the cross-compile task I ran `GOOS=linux GOARCH=arm64 go build -o main-arm64 main.go`
- compared both binaries using `file`
- for the strip the binary file I built the new binary using `go build -ldflags='-s -w' -o main-stripped main.go`
I asked LLM what does flags do and compared both file sizes using du.
- for the ruby version I used LLM to build the ruby script and to understand how
to run it
- for the debug task I undertood for my self that the problem was because of the dynamic linking
but didn't know how to debug it (how to exactly know what verions of glibc 
the os was using if the binary was actually using dynamic linking) so I asked
LLM and proposed to use lld so
- I installed ldd to learn how to use it (to understand how 
to solve the debuging task).

## What was most surprising?

how to use ldd, I was not unexpected that were a tool for it but it was for sure
a good lesson

## What's still unclear?

nothing really 

## Stretch tasks:

The differences I find between main and main-arm64 are:
- main is built for x86-64 architechture and main-arm64 is built for ARM arrch64
- main is dynamically linked and main-arm64 is statically linked

The difference between main and main-stripped is that main-stripped is smaller
because it removes debug information, the symbol table and DWARF. The tradeoff
is smaller binary vs debug capabilities, so if something goes wrong with the 
bigger binary we can know the traceback of the error but if something goes with
the smaller binary we can't not know what went wrong

For the go binary to run I need a compiled binary built for the machine OS and 
CPU architechture. If that binary is dynamically linked I would also need
the required shared library to be installed. For the ruby script instead I would
need the ruby interpreter plus the requried gems (e.g. sinatra).
