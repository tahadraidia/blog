---
title: "Alternative to JMP ESP Instruction"
date: 2021-12-12T13:34:28Z
categories: ["Security", "Exploit Development"]
tags: ["Assembly x86", "Assembly", "ASM", "x86"]
---

When it comes to vanilla buffer overflow, `JMP ESP` instruction is the one you look for when you got control over EIP register. 

Now let's assume that DEP is not enabled and due to ASLR and/or JMP ESP addresses contains bad characters, which make those address impossible to use.   

We can look for the following assembly instructions instead: 

- PUSH ESP; RET (54C3)

```
0:012> u 77c73989
ntdll!ResCDirectoryValidateEntries+0x1805:
77c73989 54              push    esp
77c7398a c3              ret
```

- CALL ESP; (FFD4)

```
0:012> u 77c77254
ntdll!ResCDirectoryValidateEntries+0x50d0:
77c77254 ffd4            call    esp
```

Above instructions are an alternative to JMP ESP, whoever, it is important to note that creativity is the key here, it all depends on the restrictions you are facing and what other register/s you control and so on but once you can control EIP you can be creative on how to use gadgets to achieve your goal, think out of the box!



