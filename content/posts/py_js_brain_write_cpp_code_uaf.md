---
title: "When a Py/JS Brain Writes C++: A Bug Story"
date: 2025-06-17T19:59:37+01:00
---

### TL&DR

After two weeks or so of writing in high-level programming langauges such as JS and Python, my brain adapated to a similar coding style when switching back to C++, which eventually led me to write buggy (UAF-prone) code due to the nature of language. If you're interested into the technical details, stick around!

### The Bug Dicovery

While inspecting DBGView logs I noticed an empty string [2]. If you pay attention to the check before printing that value, it seems impossible that the program would behave like that; but here we go! 

```C++
...

  std::wstring module_name = [](const PUNICODE_STRING& u) -> std::wstring {
        std::wstring wstr(u->Buffer, u->Length / sizeof(wchar_t));
        const std::wstring prefix = L"\\??\\";
        if (wstr.compare(0, prefix.length(), prefix) == 0)
        {
            wstr.erase(0, prefix.length());
        }
        return wstr;
    }(ObjectAttributes->ObjectName);

    if (!module_name.empty())
    {
        DBGINFO("File %ws %s",
            module_name.c_str(),
            (exists ? "exists" : "DOES NOT exist")
            );
        auto parent = std::filesystem::path(module_name).remove_filename().c_str();  // [1]
        if (parent && *parent && wcslen(parent) > 0) DBGINFO("Parent directory %ws", parent); // [2]
    }
...

```

Yes, you're correct. That's a typical Undefined Behaviour (UB), and we will dissect the root cause of it in the next section.

### The Bug Breakdown

As you might have figured it out already, the bug resides at [1], during the two past weeks, I got used to the builder, factory sort of statement style in  high-level programming languages, but hey! we are dealing with C++ ;)

```C++
auto parent = std::filesystem::path(module_name).remove_filename().c_str();
```

I mean, let's face it; The statement looks benign and safe at first sight, right? Unfortunately, I made a rookie mistake. `c_str()` returns a pointer to a C-style buffer. Hence, the `parent` type will be `const wchar*`. So far, so good - but the returned pointer comes from an `rvalue` (temporary object), `std::filesystem::path`, which gets destroyed at the end of the statement. That makes the `parent` variable a dangling pointer.

The fix is straightforward, store the returned `std::filesystem::path` value in a variable, so it survives longer and voila!

PS: this can be caught easily if the program was compiled with `-fsanitize=address`. Make sure to incorporate this during your testing and development cycles.

Thanks for reading!
