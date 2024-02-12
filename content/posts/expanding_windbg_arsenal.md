---
title: "Expanding Our WinDBG Arsenal - Handleex Extension"
date: 2023-07-14
slug: expanding-our-windbg-arsenal-handleex-extension
cover: https://cdn.hashnode.com/res/hashnode/image/upload/v1689332063820/f169c4a5-6664-4b9f-b724-bd01923a9171.png
tags: [cpp, c, reverse-engineering, windbg, ntdll]

---

> This post has been ported from Darkwaves InfoSec blog.

### Introduction

When it comes to dynamic analysis on Windows, WinDBG is our option of choice. The debugger provides several built-in extensions such as analyze, heap, gle and allows extendibility by creating extensions using several programming languages.

During an engagement for a client, a need emerged to retrieve the filename associated with a file handle, all that is within the userland.

As mentioned earlier, WinDBG comes up with diverse built-in extensions, one of which `handle`, and the extension displays information for the given handle.

```txt
0:007> !handle -?
!handle [<handle>] [<flags>] [<type>]
 <handle> - Handle to get information about
            0 or -1 means all handles
 <flags> - Output control flags
           1   - Get type information (default)
           2   - Get basic information
           4   - Get name information
           8   - Get object specific info (where available) (space-delimited, 32-bit
           max)
 <type> - Limit query to handles of the given type
Display information about open handles
```

Unfortunately, the filename linked to the file handle is not displayed by the extension. However, if you are familiar with Sysinternals Suite, you may be aware of Handle Viewer, a tool that dumps handle information, including the corresponding filename.

![](https://cdn.hashnode.com/res/hashnode/image/upload/v1685282581969/34fb3348-d281-4770-b48a-abc7a87fa64f.png)

### How Does Nthandle Retrieve Information About a Handle?

The tool runs as a standalone application and does not require admin privileges. This means it is possible to obtain handle information from userland without any special privileges. Nonetheless, the question remains: how does Nthandle retrieve information about a handle?

Starting inspecting the imported libraries in IDA revealed the usage of common high-level modules, such as ADVAPI32, COMDLG32, GDI32, KERNEL32, and USER32.

At first glance, none of the imported APIs appeared to be directly used to retrieve information from a handle.

![](https://cdn.hashnode.com/res/hashnode/image/upload/v1685282622737/127316f7-89fb-4433-a782-c7fed8c1cbef.png)

After renaming some labels in IDA, the main function now looks something like this.

![](https://cdn.hashnode.com/res/hashnode/image/upload/v1685282649659/3706b846-206e-493b-8aff-a821a1d4505a.png)

At this point, the pseudo-code should be self-explanatory. The functions that interest us are load\_ntdll\_symbols() and golden\_function().

![](https://cdn.hashnode.com/res/hashnode/image/upload/v1685286926906/d864ccd8-759a-480f-859d-e1d9ad2a6c50.png)

Interestingly, NtQuerySystemInformation() provides several pieces of information about the system, including handle information. Furthermore, while inspecting golden\_function(), we came across sub\_140007980().

![](https://cdn.hashnode.com/res/hashnode/image/upload/v1685283173398/6a4b0f28-c2fe-42cf-bf6a-804c4224d35e.png)

The function obtains handle information by leveraging the NtQuerySystemInformation() API, as shown below.

![](https://cdn.hashnode.com/res/hashnode/image/upload/v1685283186453/e529b1b9-6dc4-4d6b-b0cb-348afda17798.png)

The NtQuerySystemInformation() API is a Windows API that allows developers to retrieve system information. One particular use case is retrieving handles information without requiring privileged permissions. The API requires the following parameters:

1. `SystemInformationClass`: This parameter specifies the type of system information to retrieve. For handles information, the appropriate value is `SystemHandleInformation`. This class allows obtaining details about open handles in the system.
    
2. `SystemInformation`: This parameter is a pointer to a buffer that receives the requested system information. For handles information, the buffer should be appropriately sized to accommodate the returned data, typically an array of structures.
    
3. `SystemInformationLength`: This parameter specifies the size of the buffer provided in the `SystemInformation` parameter.
    
4. `ReturnLength`: An optional parameter that receives the actual size of the system information returned by the API. This helps to ensure that the provided buffer is large enough to hold the data and enables the caller to resize the buffer if needed.
    

By using the `SystemHandleInformation` class with NtQuerySystemInformation(), developers can retrieve details about the handles present in the system. This information includes the handle value, process ID, object type, access rights, and other relevant details. It allows you to enumerate and analyze the handles used by processes running on the system.

One important aspect of NtQuerySystemInformation() is that it provides a way to retrieve handles information without requiring privileged permissions. While certain privileged APIs might offer more comprehensive handle-related information, NtQuerySystemInformation() can provide valuable insights for analysis and troubleshooting, even in scenarios where elevated privileges are not available.

### Handleex Windbg Extension is Born

Now that we have established how Nthandle obtains information about a handle, it is time to build our own Windbg extension that allows us to retrieve the associated name of an object. To accomplish this, the extension will leverage the following undocumented APIs:

* NtQuerySystemInformation()
    
* NtDuplicateObject()
    
* NtQueryObject()
    
NtQuerySystemInformation() will be used to retrieve all handles on the system. Since we are not running within the target process, NtDuplicateObject() will be used to duplicate the handle that we would like to obtain information about. The documented equivalent in the Windows API is DuplicateToken(). Finally, NtQueryObject() will be used to retrieve the object type and name.

The NtQueryObject() API is a Windows Native API function that can be used to retrieve various information about an object in the system, including its type and filename. To retrieve the object type, one can pass the ObjectInformationClass parameter as ObjectTypeInformation to the NtQueryObject() function. This will return information about the object, including its type. To retrieve the filename associated with the object, one can pass the ObjectInformationClass parameter as ObjectNameInformation. The function will then provide the name of the object, if available, in the returned information.

Following is a screenshot of the Windbg extension in action.

![](https://cdn.hashnode.com/res/hashnode/image/upload/v1685283285591/b215b905-5697-4718-af48-e19fe037de96.png)

You can find the source code here: [https://github.com/tahadraidia/windbg-arsenal/tree/main/handleex](https://github.com/tahadraidia/windbg-arsenal/tree/main/handleex)

Further Reading

* https://learn.microsoft.com/en-us/windows-hardware/drivers/debugger/
    
* https://learn.microsoft.com/en-us/windows-hardware/drivers/debugger/-analyze
    
* https://learn.microsoft.com/en-us/windows-hardware/drivers/debugger/-handle
    
* https://learn.microsoft.com/en-us/windows/win32/api/winternl/nf-winternl-ntquerysysteminformation
