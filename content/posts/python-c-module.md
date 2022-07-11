---
title: "Let's build a Python module in C"
category: Programming
tags: ["C","Python", "Windows"]
date: 2020-10-04
---

## Background

Python is one of the most used programming language nowadays specially due its popularity in data science, deep and machine learning fields; Truth to be told, under the hood there is C and/or C++ code running.

Let's take for example some popular python libraries used in math and machine learn to illustrate that point:

* [Numpy](https://github.com/numpy/numpy) (33.2% of the code is written in C)
* [TensorFlow](https://github.com/tensorflow/tensorflow) (61% of the code is written in C++) 
* [PyTorch](https://github.com/pytorch/pytorch) (53% of the code in written in C++ and 4% in C) 

The raison that these libraries are build in C and/or C++ is for performance issues mainly, also it is important to note that Python is written in C, hence it provides a C API to extend the language by creating new modules at lower-level possible.

## Disclaimer

This blog post won't be an introduction to the internals of Python, however, I'll leave at the bottom of the page some useful resources on the subject if anyone is interested. 

In this post, I am going to walk you through on how to write a minimalist Python module in C, however, since I believe that Hello Words' are boring, we are going to write a module that checks if a file is a valid PE (Portable Executable) using Windows API.

In order to follow with me, you will need a Windows machine with Visual Studio C++ and Python installed on the system.

## Let's start coding, shall we? 

As mentioned earlier, we will see the minimalist C code required to build a module, basically a C module requires several things but most of all it needs:

* Function that makes up the core functionality of your C module
* Definitions of the module and the methods of your C module
* Initialize your C module 

Let's start by writing our core function that checks if a file is portable executable, we will use the following Windows API functions:

* CreateFileA
* CreateFileMapping
* MapViewOfFile
* UnmapViewOfFile
* CloseHandle

The function takes a parameter and returns True if the file is a PE, False otherwise;

```C
static PyObject* isValidPE(PyObject *self, PyObject* args)
{
	LPSTR pfile =  NULL;

	if(!PyArg_ParseTuple(args, "s", &pfile))
	{
      		return Py_None;
	}

	// Get file handler.
	HANDLE hFile = CreateFileA(
		pfile,
		GENERIC_READ,
		FILE_SHARE_READ,
		NULL,
		OPEN_EXISTING,
		FILE_ATTRIBUTE_NORMAL,
		NULL
	);

	// Error check.
	if(hFile == INVALID_HANDLE_VALUE)
	{
		PyErr_SetString(PyExc_ValueError, "CreateFileA retuned INVALID_HANDLE_VALUE.");
		return Py_None;
	}

	// Map the EXE file.
	HANDLE hMapFile = CreateFileMapping(
		hFile,
		NULL,
		PAGE_READONLY,
		0,
		0,
		NULL
	);

	// Error check.
	if(hMapFile == NULL)
	{
		PyErr_SetString(PyExc_ValueError, "CreateFileMapping retuned NULL.");
		return Py_None;
	}

	// Get the base address.
	LPVOID lpBase = MapViewOfFile(
		hMapFile,
		FILE_MAP_READ,
		0, 0, 0);

	// Error check.
	if(lpBase == NULL)
	{
		PyErr_SetString(PyExc_ValueError, "MapViewOfFile retuned NULL.");
		return Py_None;
	}

	PIMAGE_DOS_HEADER dosHeader = (PIMAGE_DOS_HEADER)lpBase;

	// Clean up. 
	UnmapViewOfFile(hMapFile);
	CloseHandle(hMapFile);
	CloseHandle(hFile);
	
	// Either True or False.
	return dosHeader->e_magic == IMAGE_DOS_SIGNATURE ? Py_True : Py_False;
}
```

The function returns `PyObject`  which is an object structure that you use to define object types in Python; All other object types are extensions of this type.

On our function we used the following Python object structures:

* PyObject (equivalent to Object in Java)
* PyArg_ParseTyple (used to parse function arguments)
* PyNone (equivalent to NULL in C)
* PyErr_SetString (used to raise error)
* Py_True (Python object that represents true)
* Py_False (Python object that represents false) 

Now that we wrote the core functionality of the module, let's define our function using `PyMethodDef`:

```C
static PyMethodDef pevalidator_module_methods[] = {
    {"isValidPE", (PyCFunction)isValidPE, METH_VARARGS, "This method checks if a file is  a valid PE."},
    {NULL, NULL, 0, NULL}
};
```

* **"isValidPE"** is the name we will use to invoke this particular function
* **(PyCFunction)isValidPE** is the name of the C function to invoke 
* **METH_VARARGS** is a flag that tells Python interpreter that this function take arguments
* The last parameter is a string used to represent the method docstring

Next step is to define our module:

```C
static struct PyModuleDef pevalidator_module = {
    PyModuleDef_HEAD_INIT,
    "pevalidator",
    "This module checks if a file is PE file.",
    -1,
    pevalidator_module_methods
};
```

* **PyModuleDef_HEAD_INIT** advised to have 
* **"pevalidator"** is the name of the C module
* A string used to represent the module's description docstring
* **-1** represents an amount of memory needed to store the program state
* **pevalidator_module_methods** reference to the methods table, the one we defined earlier

We are almost there! In order to build and import the module we will use `distrutils` :

```Python
from distutils.core import setup, Extension

setup(name="pevalidator", version="1.0", ext_modules=[Extension('pevalidator',
    ['pevalidator.c'])])
```

* **pevalidator** is the name of the module
*  **['pevalidator.c']** list of sources files relative to `setup.py`.

Here is how to build the module:

```powershell
PS C:\Users\tahai\code\python-c-module> python .\setup.py build
running build
running build_ext
building 'pevalidator' extension
creating build
creating build\temp.win32-3.8
creating build\temp.win32-3.8\Release
C:\Program Files (x86)\Microsoft Visual Studio\2019\Community\VC\Tools\MSVC\14.26.28801\bin\HostX86\x86\cl.exe /c /nologo /Ox /W3 /GL /DNDEBUG /MD -IC:\Users\tahai\AppData\Local\Programs\Python\Python38-32\include -IC:\Users\tahai\AppData\Local\Programs\Python\Python38-32\include "-IC:\Program Files (x86)\Microsoft Visual Studio\2019\Community\VC\Tools\MSVC\14.26.28801\ATLMFC\include" "-IC:\Program Files (x86)\Microsoft Visual Studio\2019\Community\VC\Tools\MSVC\14.26.28801\include" "-IC:\Program Files (x86)\Windows Kits\NETFXSDK\4.8\include\um" "-IC:\Program Files (x86)\Windows Kits\10\include\10.0.18362.0\ucrt" "-IC:\Program Files (x86)\Windows Kits\10\include\10.0.18362.0\shared" "-IC:\Program Files (x86)\Windows Kits\10\include\10.0.18362.0\um" "-IC:\Program Files (x86)\Windows Kits\10\include\10.0.18362.0\winrt" "-IC:\Program Files (x86)\Windows Kits\10\include\10.0.18362.0\cppwinrt" "-IC:\Program Files (x86)\Fasm\INCLUDE" /Tcpevalidator.c /Fobuild\temp.win32-3.8\Release\pevalidator.obj
pevalidator.c
creating C:\Users\tahai\code\python-c-module\build\lib.win32-3.8
C:\Program Files (x86)\Microsoft Visual Studio\2019\Community\VC\Tools\MSVC\14.26.28801\bin\HostX86\x86\link.exe /nologo /INCREMENTAL:NO /LTCG /DLL /MANIFEST:EMBED,ID=2 /MANIFESTUAC:NO /LIBPATH:C:\Users\tahai\AppData\Local\Programs\Python\Python38-32\libs /LIBPATH:C:\Users\tahai\AppData\Local\Programs\Python\Python38-32\PCbuild\win32 "/LIBPATH:C:\Program Files (x86)\Microsoft Visual Studio\2019\Community\VC\Tools\MSVC\14.26.28801\ATLMFC\lib\x86" "/LIBPATH:C:\Program Files (x86)\Microsoft Visual Studio\2019\Community\VC\Tools\MSVC\14.26.28801\lib\x86" "/LIBPATH:C:\Program Files (x86)\Windows Kits\NETFXSDK\4.8\lib\um\x86" "/LIBPATH:C:\Program Files (x86)\Windows Kits\10\lib\10.0.18362.0\ucrt\x86" "/LIBPATH:C:\Program Files (x86)\Windows Kits\10\lib\10.0.18362.0\um\x86" /EXPORT:PyInit_pevalidator build\temp.win32-3.8\Release\pevalidator.obj /OUT:build\lib.win32-3.8\pevalidator.cp38-win32.pyd /IMPLIB:build\temp.win32-3.8\Release\pevalidator.cp38-win32.lib
   Creating library build\temp.win32-3.8\Release\pevalidator.cp38-win32.lib and object build\temp.win32-3.8\Release\pevalidator.cp38-win32.exp
Generating code
Finished generating code
PS C:\Users\tahai\code\python-c-module>
```

Before we can import and use the module we need to install the module as fellow:

```powershell
PS C:\Users\tahai\code\python-c-module> python .\setup.py install
running install
running build
running build_ext
running install_lib
copying build\lib.win32-3.8\pevalidator.cp38-win32.pyd -> C:\Users\tahai\AppData\Local\Programs\Python\Python38-32\Lib\site-packages
running install_egg_info
Removing C:\Users\tahai\AppData\Local\Programs\Python\Python38-32\Lib\site-packages\pevalidator-1.0-py3.8.egg-info
Writing C:\Users\tahai\AppData\Local\Programs\Python\Python38-32\Lib\site-packages\pevalidator-1.0-py3.8.egg-info
PS C:\Users\tahai\code\python-c-module>
```

## In Action:

```powershell
PS C:\Users\tahai\code\python-c-module> python
Python 3.8.5 (tags/v3.8.5:580fbb0, Jul 20 2020, 15:43:08) [MSC v.1926 32 bit (Intel)] on win32
Type "help", "copyright", "credits" or "license" for more information.
>>> import pevalidator as pev
>>> pev.isValidPE("c:\\windows\\system32\\notepad.exe")
True
>>> pev.isValidPE("C:\\Users\\tahai\\code\\python-c-module\\setup.py")
False
>>> pev.isValidPE("C:\\doesnotexist.exe")
ValueError: CreateFileA retuned INVALID_HANDLE_VALUE.

The above exception was the direct cause of the following exception:

Traceback (most recent call last):
  File "<stdin>", line 1, in <module>
SystemError: <built-in function isValidPE> returned a result with an error set
>>> exit()
PS C:\Users\tahai\code\python-c-module>
```

## Final Code

{{< gist tahadraidia 9c57146c35f0ba0fced39b80883ab2d1 >}}

## Useful References

* [https://docs.python.org/3/c-api/index.html](https://docs.python.org/3/c-api/index.html)
* [https://realpython.com/build-python-c-extension-module/](https://realpython.com/build-python-c-extension-module/)
* [https://pg.ucsd.edu/cpython-internals.htm](https://pg.ucsd.edu/cpython-internals.htm)
* [https://medium.com/@dawranliou/getting-started-with-python-internals-a5474ccb8022](https://medium.com/@dawranliou/getting-started-with-python-internals-a5474ccb8022)
* [https://docs.microsoft.com/en-us/windows/win32/api/winbase/nf-winbase-createfilemappinga](https://docs.microsoft.com/en-us/windows/win32/api/winbase/nf-winbase-createfilemappinga)
* [https://docs.microsoft.com/en-us/windows/win32/api/memoryapi/nf-memoryapi-mapviewoffile](https://docs.microsoft.com/en-us/windows/win32/api/memoryapi/nf-memoryapi-mapviewoffile)
* [https://docs.microsoft.com/en-us/windows/win32/api/fileapi/nf-fileapi-createfilea](https://docs.microsoft.com/en-us/windows/win32/api/fileapi/nf-fileapi-createfilea)
