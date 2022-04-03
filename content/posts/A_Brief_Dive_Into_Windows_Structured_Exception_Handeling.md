---
title: "A Brief Dive Into Windows Structured Exception Handling"
date: 2021-12-22T07:27:39Z
categories: ["Exploit Development", "Low Level"]
tags: ["OSED", "PEN301", "Windows", "Assembly x86", "System", "FASM", "Windbg"]
---

When it comes to handle exceptions in programming, we are all familiar with `try/catch` and it's other variant syntax sugar.  For example below is a divide by zero error raised as an exception in python.

```python
PS C:\Users\tahai\code\blog> python
Python 3.6.4 (v3.6.4:d48eceb, Dec 19 2017, 06:54:40) [MSC v.1900 64 bit (AMD64)] on win32
Type "help", "copyright", "credits" or "license" for more information.
>>> d = 9 // 0
Traceback (most recent call last):
  File "<stdin>", line 1, in <module>
ZeroDivisionError: integer division or modulo by zero
>>>
```

The exception name is called `ZeroDivisionError`, in this case we didn't catch the error but the system did for us.

We can improve a bit our code like the following:

```python
>>> try:
...     d = 9 // 0
... except Exception as e:
...     print(f"Exception raised: {e}")
...
Exception raised: integer division or modulo by zero
>>>
```

Nice! we caught an exception, however, this is a generic as the name says `Exception`, the exception was not precise or specific. Because we are dealing with divisions we can say the program, needs to raise an exception if division by zero instance occurred but the program needs to keep running.

To resolve this we can use `ZeroDivisonError` exception instead of Exception right.

```python
>>> try:
...     d = 9 // 0
... except ZeroDivisionError as e:
...     print(f"Zero Deivions Error spotted: {e}")
...
Zero Divison Error spotted: integer division or modulo by zero
>>>
```

This works, we isolated the case of zero division but what happens if another type of error raises within the same try/except block? Let us say that an error occurs just before zero division one.

```python
>>> try:
...     pint("foobar")
...     d = 9 // 0
... except ZeroDivisionError as e:
...     print(f"Exception raised: {e}")
...
Traceback (most recent call last):
  File "<stdin>", line 2, in <module>
NameError: name 'pint' is not defined
>>>
```

Well, it goes unhandled by our program but the system still catches it but the program crashed.
In this case `NameError` was raised because we have misspelled `print()` function. In order to illustrate the idea that the system can encounter nested exception and exceptions are stored in a list we are going to arise an exception that the system cannot handle.

```python
>>> try:
...     d = 9 // 0
... except Exception(e):
...     print("Exception raised!")
...
Traceback (most recent call last):
  File "<stdin>", line 2, in <module>
ZeroDivisionError: integer division or modulo by zero

During handling of the above exception, another exception occurred:

Traceback (most recent call last):
  File "<stdin>", line 3, in <module>
NameError: name 'e' is not defined
```

Notice this message down below:

```python
During handling of the above exception, another exception occurred:

Traceback (most recent call last):
  File "<stdin>", line 3, in <module>
NameError: name 'e' is not defined
```

Not bad, this shows that the system can catch nested exceptions, now is the time to go through some definitions, until now we have dealt with only software exceptions, as the name says you can guess the opponent exception which, is hardware exception, which are initiated by the CPU. This could occurs when a program tries to read from a no valid memory address for example.

Now that we now the types of exceptions, what we need to know is that they work at thread level, which means we can found information of those exception in the Thread Environment Block structure of Windows.

Let us open notepad (x86 version) within windbg and set a break point at the entry, so we can exam the structure.

```nasm
0:000> bp $exentry
0:000> g
ModLoad: 77090000 770b5000   C:\WINDOWS\SysWOW64\IMM32.DLL
Breakpoint 0 hit
eax=0012830c ebx=00204000 ecx=00941860 edx=00005000 esi=00941860 edi=00941860
eip=00941860 esp=0047fd64 ebp=0047fd70 iopl=0         nv up ei pl zr na pe cy
cs=0023  ss=002b  ds=002b  es=002b  fs=0053  gs=002b             efl=00000247
notepad!wWinMainCRTStartup:
00941860 e85d080000      call    notepad!__security_init_cookie (009420c2)
```

Using `dt` we can examine `TEB` structure in Windbg.

```nasm
0:000> dt _TEB
ntdll!_TEB
   +0x000 NtTib            : _NT_TIB
   +0x01c EnvironmentPointer : Ptr32 Void
   +0x020 ClientId         : _CLIENT_ID
   +0x028 ActiveRpcHandle  : Ptr32 Void
   +0x02c ThreadLocalStoragePointer : Ptr32 Void
   +0x030 ProcessEnvironmentBlock : Ptr32 _PEB
   +0x034 LastErrorValue   : Uint4B
   +0x038 CountOfOwnedCriticalSections : Uint4B
   +0x03c CsrClientThread  : Ptr32 Void
   +0x040 Win32ThreadInfo  : Ptr32 Void
   +0x044 User32Reserved   : [26] Uint4B
   +0x0ac UserReserved     : [5] Uint4B
   +0x0c0 WOW32Reserved    : Ptr32 Void
   +0x0c4 CurrentLocale    : Uint4B
   +0x0c8 FpSoftwareStatusRegister : Uint4B
   +0x0cc ReservedForDebuggerInstrumentation : [16] Ptr32 Void
   +0x10c SystemReserved1  : [26] Ptr32 Void
   +0x174 PlaceholderCompatibilityMode : Char
   +0x175 PlaceholderHydrationAlwaysExplicit : UChar
   +0x176 PlaceholderReserved : [10] Char
   +0x180 ProxiedProcessId : Uint4B
   +0x184 _ActivationStack : _ACTIVATION_CONTEXT_STACK
   +0x19c WorkingOnBehalfTicket : [8] UChar
   +0x1a4 ExceptionCode    : Int4B
   +0x1a8 ActivationContextStackPointer : Ptr32 _ACTIVATION_CONTEXT_STACK
   +0x1ac InstrumentationCallbackSp : Uint4B
...
```

The first field is the one that interests us, `NtTib` at offset `0x00` is a structure of type `_NT_TIB` we can use dt command again examine that structure.

```nasm
0:000> dt _NT_TIB
ntdll!_NT_TIB
   +0x000 ExceptionList    : Ptr32 _EXCEPTION_REGISTRATION_RECORD
   +0x004 StackBase        : Ptr32 Void
   +0x008 StackLimit       : Ptr32 Void
   +0x00c SubSystemTib     : Ptr32 Void
   +0x010 FiberData        : Ptr32 Void
   +0x010 Version          : Uint4B
   +0x014 ArbitraryUserPointer : Ptr32 Void
   +0x018 Self             : Ptr32 _NT_TIB
```

ExceptionList is the first element of the structure, that's the one we are looking for, the type of the structure is `_EXCEPTION_REGISTRATION_RECORD`.

```nasm
0:000> dt _EXCEPTION_REGISTRATION_RECORD
ntdll!_EXCEPTION_REGISTRATION_RECORD
   +0x000 Next             : Ptr32 _EXCEPTION_REGISTRATION_RECORD
   +0x004 Handler          : Ptr32     _EXCEPTION_DISPOSITION
```

This is a singled linked list of `_EXCEPTION_REGISTRATION_RECORD`, as the first member (Next) points to the next exception_registration_record struct, the end of the list is defined with the value `-1` in hex.

The second member (Handler) is a pointer to the exception call back function named `_exception_handler`, this returns `_EXCEPTION_DISPOSITION` enum.

```nasm
0:000> dt _EXCEPTION_DISPOSITION
ntdll!_EXCEPTION_DISPOSITION
   ExceptionContinueExecution = 0n0
   ExceptionContinueSearch = 0n1
   ExceptionNestedException = 0n2
   ExceptionCollidedUnwind = 0n3
```

However, we only see the value returned from the function callback, searching for `_excpect_handler` string in file headers several matches were retourned.

![search_code](/images/windows_seh/search_except_handler.png)

Note that on the machine I am using, mingw is installed and visual C++ as well. We will pick visual c++ implementation.

We can find `_EXCEPTION_DISPOSITION` enum declaration at line 18.

```C
...
 18 // Exception disposition return values
 19 typedef enum _EXCEPTION_DISPOSITION
 20 {
 21     ExceptionContinueExecution,
 22     ExceptionContinueSearch,
 23     ExceptionNestedException,
 24     ExceptionCollidedUnwind
 25 } EXCEPTION_DISPOSITION;
 ...
 ```

 If we scroll down to line 29 we find `_except_handler` function decorator.

 ```C
 ...
 29 // SEH handler
 30 #ifdef _M_IX86
 31
 32     struct _EXCEPTION_RECORD;
 33     struct _CONTEXT;
 34
 35     EXCEPTION_DISPOSITION __cdecl _except_handler(
 36         _In_ struct _EXCEPTION_RECORD* _ExceptionRecord,
 37         _In_ void*                     _EstablisherFrame,
 38         _Inout_ struct _CONTEXT*       _ContextRecord,
 39         _Inout_ void*                  _DispatcherContext
 40         );
 41
 42 #elif defined _M_X64 || defined _M_ARM || defined _M_ARM64
 43     #ifndef _M_CEE_PURE
 44
 45         struct _EXCEPTION_RECORD;
 46         struct _CONTEXT;
 47         struct _DISPATCHER_CONTEXT;
 48
 49         _VCRTIMP EXCEPTION_DISPOSITION __C_specific_handler(
 50             _In_    struct _EXCEPTION_RECORD*   ExceptionRecord,
 51             _In_    void*                       EstablisherFrame,
 52             _Inout_ struct _CONTEXT*            ContextRecord,
 53             _Inout_ struct _DISPATCHER_CONTEXT* DispatcherContext
 54             );
 55
 56     #endif
 57 #endif
 ...
 ```

 We will focus on the x86 implementation, since we are dealing with x86 Assembly for now.

 ```C
 ...
 30 #ifdef _M_IX86
 31
 32     struct _EXCEPTION_RECORD;
 33     struct _CONTEXT;
 34
 35     EXCEPTION_DISPOSITION __cdecl _except_handler(
 36         _In_ struct _EXCEPTION_RECORD* _ExceptionRecord,
 37         _In_ void*                     _EstablisherFrame,
 38         _Inout_ struct _CONTEXT*       _ContextRecord,
 39         _Inout_ void*                  _DispatcherContext
 40         );
 41
 42 #elif defined _M_X64 || defined _M_ARM || defined _M_ARM64
 ...

 ```

 The function takes four parameters, two in and other out. for us `_EstablisherFrame` and `_ContextRecord` are the ones that interest us.

 EtablisherFrame points to the `_Exceptation_Regeistration_Record` structure, ContextRecord a Context structure is very interesting, this structure contains assembly registers such as EIP and so on.

 ```C
 0:000> dt _CONTEXT
ntdll!_CONTEXT
   +0x000 ContextFlags     : Uint4B
   +0x004 Dr0              : Uint4B
   +0x008 Dr1              : Uint4B
   +0x00c Dr2              : Uint4B
   +0x010 Dr3              : Uint4B
   +0x014 Dr6              : Uint4B
   +0x018 Dr7              : Uint4B
   +0x01c FloatSave        : _FLOATING_SAVE_AREA
   +0x08c SegGs            : Uint4B
   +0x090 SegFs            : Uint4B
   +0x094 SegEs            : Uint4B
   +0x098 SegDs            : Uint4B
   +0x09c Edi              : Uint4B
   +0x0a0 Esi              : Uint4B
   +0x0a4 Ebx              : Uint4B
   +0x0a8 Edx              : Uint4B
   +0x0ac Ecx              : Uint4B
   +0x0b0 Eax              : Uint4B
   +0x0b4 Ebp              : Uint4B
   +0x0b8 Eip              : Uint4B
   +0x0bc SegCs            : Uint4B
   +0x0c0 EFlags           : Uint4B
   +0x0c4 Esp              : Uint4B
   +0x0c8 SegSs            : Uint4B
   +0x0cc ExtendedRegisters : [512] UChar
 ```

Now that we had a tiny grasp of SEH implementation, let us list list of exception of the current process using Windbg command/extension called `exchain`.

```nasm
0:000> !exchain
0047fdbc: ntdll!_except_handler4+0 (7714ad40)
  CRT scope  0, filter: ntdll!__RtlUserThreadStart+3cdb8 (77174827)
                func:   ntdll!__RtlUserThreadStart+3ce51 (771748c0)
0047fdd4: ntdll!FinalExceptionHandlerPad9+0 (77158a39)
Invalid exception stack at ffffffff
```

Notice `Invalid exceptiion stack at fffffff`, this marks the end of ExceptionList. From the output of the command we can tell that ExceptionList starts at `0x0047fdbc` and its Handler function address is `0x7714ad40`. Also the next `_EXCEPTION_REGISTRATION_RECORD` structure starts at `0x0047fdd4` and its Handle function callback address is `0x77158a39`.

- 0047fdbc: ntdll!_except_handler4+0 (7714ad40)
- 0047fdd4: ntdll!FinalExceptionHandlerPad9+0 (77158a39)

We can confirm that by manually walking through ExceptionList using the memory address given by the command above but before we do that let us confirm the ExceptionList using `teb` extension.

```nasm
0:000> !teb
TEB at 00207000
    ExceptionList:        0047fdbc
    StackBase:            00480000
    StackLimit:           0046f000
    SubSystemTib:         00000000
    FiberData:            00001e00
    ArbitraryUserPointer: 00000000
    Self:                 00207000
    EnvironmentPointer:   00000000
    ClientId:             00002254 . 0000385c
    RpcHandle:            00000000
    Tls Storage:          00654fe8
    PEB Address:          00204000
    LastErrorValue:       126
    LastStatusValue:      c0000135
    Count Owned Locks:    0
    HardErrorMode:        0

```

The address of ExceptionList matches the one we got from `!exchain`, let us go further and investigate.

```nasm
0:000> dt _nt_tib 0047fdbc
ntdll!_NT_TIB
   +0x000 ExceptionList    : 0x0047fdd4 _EXCEPTION_REGISTRATION_RECORD
   +0x004 StackBase        : 0x7714ad40 Void
   +0x008 StackLimit       : 0x89b0af72 Void
   +0x00c SubSystemTib     : (null)
   +0x010 FiberData        : 0x0047fddc Void
   +0x010 Version          : 0x47fddc
   +0x014 ArbitraryUserPointer : 0x77137a6e Void
   +0x018 Self             : 0xffffffff _NT_TIB
```

We know that ExceptionList is a singled linked list of `_EXCEPTION_REGISTRATION_RECORD`, next we take the pointer of the structure inspect it with `dt`.

```nasm
0:000> dt _EXCEPTION_REGISTRATION_RECORD 0x0047fdd4
ntdll!_EXCEPTION_REGISTRATION_RECORD
   +0x000 Next             : 0xffffffff _EXCEPTION_REGISTRATION_RECORD
   +0x004 Handler          : 0x77158a39     _EXCEPTION_DISPOSITION  ntdll!FinalExceptionHandlerPad9+0

```
Nice! Next member points to `0xffffffff`, which, means the end of the list as shown in `!exchain` command.

```nasm
0:000> !exchain
0047fdbc: ntdll!_except_handler4+0 (7714ad40)
  CRT scope  0, filter: ntdll!__RtlUserThreadStart+3cdb8 (77174827)
                func:   ntdll!__RtlUserThreadStart+3ce51 (771748c0)
0047fdd4: ntdll!FinalExceptionHandlerPad9+0 (77158a39)
Invalid exception stack at ffffffff
```

Notice the Handler pointer address match as well, I think we gain a bit more understanding of how SEH works at the very high level.

Next, we are going to write a tiny assembly program in FASM that prints the address of the ExceptionList, StackBase and StackLimit for the fun and profile (Mostly to reinforce our understanding in the subject).

```nasm
...
 18 start:
 19         xor edx,edx
 20         xor ebx,ebx
 21         xor ecx,ecx
 22
 23         mov ecx,[fs:ecx] ; ecx holds ExceptionList
 24         push ecx ; save it for later
 25         PrintPointer ecx,exception_address_string
 26
 27
 28         ;mov ebx,[ecx] ; ebx now holds Next (execption_registration_record) pointer
 29         pop ebx ; fetch ExceptionList address from stack.
 30         mov ebx, [ebx] ; Dereference the pointer (_Exception_Registration_Record struct) Next.
 31         PrintPointer ebx,exception_record ; ebx contains the value of Next.
 32         mov ebx,[ebx+0x4] ; ebx now ecx _exception_hander pointer (Handler)
 33         PrintPointer ebx,exception_handler
 34
 35         xor ecx,ecx
 36         mov ecx,[fs:0x4 ] ; ecx now holds StackBase
 37         PrintPointer ecx,stackbase_string
 38         mov ecx,[fs:0x8 ] ; ecx now holds StackLimit
 39         PrintPointer ecx,stacklimit_string
 40
 41         jmp finish
 42 finish:
 43         invoke TerminateProcess, 0xffffffff,0x00
 ...
```

The code is quite compact, it starts by null out edx,ebx and ecx registers respectively then copies the address of ExceptionList ot ecx register by accessing FS segment register at offset 0x00.

```nasm
	xor edx,edx
	xor ebx,ebx
	xor ecx,ecx

	mov ecx,[fs:ecx] ; ecx holds ExceptionList
	push ecx ; save it for later
	PrintPointer ecx,exception_address_string

```
Then it pushes ecx to the stack to save it for later on, after that we just print the address of ExceptionList using a custom macro called PrintPointer.

```nasm
macro PrintPointer reg,string
{
	xor eax,eax
	mov dword eax,string
        cinvoke printf,eax,reg
}
```

The macro is quite simple, it starts by zeroing out eax register, then copies a DWORD from what string variable contains to eax register and finally calls printfs function with reg.

Reg variable contains the pointer ExceptionList, to follow with me compile the code provided at the bottom of the page and open it with Windbg.

```nasm
0:000> bp $exentry
*** Unable to resolve unqualified symbol in Bp expression '$extentry'.
0:000> g
Breakpoint 1 hit
eax=000dffcc ebx=00308000 ecx=00401000 edx=00401000 esi=00401000 edi=00401000
eip=00401000 esp=000dff74 ebp=000dff80 iopl=0         nv up ei pl zr na pe nc
cs=0023  ss=002b  ds=002b  es=002b  fs=0053  gs=002b             efl=00000246
poc+0x1000:
00401000 31d2            xor     edx,edx
0:000> u @eip Lf
poc+0x1000:
00401000 31d2            xor     edx,edx
00401002 31db            xor     ebx,ebx
00401004 31c9            xor     ecx,ecx
00401006 648b09          mov     ecx,dword ptr fs:[ecx]
00401009 51              push    ecx
0040100a 31c0            xor     eax,eax
0040100c b800204000      mov     eax,offset poc+0x2000 (00402000)
00401011 51              push    ecx
00401012 50              push    eax
00401013 ff1560304000    call    dword ptr [poc+0x3060 (00403060)]
00401019 83c408          add     esp,8
0040101c 5b              pop     ebx
0040101d 8b1b            mov     ebx,dword ptr [ebx]
0040101f 31c0            xor     eax,eax
00401021 b813204000      mov     eax,offset poc+0x2013 (00402013)
```

We set a BP at `0040100a` the second `xor eax,eax` so we can examine the value of ecx which holds the pointer to ExceptionList.

```nasm
0:000> bp 0040100a
0:000> g
Breakpoint 2 hit
eax=000dffcc ebx=00000000 ecx=000dffcc edx=00000000 esi=00401000 edi=00401000
eip=0040100a esp=000dff70 ebp=000dff80 iopl=0         nv up ei pl zr na pe nc
cs=0023  ss=002b  ds=002b  es=002b  fs=0053  gs=002b             efl=00000246
poc+0x100a:
0040100a 31c0            xor     eax,eax
0:000> r @ecx
ecx=000dffcc
0:000> !teb
TEB at 0030b000
    ExceptionList:        000dffcc
    StackBase:            000e0000
    StackLimit:           000dd000
    SubSystemTib:         00000000
    FiberData:            00001e00
    ArbitraryUserPointer: 00000000
    Self:                 0030b000
    EnvironmentPointer:   00000000
    ClientId:             00003ac8 . 00003078
    RpcHandle:            00000000
    Tls Storage:          00156038
    PEB Address:          00308000
    LastErrorValue:       187
    LastStatusValue:      c00700bb
    Count Owned Locks:    0
    HardErrorMode:        0
```

Nice! rcx holds indeed ExceptionList pointer, next we will set a new bp at `0040101f`.

```nasm
0:000> u @eip La
poc+0x100a:
0040100a 31c0            xor     eax,eax
0040100c b800204000      mov     eax,offset poc+0x2000 (00402000)
00401011 51              push    ecx
00401012 50              push    eax
00401013 ff1560304000    call    dword ptr [poc+0x3060 (00403060)]
00401019 83c408          add     esp,8
0040101c 5b              pop     ebx
0040101d 8b1b            mov     ebx,dword ptr [ebx]
0040101f 31c0            xor     eax,eax
00401021 b813204000      mov     eax,offset poc+0x2013 (00402013)
0:000> bl
     0 e Disable Clear u             0001 (0001) ($extentry)
     1 e Disable Clear  00401000     0001 (0001)  0:**** poc+0x1000
     2 e Disable Clear  0040100a     0001 (0001)  0:**** poc+0x100a
0:000> bp 0040101f
0:000> g
Breakpoint 3 hit
eax=00000018 ebx=000dffe4 ecx=cbf993fe edx=00000000 esi=00401000 edi=00401000
eip=0040101f esp=000dff74 ebp=000dff80 iopl=0         nv up ei pl nz ac po nc
cs=0023  ss=002b  ds=002b  es=002b  fs=0053  gs=002b             efl=00000212
poc+0x101f:
0040101f 31c0            xor     eax,eax
```

At this point ebx should hold the pointer to `_exception_registration_record` structure.

```nasm
0:000> r
eax=00000018 ebx=000dffe4 ecx=cbf993fe edx=00000000 esi=00401000 edi=00401000
eip=0040101f esp=000dff74 ebp=000dff80 iopl=0         nv up ei pl nz ac po nc
cs=0023  ss=002b  ds=002b  es=002b  fs=0053  gs=002b             efl=00000212
poc+0x101f:
0040101f 31c0            xor     eax,eax
0:000> r @ebx
ebx=000dffe4
0:000> dt ExceptionList 000dffcc
Symbol ExceptionList not found.
0:000> dt _nt_tib 000dffcc
ntdll!_NT_TIB
   +0x000 ExceptionList    : 0x000dffe4 _EXCEPTION_REGISTRATION_RECORD
   +0x004 StackBase        : 0x7714ad40 Void
   +0x008 StackLimit       : 0x708455ec Void
   +0x00c SubSystemTib     : (null)
   +0x010 FiberData        : 0x000dffec Void
   +0x010 Version          : 0xdffec
   +0x014 ArbitraryUserPointer : 0x77137a6e Void
   +0x018 Self             : 0xffffffff _NT_TIB
0:000> dt _EXCEPTION_REGISTRATION_RECORD @ebx
ntdll!_EXCEPTION_REGISTRATION_RECORD
   +0x000 Next             : 0xffffffff _EXCEPTION_REGISTRATION_RECORD
   +0x004 Handler          : 0x77158a69     _EXCEPTION_DISPOSITION  ntdll!FinalExceptionHandlerPad57+0
```

Confirmed! we should now have an idea, let speed up our investigation and set a break point at the end before the program terminates (`0x00401080`).

```nasm
0:000> u @eip L20
poc+0x101f:
0040101f 31c0            xor     eax,eax
00401021 b813204000      mov     eax,offset poc+0x2013 (00402013)
00401026 53              push    ebx
00401027 50              push    eax
00401028 ff1560304000    call    dword ptr [poc+0x3060 (00403060)]
0040102e 83c408          add     esp,8
00401031 8b5b04          mov     ebx,dword ptr [ebx+4]
00401034 31c0            xor     eax,eax
00401036 b829204000      mov     eax,offset poc+0x2029 (00402029)
0040103b 53              push    ebx
0040103c 50              push    eax
0040103d ff1560304000    call    dword ptr [poc+0x3060 (00403060)]
00401043 83c408          add     esp,8
00401046 31c9            xor     ecx,ecx
00401048 648b0d04000000  mov     ecx,dword ptr fs:[4]
0040104f 31c0            xor     eax,eax
00401051 b840204000      mov     eax,offset poc+0x2040 (00402040)
00401056 51              push    ecx
00401057 50              push    eax
00401058 ff1560304000    call    dword ptr [poc+0x3060 (00403060)]
0040105e 83c408          add     esp,8
00401061 648b0d08000000  mov     ecx,dword ptr fs:[8]
00401068 31c0            xor     eax,eax
0040106a b84f204000      mov     eax,offset poc+0x204f (0040204f)
0040106f 51              push    ecx
00401070 50              push    eax
00401071 ff1560304000    call    dword ptr [poc+0x3060 (00403060)]
00401077 83c408          add     esp,8
0040107a eb00            jmp     poc+0x107c (0040107c)
0040107c 6a00            push    0
0040107e 6aff            push    0FFFFFFFFh
00401080 ff157c304000    call    dword ptr [poc+0x307c (0040307c)]
```

We hit the bp after executing the program and everything matches.

```nasm
0:000> g
Breakpoint 4 hit
eax=00000015 ebx=77158a69 ecx=cbf993fa edx=00000000 esi=00401000 edi=00401000
eip=00401080 esp=000dff6c ebp=000dff80 iopl=0         nv up ei pl nz ac pe nc
cs=0023  ss=002b  ds=002b  es=002b  fs=0053  gs=002b             efl=00000216
poc+0x1080:
*** Unable to resolve unqualified symbol in Bp expression '$extentry'.
00401080 ff157c304000    call    dword ptr [poc+0x307c (0040307c)] ds:002b:0040307c={KERNEL32!TerminateProcessStub (76029910)}
0:000> !exchain
000dffcc: ntdll!_except_handler4+0 (7714ad40)
  CRT scope  0, filter: ntdll!__RtlUserThreadStart+3cdb8 (77174827)
                func:   ntdll!__RtlUserThreadStart+3ce51 (771748c0)
000dffe4: ntdll!FinalExceptionHandlerPad57+0 (77158a69)
Invalid exception stack at ffffffff
0:000> !teb
TEB at 0030b000
    ExceptionList:        000dffcc
    StackBase:            000e0000
    StackLimit:           000dd000
    SubSystemTib:         00000000
    FiberData:            00001e00
    ArbitraryUserPointer: 00000000
    Self:                 0030b000
    EnvironmentPointer:   00000000
    ClientId:             00003ac8 . 00003078
    RpcHandle:            00000000
    Tls Storage:          00156038
    PEB Address:          00308000
    LastErrorValue:       187
    LastStatusValue:      c00700bb
    Count Owned Locks:    0
    HardErrorMode:        0
```

We can compare the output of the debugger along side with our program show in the screenshot below.

![PoC](/images/windows_seh/poc.png)

You can find the complete source code of the poc  here:

https://gist.github.com/tahadraidia/e95d104ba54b20f3b2ff17a381268bcd

References:
- SEH C/CPP MSDN  https://docs.microsoft.com/en-us/cpp/cpp/structured-exception-handling-c-cpp?view=msvc-170
- Windows core programming notes (eighteen) SEH structured exception one https://blog.csdn.net/wangpengk7788/article/details/54930185
- https://flatassembler.net/
- https://flatassembler.net/docs.php?article=fasmg_manual
- https://docs.microsoft.com/en-us/windows-hardware/drivers/debugger/getting-started-with-windbg
