# PROMPTS.md — introduction-to-builds

## Context

This file documents the AI-assisted work and thinking process I used while completing the `introduction-to-builds` iximiuz challenge. The main goal was to understand how to build, inspect, and run Go binaries across different operating systems and architectures, and to prepare the required reflection and debug write-up.

## Prompts and assistance used

### 1. Understanding the submission requirements

**Prompt:**  
“Briefly explain what do I have to do here.”

**Summary of help received:**  
I asked for a short explanation of the challenge requirements. The response clarified that I needed to complete the iximiuz challenge, push the required files to the `main` branch of my GitHub repository, and submit the iximiuz URL, GitHub repo URL, and `PROMPTS.md` in Google Classroom.

### 2. Planning next steps after creating the GitHub repo

**Prompt:**  
“The last step I did was to create the GitHub repo, what are the next steps I have to do, explain them shortly and very clear/concise.”

**Summary of help received:**  
The answer gave me a practical sequence: clone the repo into the playground, create or copy `main.go`, build the binary with `go build -o main main.go`, run and test it with `curl`, create at least one stretch artifact, write `REFLECTION.md` and `DEBUG.md`, commit everything, and push to `main`.

### 3. Understanding executable formats

**Prompt:**  
“From there, what does Mach-O mean?”

**Summary of help received:**  
I learned that Mach-O means Mach Object and is the executable format used by macOS. This helped me understand why a file reported as `Mach-O 64-bit executable x86_64` was built for macOS Intel, not Linux.

### 4. Understanding cross-compilation output

**Prompt:**  
“For what OS is this: `main-arm64: ELF 64-bit LSB executable, ARM aarch64...`”

**Summary of help received:**  
The response explained that this binary was built for Linux on ARM64. I learned that `ELF` indicates a Linux/Unix-style executable and `ARM aarch64` means ARM64 architecture.

### 5. Comparing `file` command outputs

**Prompt:**  
“Why the second one has more details than the second? Is the first one stripped?”

**Summary of help received:**  
The explanation clarified that the `file` command often shows more metadata for ELF binaries than for Mach-O binaries. I also learned that a shorter `file` output does not necessarily mean the binary is stripped, and that `go tool nm main` can help check for symbols.

### 6. Debugging the GLIBC error

**Prompt:**  
“What can this be: `./main: /lib/x86_64-linux-gnu/libc.so.6: version GLIBC_2.34 not found`”

**Summary of help received:**  
I learned that this usually means the binary was built on a newer Linux system with a newer glibc version and then copied to an older system that does not have the required glibc version.

### 7. Finding another possible cause

**Prompt:**  
“What can be another cause?”

**Summary of help received:**  
The answer explained that CGO could have been enabled during the Go build, causing the binary to dynamically link against glibc. This gave me a second hypothesis for `DEBUG.md`.

### 8. Writing ranked hypotheses

**Prompt:**  
“I need to write two ranked hypotheses for the root cause. Higher likelihood first, with a one-sentence reason why each is plausible.”

**Summary of help received:**  
I received a clearer way to phrase the two hypotheses: first, the binary was built on a newer Linux system than the customer VM; second, the binary was built with CGO enabled, creating a dynamic glibc dependency.

### 9. Understanding the difference between the two hypotheses

**Prompt:**  
“I don't get the difference between these two.”

**Summary of help received:**  
The answer explained that the first hypothesis describes where the `GLIBC_2.34` requirement came from, while the second explains why the Go binary depended on glibc at all.

### 10. Understanding static linking

**Prompt:**  
“What happen if I statically link but build it in a newer OS?”

**Summary of help received:**  
I learned that a statically linked Go binary built with `CGO_ENABLED=0` usually avoids the target machine’s glibc dependency, although the OS and architecture still need to match.

### 11. Verification commands

**Prompt:**  
“One verification step per hypothesis — a concrete command you'd run on the customer's VM (or yours) that distinguishes them.”

**Summary of help received:**  
The suggested verification commands were `ldd --version` to check the glibc version on the target VM and `ldd ./main` to check whether the binary dynamically links against glibc.

### 12. Building a dynamically linked Go binary

**Prompt:**  
“How to build a dynamically linked Go binary?”

**Summary of help received:**  
I learned that `CGO_ENABLED=1 go build -ldflags='-linkmode=external' -o main main.go` can produce a dynamically linked Go binary, and that `ldd ./main` can confirm the dynamic dependencies.

### 13. Reading `ldd` output

**Prompt:**  
“What does this shows? `linux-vdso.so.1`, `libc.so.6`, `/lib64/ld-linux-x86-64.so.2`”

**Summary of help received:**  
The response explained that this output proves the binary is dynamically linked and depends on glibc. In particular, `libc.so.6` is the important evidence for the GLIBC dependency.

### 14. Understanding CGO

**Prompt:**  
“What does CGO mean?”

**Summary of help received:**  
I learned that CGO means C Go and is the Go feature that lets Go code call C code and use C libraries. I also learned the practical difference between `CGO_ENABLED=1` and `CGO_ENABLED=0`.

## How I used the assistance

I used the AI responses to understand the concepts behind the commands instead of only copying commands. The most useful ideas were the difference between Mach-O and ELF, the meaning of architecture labels like `x86_64` and `aarch64`, the role of dynamic linking, and why CGO can make a Go binary depend on glibc. I used that understanding to prepare the challenge artifacts, especially the `DEBUG.md` explanation.

## Commands I planned to use or verify

```bash
go build -o main main.go
file ./main
ldd ./main
ldd --version
CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -o main main.go
CGO_ENABLED=1 go build -ldflags='-linkmode=external' -o main main.go
go build -ldflags='-s -w' -o main-stripped main.go
du -b ./main ./main-stripped
```

## Remaining unclear points

I still need more practice with the exact details of static versus dynamic linking in Go, especially how CGO changes the final binary depending on the operating system, architecture, and installed C libraries. I understand the high-level idea, but I would like to become more confident predicting the result before running `file` or `ldd`.

# From a different LLM session:

## Prompt 1

Explain what these Go build flags do:

```bash
go build -ldflags='-s -w' -o main-stripped main.go
```

## Prompt 2

What is DWARF debug information, and why does the Go linker flag `-w` remove it?

## Prompt 3

Given this Go HTTP server, write a Ruby/Sinatra version that returns the same JSON shape on port 4444:

```go
package main

import (
    "encoding/json"
    "fmt"
    "log"
    "net/http"
)

type Simple struct {
    Name        string
    Description string
    Url         string
}

func handler(w http.ResponseWriter, r *http.Request) {
    simple := Simple{"Hello", "World", r.Host}

    jsonOutput, _ := json.Marshal(simple)

    w.Header().Set("Content-Type", "application/json")

    fmt.Fprintln(w, string(jsonOutput))
}

func main() {
    fmt.Println("Server started on port 4444")
    http.HandleFunc("/", handler)
    log.Fatal(http.ListenAndServe(":4444", nil))
}
```

## Prompt 4

I am getting this Sinatra error:

```text
attack prevented by Rack::Protection::HostAuthorization
403 Host not permitted
```

How do I fix it for a small lab app running on port 4444?

## Prompt 5

Is this reflection answer correct?

```text
For the Go binary to run, I need only the binary statically linked or dynamically linked with the correct library versions installed, but for Ruby I need the interpreter and the required gems.
```

## Prompt 6

Help me write a clear `REFLECTION.md` explaining the difference between what is needed to run a Go binary and what is needed to run a Ruby/Sinatra script.
