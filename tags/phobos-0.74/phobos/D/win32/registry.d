/* /////////////////////////////////////////////////////////////////////////////
 * File:        registry.d
 *
 * Purpose:     Win32 Registry manipulation
 *
 * Created      15th March 2003
 * Updated:     13th October 2003
 *
 * Copyright:   Synesis Software Pty Ltd, (c) 2003. All rights reserved.
 *
 * Home:        http://www.synesis.com.au/software
 *
 * ////////////////////////////////////////////////////////////////////////// */



/** \file synsoft/win32/registry.d This file contains
 * the \c synsoft.win32.registry.* classes
 */

/* ////////////////////////////////////////////////////////////////////////// */

module synsoft.win32.registry;

/* /////////////////////////////////////////////////////////////////////////////
 * Imports
 */

//import synsoft.types;
/+ + These are borrowed from synsoft.types, until such time as something similar is in Phobos ++
 +/
public alias int                    boolean;

version(LittleEndian)
{
    private const int Endian_Ambient =   1;
}
version(BigEndian)
{
    private const int Endian_Ambient =   2;
}

public enum Endian
{
        Unknown =   0                   //!< Unknown endian-ness. Indicates an error
    ,   Little  =   1                   //!< Little endian architecture
    ,   Big     =   2                   //!< Big endian architecture
    ,   Middle  =   3                   //!< Middle endian architecture
    ,   ByteSex =   4
    ,   Ambient =   Endian_Ambient      //!< The ambient architecture, e.g. equivalent to Big on big-endian architectures.
/+ ++++ The compiler does not support this, due to deficiencies in the version() mechanism ++++
  version(LittleEndian)
  {
    ,   Ambient =   Little
  }
  version(BigEndian)
  {
    ,   Ambient =   Big
  }
+/
}
/+
 +/


//import synsoft.win32.types;
/+ + These are borrowed from synsoft.win32.types for the moment, but will not be
 + needed once I've convinced Walter to use strong typedefs for things like HKEY +
 +/
public typedef uint Reserved;
public typedef void *HKEY;
public alias HKEY   *PHKEY;
public alias char   *LPCSTR;
public alias int    LONG;
public alias uint   DWORD;
public alias DWORD  *LPDWORD;
public alias void   *LPSECURITY_ATTRIBUTES;
public alias char   *LPSTR;
public alias char   *LPCSTR;
public alias void   *LPCVOID;
public struct FILETIME
{
    DWORD   dwLowDateTime;
    DWORD   dwHighDateTime;
};
/+
 +/


//import synsoft.win32.error_codes;
/+ +++++++ These are in here for now, but will be in windows.d very soon +++++++
 +/
public const LONG   ERROR_SUCCESS           =   0;
public const LONG   ERROR_ACCESS_DENIED     =   5;
public const LONG   ERROR_MORE_DATA         =   234;
public const LONG   ERROR_NO_MORE_ITEMS     =   259;
/+
 +/


//import synsoft.win32.exception;
/+ +++ This is in here, until the Phobos exception hierarchy is implemented ++++
 +/
class Win32Exception
    : Exception
{
/// \name Construction
//@{
public:
    /// \brief Creates an instance of the exception
    ///
    /// \param message The message associated with the exception
    this(char[] message)
    {
        this(message, GetLastError());
    }
    /// \brief Creates an instance of the exception, with the given 
    ///
    /// \param message The message associated with the exception
    /// \param error The Win32 error number associated with the exception
    this(char[] message, int error)
    {
        char    sz[24]; // Enough for the three " ()" characters and a 64-bit integer value
        int     cch = wsprintfA(sz, " (%d)", error);

        m_message = message;
        m_error   = error;

        super(message ~ sz[0 .. cch]);
    }
//@}

/// \name Attributes
//@{
public:
    /// Returns the message string associated with the exception
    char[] Message()
    {
        return m_message;
    }

    /// Returns the Win32 error code associated with the exception
    int Error()
    {
        return m_error;
    }

    /// Converts the error code into a string
    ///
    /// \note Not yet implemented
    char[] LookupError(char[] moduleName)
    {
        return null;
    }

//@}

/// \name Members
//@{
private:
    char[]  m_message;
    int     m_error;
//@}
}

unittest
{
    // (i) Test that we can throw and catch one by its own type
    try
    {
        char[]  message =   "Test 1";
        int     code    =   3;
        char[]  string  =   "Test 1 (3)";

        try
        {
            throw new Win32Exception(message, code);
        }
        catch(Win32Exception x)
        {
            assert(x.Error == code);
            if(message != x.Message)
            {
                printf( "UnitTest failure for Win32Exception:\n"
                        "  x.message [%d;\"%.*s\"] does not equal [%d;\"%.*s\"]\n"
                    ,   x.Message.length, x.Message
                    ,   message.length, message);
            }
            assert(message == x.Message);
        }
    }
    catch(Exception /* x */)
    {
        int code_flow_should_never_reach_here = 0;
        assert(code_flow_should_never_reach_here);
    }

    // (ii) Catch that can throw and be caught by Exception
    {
        char[]  message =   "Test 2";
        int     code    =   3;
        char[]  string  =   "Test 2 (3)";

        try
        {
            throw new Win32Exception(message, code);
        }
        catch(Exception x)
        {
            if(string != x.toString())
            {
                printf( "UnitTest failure for Win32Exception:\n"
                        "  x.toString() [%d;\"%.*s\"] does not equal [%d;\"%.*s\"]\n"
                    ,   x.toString().length, x.toString()
                    ,   string.length, string);
            }
            assert(string == x.toString());
        }
    }
}
/+
 +/


//import synsoft.text.token;
/+ ++++++ This is borrowed from synsoft.text.token, until such time as something
 + similar is in Phobos ++++++++++++++++++++++++++++++++++++++++++++++++++++++++
 +/
char[][] tokenise(char[] source, char delimiter, boolean bElideBlanks, boolean bZeroTerminate)
{
    int         i;
    int         cDelimiters =   128;
    char[][]    tokens      =   new char[][cDelimiters];
    int         start;
    int         begin;
    int         cTokens;

    /// Ensures that the tokens array is big enough
    void ensure_length()
    {
        if(!(cTokens < tokens.length))
        {
            tokens.length = tokens.length * 2;
        }
    }

    if(bElideBlanks)
    {
        for(start = 0, begin = 0, cTokens = 0; begin < source.length; ++begin)
        {
            if(source[begin] == delimiter)
            {
                if(start < begin)
                {
                    ensure_length();

                    tokens[cTokens++]   =   source[start .. begin];
                }

                start = begin + 1;
            }
        }

        if(start < begin)
        {
            ensure_length();

            tokens[cTokens++]   =   source[start .. begin];
        }
    }
    else
    {
        for(start = 0, begin = 0, cTokens = 0; begin < source.length; ++begin)
        {
            if(source[begin] == delimiter)
            {
                ensure_length();

                tokens[cTokens++]   =   source[start .. begin];

                start = begin + 1;
            }
        }

        ensure_length();

        tokens[cTokens++]   =   source[start .. begin];
    }

    tokens.length = cTokens;

    if(bZeroTerminate)
    {
        for(i = 0; i < tokens.length; ++i)
        {
            tokens[i] ~= (char)0;
        }
    }

    return tokens;
}
/+
 +/


import string;

/* ////////////////////////////////////////////////////////////////////////// */

/// \defgroup group_synsoft_win32_reg synsoft.win32.registry
/// \ingroup group_synsoft_win32
/// \brief This library provides Win32 Registry facilities

/* /////////////////////////////////////////////////////////////////////////////
 * Private constants
 */

private const DWORD DELETE                      =   0x00010000L;
private const DWORD READ_CONTROL                =   0x00020000L;
private const DWORD WRITE_DAC                   =   0x00040000L;
private const DWORD WRITE_OWNER                 =   0x00080000L;
private const DWORD SYNCHRONIZE                 =   0x00100000L;

private const DWORD STANDARD_RIGHTS_REQUIRED    =   0x000F0000L;

private const DWORD STANDARD_RIGHTS_READ        =   0x00020000L/* READ_CONTROL */;
private const DWORD STANDARD_RIGHTS_WRITE       =   0x00020000L/* READ_CONTROL */;
private const DWORD STANDARD_RIGHTS_EXECUTE     =   0x00020000L/* READ_CONTROL */;

private const DWORD STANDARD_RIGHTS_ALL         =   0x001F0000L;

private const DWORD SPECIFIC_RIGHTS_ALL         =   0x0000FFFFL;

private const HKEY HKEY_CLASSES_ROOT            =   ((HKEY)0x80000000);
private const HKEY HKEY_CURRENT_USER            =   ((HKEY)0x80000001);
private const HKEY HKEY_LOCAL_MACHINE           =   ((HKEY)0x80000002);
private const HKEY HKEY_USERS                   =   ((HKEY)0x80000003);
private const HKEY HKEY_PERFORMANCE_DATA        =   ((HKEY)0x80000004);
private const HKEY HKEY_PERFORMANCE_TEXT        =   ((HKEY)0x80000050);
private const HKEY HKEY_PERFORMANCE_NLSTEXT     =   ((HKEY)0x80000060);
private const HKEY HKEY_CURRENT_CONFIG          =   ((HKEY)0x80000005);
private const HKEY HKEY_DYN_DATA                =   ((HKEY)0x80000006);

private const Reserved  RESERVED                =   (Reserved)0;

private const DWORD REG_CREATED_NEW_KEY     =   0x00000001;
private const DWORD REG_OPENED_EXISTING_KEY =   0x00000002;

/* /////////////////////////////////////////////////////////////////////////////
 * Public enumerations
 */

/// Enumeration of the recognised registry access modes
///
/// \ingroup group_synsoft_win32_reg
public enum REGSAM
{
        KEY_QUERY_VALUE         =   0x0001 //!< Permission to query subkey data
    ,   KEY_SET_VALUE           =   0x0002 //!< Permission to set subkey data
    ,   KEY_CREATE_SUB_KEY      =   0x0004 //!< Permission to create subkeys
    ,   KEY_ENUMERATE_SUB_KEYS  =   0x0008 //!< Permission to enumerate subkeys
    ,   KEY_NOTIFY              =   0x0010 //!< Permission for change notification
    ,   KEY_CREATE_LINK         =   0x0020 //!< Permission to create a symbolic link
    ,   KEY_WOW64_32KEY         =   0x0200 //!< Enables a 64- or 32-bit application to open a 32-bit key
    ,   KEY_WOW64_64KEY         =   0x0100 //!< Enables a 64- or 32-bit application to open a 64-bit key
    ,   KEY_WOW64_RES           =   0x0300 //!< 
    ,   KEY_READ                =   (   STANDARD_RIGHTS_READ
                                    |   KEY_QUERY_VALUE
                                    |   KEY_ENUMERATE_SUB_KEYS
                                    |   KEY_NOTIFY)
                                &   ~(SYNCHRONIZE) //!< Combines the STANDARD_RIGHTS_READ, KEY_QUERY_VALUE, KEY_ENUMERATE_SUB_KEYS, and KEY_NOTIFY access rights
    ,   KEY_WRITE               =   (   STANDARD_RIGHTS_WRITE
                                    |   KEY_SET_VALUE
                                    |   KEY_CREATE_SUB_KEY)
                                &   ~(SYNCHRONIZE) //!< Combines the STANDARD_RIGHTS_WRITE, KEY_SET_VALUE, and KEY_CREATE_SUB_KEY access rights
    ,   KEY_EXECUTE             =   KEY_READ
                                &   ~(SYNCHRONIZE) //!< Permission for read access
    ,   KEY_ALL_ACCESS          =   (   STANDARD_RIGHTS_ALL
                                    |   KEY_QUERY_VALUE
                                    |   KEY_SET_VALUE
                                    |   KEY_CREATE_SUB_KEY
                                    |   KEY_ENUMERATE_SUB_KEYS
                                    |   KEY_NOTIFY
                                    |   KEY_CREATE_LINK)
                                &   ~(SYNCHRONIZE) //!< Combines the KEY_QUERY_VALUE, KEY_ENUMERATE_SUB_KEYS, KEY_NOTIFY, KEY_CREATE_SUB_KEY, KEY_CREATE_LINK, and KEY_SET_VALUE access rights, plus all the standard access rights except SYNCHRONIZE
}

/// Enumeration of the recognised registry value types
///
/// \ingroup group_synsoft_win32_reg
public enum REG_VALUE_TYPE
{
        REG_UNKNOWN                     =   -1 //!< 
    ,   REG_NONE                        =   0  //!< The null value type. (In practise this is treated as a zero-length binary array by the Win32 registry)
    ,   REG_SZ                          =   1  //!< A zero-terminated string
    ,   REG_EXPAND_SZ                   =   2  //!< A zero-terminated string containing expandable environment variable references
    ,   REG_BINARY                      =   3  //!< A binary blob
    ,   REG_DWORD                       =   4  //!< A 32-bit unsigned integer
    ,   REG_DWORD_LITTLE_ENDIAN         =   4  //!< A 32-bit unsigned integer, stored in little-endian byte order
    ,   REG_DWORD_BIG_ENDIAN            =   5  //!< A 32-bit unsigned integer, stored in big-endian byte order
    ,   REG_LINK                        =   6  //!< A registry link
    ,   REG_MULTI_SZ                    =   7  //!< A set of zero-terminated strings
    ,   REG_RESOURCE_LIST               =   8  //!< A hardware resource list
    ,   REG_FULL_RESOURCE_DESCRIPTOR    =   9  //!< A hardware resource descriptor
    ,   REG_RESOURCE_REQUIREMENTS_LIST  =   10 //!< A hardware resource requirements list
    ,   REG_QWORD                       =   11 //!< A 64-bit unsigned integer
    ,   REG_QWORD_LITTLE_ENDIAN         =   11 //!< A 64-bit unsigned integer, stored in little-endian byte order
}

/* /////////////////////////////////////////////////////////////////////////////
 * External function declarations
 */

extern (C)
{
    int wsprintfA(char *dest, char *fmt, ...);
}

extern (Windows)
{
    LONG    RegCreateKeyExA(in HKEY hkey, in LPCSTR lpSubKey, in Reserved 
                        ,   in Reserved , in DWORD dwOptions
                        ,   in REGSAM samDesired
                        ,   in LPSECURITY_ATTRIBUTES lpsa
                        ,   out HKEY hkeyResult, out DWORD disposition);
    LONG    RegDeleteKeyA(in HKEY hkey, in LPCSTR lpSubKey);
    LONG    RegDeleteValueA(in HKEY hkey, in LPCSTR lpValueName);
    LONG    RegOpenKeyA(in HKEY hkey, in LPCSTR lpSubKey, out HKEY hkeyResult);
    LONG    RegOpenKeyExA(  in HKEY hkey, in LPCSTR lpSubKey, in Reserved 
                        ,   in REGSAM samDesired, out HKEY hkeyResult);
    LONG    RegCloseKey(in HKEY hkey);
    LONG    RegFlushKey(in HKEY hkey);
    LONG    RegQueryValueExA(   in HKEY hkey, in LPCSTR lpValueName, in Reserved 
                            ,   out REG_VALUE_TYPE type, in void *lpData
                            ,   inout DWORD cbData);
    LONG    RegEnumKeyExA(  in HKEY hkey, in DWORD dwIndex, in LPSTR lpName
                        ,   inout DWORD cchName, in Reserved , in LPSTR lpClass
                        ,   in LPDWORD cchClass, in FILETIME *ftLastWriteTime);
    LONG    RegEnumValueA(  in HKEY hkey, in DWORD dwIndex, in LPSTR lpValueName
                        ,   inout DWORD cchValueName, in Reserved 
                        ,   in LPDWORD lpType, in void *lpData
                        ,   in LPDWORD lpcbData);
    LONG    RegQueryInfoKeyA(   in HKEY hkey, in LPSTR lpClass
                            ,   in LPDWORD lpcClass, in Reserved
                            ,   in LPDWORD lpcSubKeys
                            ,   in LPDWORD lpcMaxSubKeyLen
                            ,   in LPDWORD lpcMaxClassLen, in LPDWORD lpcValues
                            ,   in LPDWORD lpcMaxValueNameLen
                            ,   in LPDWORD lpcMaxValueLen
                            ,   in LPDWORD lpcbSecurityDescriptor
                            ,   in FILETIME *lpftLastWriteTime);
    LONG    RegSetValueExA( in HKEY hkey, in LPCSTR lpSubKey, in Reserved 
                        ,   in REG_VALUE_TYPE type, in LPCVOID lpData
                        ,   in DWORD cbData);

    DWORD   ExpandEnvironmentStringsA(in LPCSTR src, in LPSTR dest, in DWORD cchDest);
    int     GetLastError();
}

/* /////////////////////////////////////////////////////////////////////////////
 * Private utility functions
 */

private REG_VALUE_TYPE _RVT_from_Endian(Endian endian)
{
    switch(endian)
    {
        case    Endian.Big:
            return REG_VALUE_TYPE.REG_DWORD_BIG_ENDIAN;
            break;
        case    Endian.Little:
            return REG_VALUE_TYPE.REG_DWORD_LITTLE_ENDIAN;
            break;
        default:
            throw new RegistryException("Invalid Endian specified");
    }
}

private uint swap(in uint i)
{
    version(X86)
    {
        asm
        {    naked;
             bswap EAX ;
             ret ;
        }
    }
    else
    {
        uint    v_swap  =   (i & 0xff) << 24
                        |   (i & 0xff00) << 8
                        |   (i >> 8) & 0xff00
                        |   (i >> 24) & 0xff;

        return v_swap;
    }
}

/+
private char[] expand_environment_strings(in char[] value)
in
{
    assert(null !== value);
}
body
{
    LPCSTR  lpSrc       =   toStringz(value);
    DWORD   cchRequired =   ExpandEnvironmentStringsA(lpSrc, null, 0);
    char[]  newValue    =   new char[cchRequired];

    if(!ExpandEnvironmentStringsA(lpSrc, newValue, newValue.length))
    {
        throw new Win32Exception("Failed to expand environment variables");
    }

    return newValue;
}
+/

/* /////////////////////////////////////////////////////////////////////////////
 * Translation of the raw APIs:
 *
 * - translating char[] to char*
 * - removing the reserved arguments.
 */

private LONG _Reg_CloseKey(in HKEY hkey)
in
{
    assert(null !== hkey);
}
body
{
    /* No need to attempt to close any of the standard hive keys.
     * Although it's documented that calling RegCloseKey() on any of
     * these hive keys is ignored, we'd rather not trust the Win32
     * API.
     */
    if((uint)hkey & 0x80000000)
    {
        switch((uint)hkey)
        {
            case    HKEY_CLASSES_ROOT:
            case    HKEY_CURRENT_USER:
            case    HKEY_LOCAL_MACHINE:
            case    HKEY_USERS:
            case    HKEY_PERFORMANCE_DATA:
            case    HKEY_PERFORMANCE_TEXT:
            case    HKEY_PERFORMANCE_NLSTEXT:
            case    HKEY_CURRENT_CONFIG:
            case    HKEY_DYN_DATA:
                return ERROR_SUCCESS;
            default:
                /* Do nothing */
                break;
        }
    }

    return RegCloseKey(hkey);
}

private LONG _Reg_FlushKey(in HKEY hkey)
in
{
    assert(null !== hkey);
}
body
{
    return RegFlushKey(hkey);
}

private LONG _Reg_CreateKeyExA(     in HKEY hkey, in char[] subKey
                                ,   in DWORD dwOptions, in REGSAM samDesired
                                ,   in LPSECURITY_ATTRIBUTES lpsa
                                ,   out HKEY hkeyResult, out DWORD disposition)
in
{
    assert(null !== hkey);
    assert(null !== subKey);
}
body
{
    return RegCreateKeyExA( hkey, toStringz(subKey), RESERVED, RESERVED
                        ,   dwOptions, samDesired, lpsa, hkeyResult
                        ,   disposition);
}

private LONG _Reg_DeleteKeyA(in HKEY hkey, in char[] subKey)
in
{
    assert(null !== hkey);
    assert(null !== subKey);
}
body
{
    return RegDeleteKeyA(hkey, toStringz(subKey));
}

private LONG _Reg_DeleteValueA(in HKEY hkey, in char[] valueName)
in
{
    assert(null !== hkey);
    assert(null !== valueName);
}
body
{
    return RegDeleteValueA(hkey, toStringz(valueName));
}

private HKEY _Reg_Dup(HKEY hkey)
in
{
    assert(null !== hkey);
}
body
{
    /* Can't duplicate standard keys, but don't need to, so can just return */
    if((uint)hkey & 0x80000000)
    {
        switch((uint)hkey)
        {
            case    HKEY_CLASSES_ROOT:
            case    HKEY_CURRENT_USER:
            case    HKEY_LOCAL_MACHINE:
            case    HKEY_USERS:
            case    HKEY_PERFORMANCE_DATA:
            case    HKEY_PERFORMANCE_TEXT:
            case    HKEY_PERFORMANCE_NLSTEXT:
            case    HKEY_CURRENT_CONFIG:
            case    HKEY_DYN_DATA:
                return hkey;
            default:
                /* Do nothing */
                break;
        }
    }

    HKEY    hkeyDup;
    LONG    lRes = RegOpenKeyA(hkey, null, hkeyDup);

    debug
    {
        if(ERROR_SUCCESS != lRes)
        {
            printf("_Reg_Dup() failed: 0x%08x 0x%08x %d\n", hkey, hkeyDup, lRes);
        }

        assert(ERROR_SUCCESS == lRes);
    }

    return (ERROR_SUCCESS == lRes) ? hkeyDup : null;
}

private LONG _Reg_EnumKeyName(  in HKEY hkey, in DWORD index, inout char [] name
                            ,   out DWORD cchName)
in
{
    assert(null !== hkey);
    assert(null !== name);
    assert(0 < name.length);
}
body
{
    LONG    res;

    // The Registry API lies about the lengths of a very few sub-key lengths
    // so we have to test to see if it whinges about more data, and provide 
    // more if it does.
    for(;;)
    {
        cchName = name.length;

        res = RegEnumKeyExA(hkey, index, name, cchName, RESERVED, null, null, null);

        if(ERROR_MORE_DATA != res)
        {
            break;
        }
        else
        {
            // Now need to increase the size of the buffer and try again
            name.length = 2 * name.length;
        }
    }

    return res;
}


private LONG _Reg_EnumValueName(in HKEY hkey, in DWORD dwIndex, in LPSTR lpName
                            ,   inout DWORD cchName)
in
{
    assert(null !== hkey);
}
body
{
    return RegEnumValueA(hkey, dwIndex, lpName, cchName, RESERVED, null, null, null);
}

private LONG _Reg_GetNumSubKeys(in HKEY hkey, out DWORD cSubKeys
                            ,   out DWORD cchSubKeyMaxLen)
in
{
    assert(null !== hkey);
}
body
{
    return RegQueryInfoKeyA(hkey, null, null, RESERVED, &cSubKeys
                        ,   &cchSubKeyMaxLen, null, null, null, null, null, null);
}

private LONG _Reg_GetNumValues( in HKEY hkey, out DWORD cValues
                            ,   out DWORD cchValueMaxLen)
in
{
    assert(null !== hkey);
}
body
{
    return RegQueryInfoKeyA(hkey, null, null, RESERVED, null, null, null
                        ,   &cValues, &cchValueMaxLen, null, null, null);
}

private LONG _Reg_GetValueType( in HKEY hkey, in char[] name
                            ,   out REG_VALUE_TYPE type)
in
{
    assert(null !== hkey);
}
body
{
    DWORD   cbData  =   0;
    LONG    res     =   RegQueryValueExA(   hkey, toStringz(name), RESERVED, type
                                        ,   (byte*)0, cbData);

    if(ERROR_MORE_DATA == res)
    {
        res = ERROR_SUCCESS;
    }

    return res;
}

private LONG _Reg_OpenKeyExA(   in HKEY hkey, in char[] subKey
                            ,   in REGSAM samDesired, out HKEY hkeyResult)
in
{
    assert(null !== hkey);
    assert(null !== subKey);
}
body
{
    return RegOpenKeyExA(hkey, toStringz(subKey), RESERVED, samDesired, hkeyResult);
}

private void _Reg_QueryValue(   in HKEY hkey, in char[] name, out char[] value
                            ,   out REG_VALUE_TYPE type)
in
{
    assert(null !== hkey);
}
body
{
    union U
    {
        uint    dw;
        ulong   qw;
    };
    U       u;
    void    *data   =   &u.qw;
    DWORD   cbData  =   U.qw.size;
    LONG    res     =   RegQueryValueExA(   hkey, toStringz(name), RESERVED
                                        ,   type, data, cbData);

    if(ERROR_MORE_DATA == res)
    {
        data = new byte[cbData];

        res = RegQueryValueExA( hkey, toStringz(name), RESERVED, type, data
                            ,   cbData);
    }

    if(ERROR_SUCCESS != res)
    {
        throw new RegistryException("Cannot read the requested value", res);
    }
    else
    {
        switch(type)
        {
            default:
            case    REG_VALUE_TYPE.REG_BINARY:
            case    REG_VALUE_TYPE.REG_MULTI_SZ:
                throw new RegistryException("Cannot read the given value as a string");
                break;
            case    REG_VALUE_TYPE.REG_SZ:
            case    REG_VALUE_TYPE.REG_EXPAND_SZ:
                value = string.toString((char*)data);
                break;
version(LittleEndian)
{
            case    REG_VALUE_TYPE.REG_DWORD_LITTLE_ENDIAN:
                value = string.toString(u.dw);
                break;
            case    REG_VALUE_TYPE.REG_DWORD_BIG_ENDIAN:
                value = string.toString(swap(u.dw));
                break;
}
version(BigEndian)
{
            case    REG_VALUE_TYPE.REG_DWORD_LITTLE_ENDIAN:
                value = string.toString(swap(u.dw));
                break;
            case    REG_VALUE_TYPE.REG_DWORD_BIG_ENDIAN:
                value = string.toString(u.dw);
                break;
}
            case    REG_VALUE_TYPE.REG_QWORD_LITTLE_ENDIAN:
                value = string.toString(u.qw);
                break;
        }
    }
}

private void _Reg_QueryValue(   in HKEY hkey, in char[] name, out char[][] value
                            ,   out REG_VALUE_TYPE type)
in
{
    assert(null !== hkey);
}
body
{
    char[]  data    =   new char[256];
    DWORD   cbData  =   data.size;
    LONG    res     =   RegQueryValueExA(   hkey, toStringz(name), RESERVED, type
                                        ,   data, cbData);

    if(ERROR_MORE_DATA == res)
    {
        data.length = cbData;

        res = RegQueryValueExA(hkey, toStringz(name), RESERVED, type, data, cbData);
    }
    else if(ERROR_SUCCESS == res)
    {
        data.length = cbData;
    }

    if(ERROR_SUCCESS != res)
    {
        throw new RegistryException("Cannot read the requested value", res);
    }
    else
    {
        switch(type)
        {
            default:
                throw new RegistryException("Cannot read the given value as a string");
                break;
            case    REG_VALUE_TYPE.REG_MULTI_SZ:
                break;
        }
    }

    // Now need to tokenise it
    value = tokenise(data, (char)0, 1, 0);
}

private void _Reg_QueryValue(   in HKEY hkey, in char[] name, out uint value
                            ,   out REG_VALUE_TYPE type)
in
{
    assert(null !== hkey);
}
body
{
    DWORD   cbData  =   value.size;
    LONG    res     =   RegQueryValueExA(   hkey, toStringz(name), RESERVED, type
                                        ,   &value, cbData);

    if(ERROR_SUCCESS != res)
    {
        throw new RegistryException("Cannot read the requested value", res);
    }
    else
    {
        switch(type)
        {
            default:
                throw new RegistryException("Cannot read the given value as a 32-bit integer");
                break;
version(LittleEndian)
{
            case    REG_VALUE_TYPE.REG_DWORD_LITTLE_ENDIAN:
                assert(REG_VALUE_TYPE.REG_DWORD == REG_VALUE_TYPE.REG_DWORD_LITTLE_ENDIAN);
                break;
            case    REG_VALUE_TYPE.REG_DWORD_BIG_ENDIAN:
} // version(LittleEndian)
version(BigEndian)
{
            case    REG_VALUE_TYPE.REG_DWORD_BIG_ENDIAN:
                assert(REG_VALUE_TYPE.REG_DWORD == REG_VALUE_TYPE.REG_DWORD_BIG_ENDIAN);
                break;
            case    REG_VALUE_TYPE.REG_DWORD_LITTLE_ENDIAN:
} // version(BigEndian)
                value = swap(value);
                break;
        }
    }
}

private void _Reg_QueryValue(   in HKEY hkey, in char[] name, out ulong value
                            ,   out REG_VALUE_TYPE type)
in
{
    assert(null !== hkey);
}
body
{
    DWORD   cbData  =   value.size;
    LONG    res     =   RegQueryValueExA(   hkey, toStringz(name), RESERVED, type
                                        ,   &value, cbData);

    if(ERROR_SUCCESS != res)
    {
        throw new RegistryException("Cannot read the requested value", res);
    }
    else
    {
        switch(type)
        {
            default:
                throw new RegistryException("Cannot read the given value as a 64-bit integer");
                break;
            case    REG_VALUE_TYPE.REG_QWORD_LITTLE_ENDIAN:
                break;
        }
    }
}

private void _Reg_QueryValue(   in HKEY hkey, in char[] name, out byte[] value
                            ,   out REG_VALUE_TYPE type)
in
{
    assert(null !== hkey);
}
body
{
    byte[]  data    =   new byte[100];
    DWORD   cbData  =   data.size;
    LONG    res     =   RegQueryValueExA(   hkey, toStringz(name), RESERVED, type
                                        ,   data, cbData);

    if(ERROR_MORE_DATA == res)
    {
        data.length = cbData;

        res = RegQueryValueExA(hkey, toStringz(name), RESERVED, type, data, cbData);
    }

    if(ERROR_SUCCESS != res)
    {
        throw new RegistryException("Cannot read the requested value", res);
    }
    else
    {
        switch(type)
        {
            default:
                throw new RegistryException("Cannot read the given value as a string");
                break;
            case    REG_VALUE_TYPE.REG_BINARY:
                data.length = cbData;
                value = data;
                break;
        }
    }
}

private void _Reg_SetValueExA(  in HKEY hkey, in char[] subKey
                            ,   in REG_VALUE_TYPE type, in LPCVOID lpData
                            ,   in DWORD cbData)
in
{
    assert(null !== hkey);
}
body
{
    LONG    res =   RegSetValueExA( hkey, toStringz(subKey), RESERVED, type
                                ,   lpData, cbData);

    if(ERROR_SUCCESS != res)
    {
        throw new RegistryException("Value cannot be set: \"" ~ subKey ~ "\"", res);
    }
}

/* /////////////////////////////////////////////////////////////////////////////
 * Classes
 */

////////////////////////////////////////////////////////////////////////////////
// RegistryException

/// Exception class thrown by the synsoft.win32.registry classes
///
/// \ingroup group_synsoft_win32_reg

public class RegistryException
    : Win32Exception
{
/// \name Construction
//@{
public:
    /// \brief Creates an instance of the exception
    ///
    /// \param message The message associated with the exception
    this(char[] message)
    {
        super(message);
    }
    /// \brief Creates an instance of the exception, with the given 
    ///
    /// \param message The message associated with the exception
    /// \param error The Win32 error number associated with the exception
    this(char[] message, int error)
    {
        super(message, error);
    }
//@}
}

unittest
{
    // (i) Test that we can throw and catch one by its own type
    try
    {
        char[]  message =   "Test 1";
        int     code    =   3;
        char[]  string  =   "Test 1 (3)";

        try
        {
            throw new RegistryException(message, code);
        }
        catch(RegistryException x)
        {
            assert(x.Error == code);
            if(string != x.toString())
            {
                printf( "UnitTest failure for RegistryException:\n"
                        "  x.message [%d;\"%.*s\"] does not equal [%d;\"%.*s\"]\n"
                    ,   x.Message.length, x.Message
                    ,   string.length, string);
            }
            assert(message == x.Message);
        }
    }
    catch(Exception /* x */)
    {
        int code_flow_should_never_reach_here = 0;
        assert(code_flow_should_never_reach_here);
    }
}

////////////////////////////////////////////////////////////////////////////////
// Key

/// This class represents a registry key
///
/// \ingroup group_synsoft_win32_reg

public class Key
{
    invariant
    {
        assert(null !== m_hkey);
    }

/// \name Construction
//@{
private:
    this(HKEY hkey, char[] name, boolean created)
    in
    {
        assert(null !== hkey);
    }
    body
    {
        m_hkey      =   hkey;
        m_name      =   name;
        m_created   =   created;
    }

    ~this()
    {
        _Reg_CloseKey(m_hkey);

        // Even though this is horried waste-of-cycles programming
        // we're doing it here so that the 
        m_hkey = null;
    }
//@}

/// \name Attributes
//@{
public:
    /// The name of the key
    char[] Name()
    {
        return m_name;
    }

/*  /// Indicates whether this key was created, rather than opened, by the client
    boolean Created()
    {
        return m_created;
    }
*/

    /// The number of sub keys
    uint KeyCount()
    {
        uint    cSubKeys;
        uint    cchSubKeyMaxLen;
        LONG    res =   _Reg_GetNumSubKeys(m_hkey, cSubKeys, cchSubKeyMaxLen);

        if(ERROR_SUCCESS != res)
        {
            throw new RegistryException("Number of sub-keys cannot be determined", res);
        }

        return cSubKeys;
    }

    /// An enumerable sequence of all the sub-keys of this key
    KeySequence Keys()
    {
        return new KeySequence(this);
    }

    /// An enumerable sequence of the names of all the sub-keys of this key
    KeyNameSequence KeyNames()
    {
        return new KeyNameSequence(this);
    }

    /// The number of values
    uint ValueCount()
    {
        uint    cValues;
        uint    cchValueMaxLen;
        LONG    res =   _Reg_GetNumValues(m_hkey, cValues, cchValueMaxLen);

        if(ERROR_SUCCESS != res)
        {
            throw new RegistryException("Number of values cannot be determined", res);
        }

        return cValues;
    }

    /// An enumerable sequence of all the values of this key
    ValueSequence Values()
    {
        return new ValueSequence(this);
    }

    /// An enumerable sequence of the names of all the values of this key
    ValueNameSequence ValueNames()
    {
        return new ValueNameSequence(this);
    }
//@}

/// \name Methods
//@{
public:
    /// Returns the named sub-key of this key
    ///
    /// \param name The name of the subkey to create. May not be null
    /// \return The created key
    /// \note If the key cannot be created, a RegistryException is thrown.
    Key CreateKey(char[] name, REGSAM access)
    {
        if( null === name ||
            0 == name.length)
        {
            throw new RegistryException("Key name is invalid");
        }
        else
        {
            HKEY    hkey;
            DWORD   disposition;
            LONG    lRes    =   _Reg_CreateKeyExA(  m_hkey, name, 0
                                                ,   REGSAM.KEY_ALL_ACCESS
                                                ,   null, hkey, disposition);

            if(ERROR_SUCCESS != lRes)
            {
                throw new RegistryException("Failed to create requested key: \"" ~ name ~ "\"", lRes);
            }

            assert(null !== hkey);

            // Potential resource leak here!!
            //
            // If the allocation of the memory for Key fails, the HKEY could be
            // lost. Hence, we catch such a failure by the finally, and release
            // the HKEY there. If the creation of 
            try
            {
                Key key =   new Key(hkey, name, disposition == REG_CREATED_NEW_KEY);

                hkey = null;

                return key;
            }
            finally
            {
                if(hkey != null)
                {
                    _Reg_CloseKey(hkey);
                }
            }
        }
    }
    
    /// Returns the named sub-key of this key
    ///
    /// \param name The name of the subkey to create. May not be null
    /// \return The created key
    /// \note If the key cannot be created, a RegistryException is thrown.
    /// \note This function is equivalent to calling CreateKey(name, REGSAM.KEY_ALL_ACCESS), and returns a key with all access
    Key CreateKey(char[] name)
    {
        return CreateKey(name, (REGSAM)REGSAM.KEY_ALL_ACCESS);
    }

    /// Returns the named sub-key of this key
    ///
    /// \param name The name of the subkey to aquire. If name is null (or the empty-string), then the called key is duplicated
    /// \param access The desired access; one of the REGSAM enumeration
    /// \return The aquired key. 
    /// \note This function never returns null. If a key corresponding to the requested name is not found, a RegistryException is thrown
    Key GetKey(char[] name, REGSAM access)
    {
        if( null === name ||
            0 == name.length)
        {
            return new Key(_Reg_Dup(m_hkey), m_name, false);
        }
        else
        {
            HKEY    hkey;
            LONG    lRes    =   _Reg_OpenKeyExA(m_hkey, name, REGSAM.KEY_ALL_ACCESS, hkey);

            if(ERROR_SUCCESS != lRes)
            {
                throw new RegistryException("Failed to open requested key: \"" ~ name ~ "\"", lRes);
            }

            assert(null !== hkey);

            // Potential resource leak here!!
            //
            // If the allocation of the memory for Key fails, the HKEY could be
            // lost. Hence, we catch such a failure by the finally, and release
            // the HKEY there. If the creation of 
            try
            {
                Key key =   new Key(hkey, name, false);

                hkey = null;

                return key;
            }
            finally
            {
                if(hkey != null)
                {
                    _Reg_CloseKey(hkey);
                }
            }
        }
    }

    /// Returns the named sub-key of this key
    ///
    /// \param name The name of the subkey to aquire. If name is null (or the empty-string), then the called key is duplicated
    /// \return The aquired key. 
    /// \note This function never returns null. If a key corresponding to the requested name is not found, a RegistryException is thrown
    /// \note This function is equivalent to calling GetKey(name, REGSAM.KEY_READ), and returns a key with read/enum access
    Key GetKey(char[] name)
    {
        return GetKey(name, (REGSAM)(REGSAM.KEY_READ));
    }

    /// Deletes the named key
    ///
    /// \param name The name of the key to delete. May not be null
    void DeleteKey(char[] name)
    {
        if( null === name ||
            0 == name.length)
        {
            throw new RegistryException("Key name is invalid");
        }
        else
        {
            LONG    res =   _Reg_DeleteKeyA(m_hkey, name);

            if(ERROR_SUCCESS != res)
            {
                throw new RegistryException("Value cannot be deleted: \"" ~ name ~ "\"", res);
            }
        }
    }

    /// Returns the named value
    ///
    /// \note if name is null (or the empty-string), then the default value is returned
    /// \return This function never returns null. If a value corresponding to the requested name is not found, a RegistryException is thrown
    Value GetValue(char[] name)
    {
        REG_VALUE_TYPE  type;
        LONG            res =   _Reg_GetValueType(m_hkey, name, type);

        if(ERROR_SUCCESS == res)
        {
            return new Value(this, name, type);
        }
        else
        {
            throw new RegistryException("Value cannot be opened: \"" ~ name ~ "\"", res);
        }
    }

    /// Sets the named value with the given 32-bit unsigned integer value
    ///
    /// \param name The name of the value to set. If null, or the empty string, sets the default value
    /// \param value The 32-bit unsigned value to set
    /// \note If a value corresponding to the requested name is not found, a RegistryException is thrown
    void SetValue(char[] name, uint value)
    {
        SetValue(name, value, Endian.Ambient);
    }

    /// Sets the named value with the given 32-bit unsigned integer value, according to the desired byte-ordering
    ///
    /// \param name The name of the value to set. If null, or the empty string, sets the default value
    /// \param value The 32-bit unsigned value to set
    /// \param endian Can be Endian.Big or Endian.Little
    /// \note If a value corresponding to the requested name is not found, a RegistryException is thrown
    void SetValue(char[] name, uint value, Endian endian)
    {
        REG_VALUE_TYPE  type    =   _RVT_from_Endian(endian);

        assert( type == REG_VALUE_TYPE.REG_DWORD_BIG_ENDIAN || 
                type == REG_VALUE_TYPE.REG_DWORD_LITTLE_ENDIAN);

        _Reg_SetValueExA(m_hkey, name, type, &value, value.size);
    }

    /// Sets the named value with the given 64-bit unsigned integer value
    ///
    /// \param name The name of the value to set. If null, or the empty string, sets the default value
    /// \param value The 64-bit unsigned value to set
    /// \note If a value corresponding to the requested name is not found, a RegistryException is thrown
    void SetValue(char[] name, ulong value)
    {
        _Reg_SetValueExA(m_hkey, name, REG_VALUE_TYPE.REG_QWORD, &value, value.size);
    }

    /// Sets the named value with the given string value
    ///
    /// \param name The name of the value to set. If null, or the empty string, sets the default value
    /// \param value The string value to set
    /// \note If a value corresponding to the requested name is not found, a RegistryException is thrown
    void SetValue(char[] name, char[] value)
    {
        SetValue(name, value, false);
    }

    /// Sets the named value with the given string value
    ///
    /// \param name The name of the value to set. If null, or the empty string, sets the default value
    /// \param value The string value to set
    /// \param asEXPAND_SZ If true, the value will be stored as an expandable environment string, otherwise as a normal string
    /// \note If a value corresponding to the requested name is not found, a RegistryException is thrown
    void SetValue(char[] name, char[] value, boolean asEXPAND_SZ)
    {
        _Reg_SetValueExA(m_hkey, name, asEXPAND_SZ 
                                            ? REG_VALUE_TYPE.REG_EXPAND_SZ
                                            : REG_VALUE_TYPE.REG_SZ, value
                        , value.length);
    }

    /// Sets the named value with the given multiple-strings value
    ///
    /// \param name The name of the value to set. If null, or the empty string, sets the default value
    /// \param value The multiple-strings value to set
    /// \note If a value corresponding to the requested name is not found, a RegistryException is thrown
    void SetValue(char[] name, char[][] value)
    {
        int total = 2;

        // Work out the length

        foreach(char[] s; value)
        {
            total += 1 + s.length;
        }

        // Allocate

        char[]  cs      =   new char[total];
        int     base    =   0;

        // Slice the individual strings into the new array

        foreach(char[] s; value)
        {
            int top = base + s.length;

            cs[base .. top] = s;
            cs[top] = 0;

            base = 1 + top;
        }

        _Reg_SetValueExA(m_hkey, name, REG_VALUE_TYPE.REG_MULTI_SZ, cs, cs.length);
    }

    /// Sets the named value with the given binary value
    ///
    /// \param name The name of the value to set. If null, or the empty string, sets the default value
    /// \param value The binary value to set
    /// \note If a value corresponding to the requested name is not found, a RegistryException is thrown
    void SetValue(char[] name, byte[] value)
    {
        _Reg_SetValueExA(m_hkey, name, REG_VALUE_TYPE.REG_BINARY, value, value.length);
    }

    /// Deletes the named value
    ///
    /// \param name The name of the value to delete. May not be null
    /// \note If a value of the requested name is not found, a RegistryException is thrown
    void DeleteValue(char[] name)
    {
        LONG    res =   _Reg_DeleteValueA(m_hkey, name);

        if(ERROR_SUCCESS != res)
        {
            throw new RegistryException("Value cannot be deleted: \"" ~ name ~ "\"", res);
        }
    }

    /// Flushes any changes to the key to disk
    ///
    void Flush()
    {
        LONG    res =   _Reg_FlushKey(m_hkey);

        if(ERROR_SUCCESS != res)
        {
            throw new RegistryException("Key cannot be flushed", res);
        }
    }
//@}

/// \name Members
//@{
private:
    HKEY    m_hkey;
    char[]  m_name;
    boolean m_created;
//@}
}

////////////////////////////////////////////////////////////////////////////////
// Value

/// This class represents a value of a registry key
///
/// \ingroup group_synsoft_win32_reg

public class Value
{
    invariant
    {
        assert(null !== m_key);
    }

private:
    this(Key key, char[] name, REG_VALUE_TYPE type)
    in
    {
        assert(key !== null);
    }
    body
    {
        m_key   =   key;
        m_type  =   type;
        m_name  =   name;
    }

/// \name Attributes
//@{
public:
    /// The name of the value.
    ///
    /// \note If the value represents a default value of a key, which has no name, the returned string will be of zero length
    char[] Name()
    {
        return m_name;
    }

    /// The type of value
    REG_VALUE_TYPE Type()
    {
        return m_type;
    }

    /// Obtains the current value of the value as a string.
    ///
    /// \return The contents of the value
    /// \note If the value's type is REG_EXPAND_SZ the returned value is <b>not</b> expanded; Value_EXPAND_SZ() should be called
    /// \note Throws a RegistryException if the type of the value is not REG_SZ, REG_EXPAND_SZ, REG_DWORD(_*) or REG_QWORD(_*):
    char[] Value_SZ()
    {
        REG_VALUE_TYPE  type;
        char[]          value;

        _Reg_QueryValue(m_key.m_hkey, m_name, value, type);

        if(type != m_type)
        {
            throw new RegistryException("Value type has been changed since the value was acquired");
        }

        return value;
    }

    /// Obtains the current value as a string, within which any environment variables have undergone expansion
    ///
    /// \return The contents of the value
    /// \note This function works with the same value-types as Value_SZ().
    char[] Value_EXPAND_SZ()
    {
        char[]  value   =   Value_SZ;

/+
        value = expand_environment_strings(value);

        return value;
 +/

        LPCSTR  lpSrc       =   toStringz(value);
        DWORD   cchRequired =   ExpandEnvironmentStringsA(lpSrc, null, 0);
        char[]  newValue    =   new char[cchRequired];

        if(!ExpandEnvironmentStringsA(lpSrc, newValue, newValue.length))
        {
            throw new Win32Exception("Failed to expand environment variables");
        }

        return newValue;
    }

    /// Obtains the current value as an array of strings
    ///
    /// \return The contents of the value
    /// \note Throws a RegistryException if the type of the value is not REG_MULTI_SZ
    char[][] Value_MULTI_SZ()
    {
        REG_VALUE_TYPE  type;
        char[][]        value;

        _Reg_QueryValue(m_key.m_hkey, m_name, value, type);

        if(type != m_type)
        {
            throw new RegistryException("Value type has been changed since the value was acquired");
        }

        return value;
    }

    /// Obtains the current value as a 32-bit unsigned integer, ordered correctly according to the current architecture
    ///
    /// \return The contents of the value
    /// \note An exception is thrown for all types other than REG_DWORD, REG_DWORD_LITTLE_ENDIAN and REG_DWORD_BIG_ENDIAN.
    uint Value_DWORD()
    {
        REG_VALUE_TYPE  type;
        uint            value;

        _Reg_QueryValue(m_key.m_hkey, m_name, value, type);

        if(type != m_type)
        {
            throw new RegistryException("Value type has been changed since the value was acquired");
        }

        return value;
    }

    deprecated uint Value_DWORD_LITTLEENDIAN()
    {
        return Value_DWORD();
    }

    deprecated uint Value_DWORD_BIGENDIAN()
    {
        return Value_DWORD();
    }

    /// Obtains the value as a 64-bit unsigned integer, ordered correctly according to the current architecture
    ///
    /// \return The contents of the value
    /// \note Throws a RegistryException if the type of the value is not REG_QWORD
    ulong Value_QWORD()
    {
        REG_VALUE_TYPE  type;
        ulong           value;

        _Reg_QueryValue(m_key.m_hkey, m_name, value, type);

        if(type != m_type)
        {
            throw new RegistryException("Value type has been changed since the value was acquired");
        }

        return value;
    }

    deprecated ulong Value_QWORD_LITTLEENDIAN()
    {
        return Value_QWORD();
    }

    /// Obtains the value as a binary blob
    ///
    /// \return The contents of the value
    /// \note Throws a RegistryException if the type of the value is not REG_BINARY
    byte[]  Value_BINARY()
    {
        REG_VALUE_TYPE  type;
        byte[]          value;

        _Reg_QueryValue(m_key.m_hkey, m_name, value, type);

        if(type != m_type)
        {
            throw new RegistryException("Value type has been changed since the value was acquired");
        }

        return value;
    }
//@}

/// \name Members
//@{
private:
    Key             m_key;
    REG_VALUE_TYPE  m_type;
    char[]          m_name;
//@}
}

////////////////////////////////////////////////////////////////////////////////
// Registry

/// Represents the local system registry.
///
/// \ingroup group_synsoft_win32_reg

public class Registry
{
private:
    static this()
    {
        sm_keyClassesRoot       = new Key(  _Reg_Dup(HKEY_CLASSES_ROOT)
                                        ,   "HKEY_CLASSES_ROOT", false);
        sm_keyCurrentUser       = new Key(  _Reg_Dup(HKEY_CURRENT_USER)
                                        ,   "HKEY_CURRENT_USER", false);
        sm_keyLocalMachine      = new Key(  _Reg_Dup(HKEY_LOCAL_MACHINE)
                                        ,   "HKEY_LOCAL_MACHINE", false);
        sm_keyUsers             = new Key(  _Reg_Dup(HKEY_USERS)
                                        ,   "HKEY_USERS", false);
        sm_keyPerformanceData   = new Key(  _Reg_Dup(HKEY_PERFORMANCE_DATA)
                                        ,   "HKEY_PERFORMANCE_DATA", false);
        sm_keyCurrentConfig     = new Key(  _Reg_Dup(HKEY_CURRENT_CONFIG)
                                        ,   "HKEY_CURRENT_CONFIG", false);
        sm_keyDynData           = new Key(  _Reg_Dup(HKEY_DYN_DATA)
                                        ,   "HKEY_DYN_DATA", false);
    }

private:
    this();

/// \name Hives
//@{
public:
    /// Returns the root key for the HKEY_CLASSES_ROOT hive
    static Key  ClassesRoot()       {   return sm_keyClassesRoot;       }
    /// Returns the root key for the HKEY_CURRENT_USER hive
    static Key  CurrentUser()       {   return sm_keyCurrentUser;       }
    /// Returns the root key for the HKEY_LOCAL_MACHINE hive
    static Key  LocalMachine()      {   return sm_keyLocalMachine;      }
    /// Returns the root key for the HKEY_USERS hive
    static Key  Users()             {   return sm_keyUsers;             }
    /// Returns the root key for the HKEY_PERFORMANCE_DATA hive
    static Key  PerformanceData()   {   return sm_keyPerformanceData;   }
    /// Returns the root key for the HKEY_CURRENT_CONFIG hive
    static Key  CurrentConfig()     {   return sm_keyCurrentConfig;     }
    /// Returns the root key for the HKEY_DYN_DATA hive
    static Key  DynData()           {   return sm_keyDynData;           }
//@}

private:
    static Key  sm_keyClassesRoot;
    static Key  sm_keyCurrentUser;
    static Key  sm_keyLocalMachine;
    static Key  sm_keyUsers;
    static Key  sm_keyPerformanceData;
    static Key  sm_keyCurrentConfig;
    static Key  sm_keyDynData;
}

////////////////////////////////////////////////////////////////////////////////
// KeyNameSequence

/// An enumerable sequence representing the names of the sub-keys of a registry Key
///
/// It would be used as follows:
///
/// <code>&nbsp;&nbsp;Key&nbsp;key&nbsp;=&nbsp;. . .</code>
/// <br>
/// <code></code>
/// <br>
/// <code>&nbsp;&nbsp;foreach(char[] kName; key.SubKeys)</code>
/// <br>
/// <code>&nbsp;&nbsp;{</code>
/// <br>
/// <code>&nbsp;&nbsp;&nbsp;&nbsp;process_Key(kName);</code>
/// <br>
/// <code>&nbsp;&nbsp;}</code>
/// <br>
/// <br>
///
/// \ingroup group_synsoft_win32_reg

public class KeyNameSequence
{
    invariant
    {
        assert(null !== m_key);
    }

/// Construction
private:
    this(Key key)
    {
        m_key = key;
    }

/// \name Attributes
///@{
public:
    /// The number of keys
    uint Count()
    {
        return m_key.KeyCount();
    }

    /// The name of the key at the given index
    ///
    /// \param index The 0-based index of the key to retrieve
    /// \return The name of the key corresponding to the given index
    /// \note Throws a RegistryException if no corresponding key is retrieved
    char[] GetKeyName(uint index)
    {
        DWORD   cSubKeys;
        DWORD   cchSubKeyMaxLen;
        HKEY    hkey    =   m_key.m_hkey;
        LONG    res     =   _Reg_GetNumSubKeys(hkey, cSubKeys, cchSubKeyMaxLen);
        char[]  sName   =   new char[1 + cchSubKeyMaxLen];
        DWORD   cchName;

        assert(ERROR_SUCCESS == res);

        res = _Reg_EnumKeyName(hkey, index, sName, cchName);

        assert(ERROR_MORE_DATA != res);

        if(ERROR_SUCCESS != res)
        {
            throw new RegistryException("Invalid key", res);
        }

        return sName[0 .. cchName];
    }

    /// The name of the key at the given index
    ///
    /// \param index The 0-based index of the key to retrieve
    /// \return The name of the key corresponding to the given index
    /// \note Throws a RegistryException if no corresponding key is retrieved
    char[] opIndex(uint index)
    {
        return GetKeyName(index);
    }
///@}

public:
    int apply(int delegate(inout char[] name) dg)
    {
        int     result  =   0;
        HKEY    hkey    =   m_key.m_hkey;
        DWORD   cSubKeys;
        DWORD   cchSubKeyMaxLen;
        LONG    res     =   _Reg_GetNumSubKeys(hkey, cSubKeys, cchSubKeyMaxLen);
        char[]  sName   =   new char[1 + cchSubKeyMaxLen];

        assert(ERROR_SUCCESS == res);

        for(DWORD index = 0; 0 == result; ++index)
        {
            DWORD   cchName;
            LONG    res =   _Reg_EnumKeyName(hkey, index, sName, cchName);

            assert(ERROR_MORE_DATA != res);

            if(ERROR_NO_MORE_ITEMS == res)
            {
                // Enumeration complete

                break;
            }
            else if(ERROR_SUCCESS == res)
            {
                char[] name = sName[0 .. cchName];

                result = dg(name);
            }
            else
            {
                throw new RegistryException("Key name enumeration incomplete", res);

                break;
            }
        }

        return result;
    }

/// Members
private:
    Key m_key;
}


////////////////////////////////////////////////////////////////////////////////
// KeySequence

/// An enumerable sequence representing the sub-keys of a registry Key
///
/// It would be used as follows:
///
/// <code>&nbsp;&nbsp;Key&nbsp;key&nbsp;=&nbsp;. . .</code>
/// <br>
/// <code></code>
/// <br>
/// <code>&nbsp;&nbsp;foreach(Key k; key.SubKeys)</code>
/// <br>
/// <code>&nbsp;&nbsp;{</code>
/// <br>
/// <code>&nbsp;&nbsp;&nbsp;&nbsp;process_Key(k);</code>
/// <br>
/// <code>&nbsp;&nbsp;}</code>
/// <br>
/// <br>
///
/// \ingroup group_synsoft_win32_reg

public class KeySequence
{
    invariant
    {
        assert(null !== m_key);
    }

/// Construction
private:
    this(Key key)
    {
        m_key = key;
    }

/// \name Attributes
///@{
public:
    /// The number of keys
    uint Count()
    {
        return m_key.KeyCount();
    }

    /// The key at the given index
    ///
    /// \param index The 0-based index of the key to retrieve
    /// \return The key corresponding to the given index
    /// \note Throws a RegistryException if no corresponding key is retrieved
    Key GetKey(uint index)
    {
        DWORD   cSubKeys;
        DWORD   cchSubKeyMaxLen;
        HKEY    hkey    =   m_key.m_hkey;
        LONG    res     =   _Reg_GetNumSubKeys(hkey, cSubKeys, cchSubKeyMaxLen);
        char[]  sName   =   new char[1 + cchSubKeyMaxLen];
        DWORD   cchName;

        assert(ERROR_SUCCESS == res);

        res =   _Reg_EnumKeyName(hkey, index, sName, cchName);

        assert(ERROR_MORE_DATA != res);

        if(ERROR_SUCCESS != res)
        {
            throw new RegistryException("Invalid key", res);
        }

        return m_key.GetKey(sName[0 .. cchName]);
    }

    /// The key at the given index
    ///
    /// \param index The 0-based index of the key to retrieve
    /// \return The key corresponding to the given index
    /// \note Throws a RegistryException if no corresponding key is retrieved
    Key opIndex(uint index)
    {
        return GetKey(index);
    }
///@}

public:
    int apply(int delegate(inout Key key) dg)
    {
        int         result  =   0;
        HKEY        hkey    =   m_key.m_hkey;
        DWORD       cSubKeys;
        DWORD       cchSubKeyMaxLen;
        LONG        res     =   _Reg_GetNumSubKeys(hkey, cSubKeys, cchSubKeyMaxLen);
        char[]      sName   =   new char[1 + cchSubKeyMaxLen];

        assert(ERROR_SUCCESS == res);

        for(DWORD index = 0; 0 == result; ++index)
        {
            DWORD   cchName;
            LONG    res     =   _Reg_EnumKeyName(hkey, index, sName, cchName);

            assert(ERROR_MORE_DATA != res);

            if(ERROR_NO_MORE_ITEMS == res)
            {
                // Enumeration complete

                break;
            }
            else if(ERROR_SUCCESS == res)
            {
                try
                {
                    Key key =   m_key.GetKey(sName[0 .. cchName]);

                    result = dg(key);
                }
                catch(RegistryException x)
                {
                    // Skip inaccessible keys; they are
                    // accessible via the KeyNameSequence
                    if(x.Error == ERROR_ACCESS_DENIED)
                    {
                        continue;
                    }

                    throw x;
                }
            }
            else
            {
                throw new RegistryException("Key enumeration incomplete", res);

                break;
            }
        }

        return result;
    }

/// Members
private:
    Key m_key;
}

////////////////////////////////////////////////////////////////////////////////
// ValueNameSequence

/// An enumerable sequence representing the names of the values of a registry Key
///
/// It would be used as follows:
///
/// <code>&nbsp;&nbsp;Key&nbsp;key&nbsp;=&nbsp;. . .</code>
/// <br>
/// <code></code>
/// <br>
/// <code>&nbsp;&nbsp;foreach(char[] vName; key.Values)</code>
/// <br>
/// <code>&nbsp;&nbsp;{</code>
/// <br>
/// <code>&nbsp;&nbsp;&nbsp;&nbsp;process_Value(vName);</code>
/// <br>
/// <code>&nbsp;&nbsp;}</code>
/// <br>
/// <br>
///
/// \ingroup group_synsoft_win32_reg

public class ValueNameSequence
{
    invariant
    {
        assert(null !== m_key);
    }

/// Construction
private:
    this(Key key)
    {
        m_key = key;
    }

/// \name Attributes
///@{
public:
    /// The number of values
    uint Count()
    {
        return m_key.ValueCount();
    }

    /// The name of the value at the given index
    ///
    /// \param index The 0-based index of the value to retrieve
    /// \return The name of the value corresponding to the given index
    /// \note Throws a RegistryException if no corresponding value is retrieved
    char[] GetValueName(uint index)
    {
        DWORD   cValues;
        DWORD   cchValueMaxLen;
        HKEY    hkey    =   m_key.m_hkey;
        LONG    res     =   _Reg_GetNumValues(hkey, cValues, cchValueMaxLen);
        char[]  sName   =   new char[1 + cchValueMaxLen];
        DWORD   cchName =   1 + cchValueMaxLen;

        assert(ERROR_SUCCESS == res);

        res     =   _Reg_EnumValueName(hkey, index, sName, cchName);

        if(ERROR_SUCCESS != res)
        {
            throw new RegistryException("Invalid value", res);
        }

        return sName[0 .. cchName];
    }

    /// The name of the value at the given index
    ///
    /// \param index The 0-based index of the value to retrieve
    /// \return The name of the value corresponding to the given index
    /// \note Throws a RegistryException if no corresponding value is retrieved
    char[] opIndex(uint index)
    {
        return GetValueName(index);
    }
///@}

public:
    int apply(int delegate(inout char[] name) dg)
    {
        int     result  =   0;
        HKEY    hkey    =   m_key.m_hkey;
        DWORD   cValues;
        DWORD   cchValueMaxLen;
        LONG    res     =   _Reg_GetNumValues(hkey, cValues, cchValueMaxLen);
        char[]  sName   =   new char[1 + cchValueMaxLen];

        assert(ERROR_SUCCESS == res);

        for(DWORD index = 0; 0 == result; ++index)
        {
            DWORD   cchName =   1 + cchValueMaxLen;
            LONG    res     =   _Reg_EnumValueName(hkey, index, sName, cchName);

            if(ERROR_NO_MORE_ITEMS == res)
            {
                // Enumeration complete
                break;
            }
            else if(ERROR_SUCCESS == res)
            {
                char[]  name = sName[0 .. cchName];

                result = dg(name);
            }
            else
            {
                throw new RegistryException("Value name enumeration incomplete", res);

                break;
            }
        }

        return result;
    }

/// Members
private:
    Key m_key;
}

////////////////////////////////////////////////////////////////////////////////
// ValueSequence

/// An enumerable sequence representing the values of a registry Key
///
/// It would be used as follows:
///
/// <code>&nbsp;&nbsp;Key&nbsp;key&nbsp;=&nbsp;. . .</code>
/// <br>
/// <code></code>
/// <br>
/// <code>&nbsp;&nbsp;foreach(Value v; key.Values)</code>
/// <br>
/// <code>&nbsp;&nbsp;{</code>
/// <br>
/// <code>&nbsp;&nbsp;&nbsp;&nbsp;process_Value(v);</code>
/// <br>
/// <code>&nbsp;&nbsp;}</code>
/// <br>
/// <br>
///
/// \ingroup group_synsoft_win32_reg

public class ValueSequence
{
    invariant
    {
        assert(null !== m_key);
    }

/// Construction
private:
    this(Key key)
    {
        m_key = key;
    }

/// \name Attributes
///@{
public:
    /// The number of values
    uint Count()
    {
        return m_key.ValueCount();
    }

    /// The value at the given index
    ///
    /// \param index The 0-based index of the value to retrieve
    /// \return The value corresponding to the given index
    /// \note Throws a RegistryException if no corresponding value is retrieved
    Value GetValue(uint index)
    {
        DWORD   cValues;
        DWORD   cchValueMaxLen;
        HKEY    hkey    =   m_key.m_hkey;
        LONG    res     =   _Reg_GetNumValues(hkey, cValues, cchValueMaxLen);
        char[]  sName   =   new char[1 + cchValueMaxLen];
        DWORD   cchName =   1 + cchValueMaxLen;

        assert(ERROR_SUCCESS == res);

        res     =   _Reg_EnumValueName(hkey, index, sName, cchName);

        if(ERROR_SUCCESS != res)
        {
            throw new RegistryException("Invalid value", res);
        }

        return m_key.GetValue(sName[0 .. cchName]);
    }

    /// The value at the given index
    ///
    /// \param index The 0-based index of the value to retrieve
    /// \return The value corresponding to the given index
    /// \note Throws a RegistryException if no corresponding value is retrieved
    Value opIndex(uint index)
    {
        return GetValue(index);
    }
///@}

public:
    int apply(int delegate(inout Value value) dg)
    {
        int     result  =   0;
        HKEY    hkey    =   m_key.m_hkey;
        DWORD   cValues;
        DWORD   cchValueMaxLen;
        LONG    res     =   _Reg_GetNumValues(hkey, cValues, cchValueMaxLen);
        char[]  sName   =   new char[1 + cchValueMaxLen];

        assert(ERROR_SUCCESS == res);

        for(DWORD index = 0; 0 == result; ++index)
        {
            DWORD   cchName =   1 + cchValueMaxLen;
            LONG    res     =   _Reg_EnumValueName(hkey, index, sName, cchName);

            if(ERROR_NO_MORE_ITEMS == res)
            {
                // Enumeration complete
                break;
            }
            else if(ERROR_SUCCESS == res)
            {
                Value   value   =   m_key.GetValue(sName[0 .. cchName]);

                result = dg(value);
            }
            else
            {
                throw new RegistryException("Value enumeration incomplete", res);

                break;
            }
        }

        return result;
    }

/// Members
private:
    Key m_key;
}

/* ////////////////////////////////////////////////////////////////////////// */

unittest
{

}

/* ////////////////////////////////////////////////////////////////////////// */
