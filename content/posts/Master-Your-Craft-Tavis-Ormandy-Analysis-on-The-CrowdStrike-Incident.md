---
title: "Master Your Craft - Tavis Ormandy Analysis on The CrowdStrike Incident"
categories: Security
tags: ["CrowdStrike", "Assembly", "Low Level", "Reverse Engineer", "Debugger", "Vulnerability", "Exploit", "C", "C++", "CPP"]
date: 2024-07-28
---

#### Disclaimer
This post isn't about accusing anyone or causing drama. It’s meant to show how common misinformation is on social media and to stress the importance of paying close attention in cybersecurity, especially with low-level topics like assembly.

With that in mind, this post will discuss Tavis Ormandy's thread on X about the CS incident, which you can find below.

{{< tweet user=taviso id=1814762302337654829 >}}


#### Origin - The tweet
In my humble opinion, I found this tweet somewhat off-putting. It seemed to imply that the author had a comprehensive understanding of every aspect of the C++ language. Let's be honest, even Bjarne Stroustrup himself has admitted that it's impossible to keep up with all the details of the language. C++ is vast and complex, and no one can master it entirely.

Another point worth noting is the apparent confusion between technical jargon and tool terminology. For instance, `analyze` is a built-in extension or command in WinDBG that helps in debugging when an exception occurs. The use of the `!` symbol indicates that it is an extension.

![analyze-cmd](/images/cs_incident/cdb_analyze.png)

The theory of a NULL dereference is plausible if we rely solely on [analyze's output](https://pbs.twimg.com/media/GS9HY7wbYAAsVS0?format=png&name=900x900) and ignore the assembly instruction that caused the crash. While the report indicates a 'READ OPERATION ON INVALID ADDRESS,' should we blindly trust the tool's results?

#### Memory Alignment 
The second evidence used but the author, was a pseudo C code showcasing how memory aligmanebt works, backing up the idea of NULL pointer dereferencing. Someone who does not deal with low level aspect so often can make the same silly mistake and find what illustrated in that picture correct, unfortunitly that's not the case.

The second piece of evidence presented by the author was a pseudo C code example illustrating memory alignment, intended to support the theory of a NULL pointer dereference. However, someone not familiar with low-level aspects might mistakenly accept the illustration as accurate, when in fact, it is not.

{{< tweet user=taviso id=1814762306041225589 >}}

The error lies in the representation of memory alignment and offset of different types, for the sake of simplicity I made this c++ program that illustrates the idea of memory alignments of an object, this example uses `__breakpoint()` macro to fire up your debugger, you might need to set your debugger to postmortum first. 

```CPP
#include <cstdint>
#include <iostream>
#include <sstream>

#include <Windows.h>

struct Obj {
    int a;
    int b;
    char c[2];
    int d;
};

const std::string DEBUG_TAG = "taha_dbg ";

void print_address(uintptr_t ptr) {
    std::stringstream ss;
    std::string message = "Obj address: ";

    ss << DEBUG_TAG << message << "0x" << std::hex << ptr;

    OutputDebugStringA(ss.str().c_str());

    std::cout << ss.str().c_str() << "\n";
}

int main() {

    Obj * obj = new Obj{13, 25, {0x41, 0x42}, 9};

    print_address(reinterpret_cast<uintptr_t>(obj));

    __debugbreak();

}
```

Make sure to compile with debug symbols for better experience.

```POWERSHELL
PS C:\Users\tahai\code\cpping> cl .\struct_mem_align_example.cpp  /EHsc /Zi /DEBUG
Microsoft (R) C/C++ Optimizing Compiler Version 19.37.32825 for x64
Copyright (C) Microsoft Corporation.  All rights reserved.

struct_mem_align_example.cpp
Microsoft (R) Incremental Linker Version 14.37.32825.0
Copyright (C) Microsoft Corporation.  All rights reserved.

/out:struct_mem_align_example.exe
/debug
struct_mem_align_example.obj
PS C:\Users\tahai\code\cpping>
```

Now, simply run the program. and WinDBG will pop up. Inspect the object address and content, and you will notice that if you need to fetch the value of `a`, the firt field in the struct, you can use the address of the object itself (since the first field resides at the same address as the object, i.e.,offset 0).

![mem-windbg](/images/cs_incident/windbg.png)

This demonstrates that the example provided by the author is inaccurate in a real-world scenario

#### The devil is in The Details 

{{< tweet user=taviso id=1814762308050301010 >}}

This section is the crux of the matter, highlighting the importance of attention to detail, especially when performing lower-level analysis such as with assembly language.

Assuming you're familiar with assembly, I'll briefly explain the use of [] in the instruction shown in the screenshot. In short, [] typically means accessing the value from the specified address or object, which is known as dereferencing. For example:

```asm
mv r9d, dword ptr [r8]
```

This instruction copies the value stored at the address in r8 into r9d. If r8 contains 0x9c, which is an invalid address, this will crash the program.

Now, let’s imagine r8 holds 0xdeadbeef, a valid memory address. The instruction would then grab a dword from the memory location pointed to by r8. If 0xdeadbeef contains the bytes 0x41 0x42 0x43 0x44 0x45 0x46 0x47 0x48 ..., only the first 4 bytes, 0x41 0x42 0x43 0x44, would be returned.

With this understanding of dereferencing, Tavis's tweet suggests that if r0 holds NULL (0x0) and 0x9c is the offset of the field, we should expect an instruction like [r8+0x9c]. This makes sense, and Tavis demonstrates this with an example on Godbolt.

[Example created by Tavis](https://godbolt.org/z/sdz4PGxxo)

The example is accurate, replicating the situation with the offset correctly:

```ASM
 mov     ecx, DWORD PTR [rax+156]
```

Here, 156 is the decimal equivalent of 0x9c. I used a different approach to illustrate the same concept and disprove the author's theory by modifying the earlier example for memory alignment. By setting obj* to 0x9c, which mimics the analyze output, triggering a read operation will crash the program. The generated instruction will follow the format [reg+offset], not [reg] as the author suggested. Don’t just take my word for it - try it yourself!


```CPP
...
int main() {
  // Mimic analyze -v output and showcase (index/offset) case.
    Obj * obj1 = (Obj*)0x9c;

    __debugbreak();

    if(!obj1) goto exit;

    std::cout << obj1->d;
}
```

#### Fatality
It turns out that a NULL check was in place, so the theory about NULL pointer dereferencing is incorrect.

{{< tweet user=taviso id=1814762312211046703 >}}

#### Takeaways
- Attention to detail is crucial. 
- Assumptions have no place in binary analysis. 
- Social media often contains misinformation. 

{{< youtube j0Cl0KqTeyk >}}