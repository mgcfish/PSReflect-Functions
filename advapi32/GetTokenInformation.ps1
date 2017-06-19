﻿function GetTokenInformation
{
    <#
    .SYNOPSIS

    The GetTokenInformation function retrieves a specified type of information about an access token. The calling process must have appropriate access rights to obtain the information.
    
    To determine if a user is a member of a specific group, use the CheckTokenMembership function. To determine group membership for app container tokens, use the CheckTokenMembershipEx function.

    .PARAMETER TokenHandle

    A handle to an access token from which information is retrieved. If TokenInformationClass specifies TokenSource, the handle must have TOKEN_QUERY_SOURCE access. For all other TokenInformationClass values, the handle must have TOKEN_QUERY access.

    .PARAMETER TokenInformationClass

    Specifies a value from the TOKEN_INFORMATION_CLASS enumerated type to identify the type of information the function retrieves. Any callers who check the TokenIsAppContainer and have it return 0 should also verify that the caller token is not an identify level impersonation token. If the current token is not an app container but is an identity level token, you should return AccessDenied.

    .NOTES

    Author: Jared Atkinson (@jaredcatkinson)
    License: BSD 3-Clause
    Required Module Dependencies: PSReflect
    Required Function Dependencies: ConvertSidToStringSid
    Required Structure Dependencies: TOKEN_USER, SID_AND_ATTRIBUTES, TOKEN_PRIVILEGES, TOKEN_OWNER, TOKEN_SOURCE, TOKEN_TYPE, SECURITY_IMPERSONATION_LEVEL, LUID, TOKEN_MANDATORY_LABEL
    Required Enumeration Dependencies: LuidAttributes
    Optional Dependencies: TokenInformationClass (Enum)

    (func advapi32 GetTokenInformation ([bool]) @(
        [IntPtr],                #_In_      HANDLE                  TokenHandle
        [Int32],                 #_In_      TOKEN_INFORMATION_CLASS TokenInformationClass
        [IntPtr],                #_Out_opt_ LPVOID                  TokenInformation
        [UInt32],                #_In_      DWORD                   TokenInformationLength
        [UInt32].MakeByRefType() #_Out_     PDWORD                  ReturnLength
    ) -EntryPoint GetTokenInformation -SetLastError)
        
    .LINK

    https://msdn.microsoft.com/en-us/library/windows/desktop/aa446671(v=vs.85).aspx

    .EXAMPLE
    #>

    param
    (
        [Parameter(Mandatory = $true)]
        [IntPtr]
        $TokenHandle,
        
        [Parameter(Mandatory = $true)]
        [ValidateSet('TokenUser','TokenGroups','TokenPrivileges','TokenOwner','TokenPrimaryGroup','TokenDefaultDacl','TokenSource','TokenType','TokenImpersonationLevel','TokenStatistics','TokenRestrictedSids','TokenSessionId','TokenGroupsAndPrivileges','TokenSandBoxInert','TokenOrigin','TokenElevationType','TokenLinkedToken','TokenElevation','TokenHasRestrictions','TokenAccessInformation','TokenVirtualizationAllowed','TokenVirtualizationEnabled','TokenIntegrityLevel','TokenUIAccess','TokenMandatoryPolicy','TokenLogonSid','TokenIsAppContainer','TokenCapabilities','TokenAppContainerSid','TokenAppContainerNumber','TokenUserClaimAttributes','TokenDeviceClaimAttributes','TokenDeviceGroups','TokenRestrictedDeviceGroups')]
        [string]
        $TokenInformationClass
    )
    
    # initial query to determine the necessary buffer size
    $TokenPtrSize = 0
    $Success = $Advapi32::GetTokenInformation($TokenHandle, $TOKEN_INFORMATION_CLASS::$TokenInformationClass, 0, $TokenPtrSize, [ref]$TokenPtrSize)
    [IntPtr]$TokenPtr = [System.Runtime.InteropServices.Marshal]::AllocHGlobal($TokenPtrSize)

    # retrieve the proper buffer value
    $Success = $Advapi32::GetTokenInformation($TokenHandle, $TOKEN_INFORMATION_CLASS::$TokenInformationClass, $TokenPtr, $TokenPtrSize, [ref]$TokenPtrSize); $LastError = [Runtime.InteropServices.Marshal]::GetLastWin32Error()
    
    if($Success)
    {
        switch($TokenInformationClass)
        {
            TokenUser
            {
                <#
                The buffer receives a TOKEN_USER structure that contains the user account of the token.
                    ConvertSidToStringSid (Function)
                    TOKEN_USER (Structure)
                    SID_AND_ATTRIBUTES (Structure)
                #>
                $TokenUser = $TokenPtr -as $TOKEN_USER
                ConvertSidToStringSid -SidPointer $TokenUser.User.Sid
            }
            TokenGroups
            {
                <#
                The buffer receives a TOKEN_GROUPS structure that contains the group accounts associated with the token.
                    TOKEN_GROUP (Structure)
                    SID_AND_ATTRIBUTES (Structure)
                #>
                Write-Output $TokenPtr
            }
            TokenPrivileges
            {
                <#
                The buffer receives a TOKEN_PRIVILEGES structure that contains the privileges of the token.
                    TOKEN_PRIVILEGES (Structure)
                    LUID_AND_ATTRIBUTES (Structure)
                    LuidAttributes (Enumeration)
                #>
                $TokenPrivileges = $TokenPtr -as $TOKEN_PRIVILEGES
                $sb = New-Object System.Text.StringBuilder

                for($i=0; $i -lt $TokenPrivileges.PrivilegeCount; $i++) 
                {
                    if((($TokenPrivileges.Privileges[$i].Attributes -as $LuidAttributes) -band $LuidAttributes::SE_PRIVILEGE_ENABLED) -eq $LuidAttributes::SE_PRIVILEGE_ENABLED)
                    {
                        $sb.Append(", $($TokenPrivileges.Privileges[$i].Luid.LowPart.ToString())") | Out-Null  
                    }
                }

                Write-Output $sb.ToString().TrimStart(', ')
            }
            TokenOwner
            {
                <#
                The buffer receives a TOKEN_OWNER structure that contains the default owner security identifier (SID) for newly created objects.
                    ConvertSidToStringSid (Function)
                    TOKEN_OWNER (Structure)
                #>
                $TokenOwner = $TokenPtr -as $TOKEN_OWNER
    
                if($TokenOwner.Owner -ne $null)
                {
                    Write-Output (ConvertSidToStringSid -SidPointer $TokenOwner.Owner)
                }
                else
                {
                    Write-Output $null
                }
            }
            TokenPrimaryGroup
            {
                <#
                The buffer receives a TOKEN_PRIMARY_GROUP structure that contains the default primary group SID for newly created objects.
                    TOKEN_PRIMARY_GROUP (Structure)
                #>

                Write-Output $TokenPtr
            }
            TokenDefaultDacl
            {
                <#
                The buffer receives a TOKEN_DEFAULT_DACL structure that contains the default DACL for newly created objects.
                    TOKEN_DEFAULT_DACL (Structure)
                #>
                Write-Output $TokenPtr
            }
            TokenSource
            {
                <#
                The buffer receives a TOKEN_SOURCE structure that contains the source of the token. TOKEN_QUERY_SOURCE access is needed to retrieve this information.
                    TOKEN_SOURCE (Structure)
                    LUID (Structure)
                #>
                $TokenSource = $TokenPtr -as $TOKEN_SOURCE
                Write-Output ($TokenSource.SourceName -join "")
            }
            TokenType
            {
                <#
                The buffer receives a TOKEN_TYPE value that indicates whether the token is a primary or impersonation token.
                    TOKEN_TYPE (Enumeration)
                #>
                if($TokenPtr -ne $null)
                {
                    Write-Output ([System.Runtime.InteropServices.Marshal]::ReadInt32($TokenPtr) -as $TOKEN_TYPE)
                }
            }
            TokenImpersonationLevel
            {
                <#
                The buffer receives a SECURITY_IMPERSONATION_LEVEL value that indicates the impersonation level of the token. If the access token is not an impersonation token, the function fails.
                    SECURITY_IMPERSONATION_LEVEL (Enumeration)
                #>
                Write-Output ([System.Runtime.InteropServices.Marshal]::ReadInt32($TokenPtr) -as $SECURITY_IMPERSONATION_LEVEL)
            }
            TokenStatistics
            {
                <#
                The buffer receives a TOKEN_STATISTICS structure that contains various token statistics.
                    TOKEN_STATISTICS (Structure)
                    LUID (Structure)
                    TOKEN_TYPE (Enumeration)
                    SECURITY_IMPERSONATION_LEVEL (Enumeration)
                #>
                Write-Output $TokenPtr
            }
            TokenRestrictedSids
            {
                <#
                The buffer receives a TOKEN_GROUPS structure that contains the list of restricting SIDs in a restricted token.
                    TOKEN_GROUPS (Structure)
                    SID_AND_ATTRIBUTES (Structure)
                #>
                Write-Output $TokenPtr
            }
            TokenSessionId
            {
                # The buffer receives a DWORD value that indicates the Terminal Services session identifier that is associated with the token.
                # If the token is associated with the terminal server client session, the session identifier is nonzero.
                # Windows Server 2003 and Windows XP:  If the token is associated with the terminal server console session, the session identifier is zero.
                # In a non-Terminal Services environment, the session identifier is zero.
                # If TokenSessionId is set with SetTokenInformation, the application must have the Act As Part Of the Operating System privilege, and the application must be enabled to set the session ID in a token.
                Write-Output ([System.Runtime.InteropServices.Marshal]::ReadInt32($TokenPtr))
            }
            TokenGroupsAndPrivileges
            {
                <#
                The buffer receives a TOKEN_GROUPS_AND_PRIVILEGES structure that contains the user SID, the group accounts, the restricted SIDs, and the authentication ID associated with the token.
                    TOKEN_GROUPS_AND_PRIVILEGES (Structure)
                    SID_AND_ATTRIBUTES (Structure)
                    LUID (Structure)
                #>
                Write-Output $TokenPtr
            }
            TokenSandBoxInert
            {
                # The buffer receives a DWORD value that is nonzero if the token includes the SANDBOX_INERT flag.
                Write-Output $TokenPtr
            }
            TokenOrigin
            {
                <#
                The buffer receives a TOKEN_ORIGIN value.
                If the token resulted from a logon that used explicit credentials, such as passing a name, domain, and password to the LogonUser function, then the TOKEN_ORIGIN structure will contain the ID of the logon session that created it.
                If the token resulted from network authentication, such as a call to AcceptSecurityContext or a call to LogonUser with dwLogonType set to LOGON32_LOGON_NETWORK or LOGON32_LOGON_NETWORK_CLEARTEXT, then this value will be zero.
                    TOKEN_ORIGIN (Structure)
                    LUID (Structure)
                #>
                $TokenOrigin = $TokenPtr -as $LUID
                Write-Output (Get-LogonSession -LogonId $TokenOrigin.LowPart)
            }
            TokenElevationType
            {
                <#
                The buffer receives a TOKEN_ELEVATION_TYPE value that specifies the elevation level of the token.
                    TOKEN_ELEVATION_TYPE (Enumeration)
                #>
                Write-Output $TokenPtr
            }
            TokenLinkedToken
            {
                <#
                The buffer receives a TOKEN_LINKED_TOKEN structure that contains a handle to another token that is linked to this token.
                    TOKEN_LINKED_TOKEN (Structure)
                #>
                Write-Output $TokenPtr
            }
            TokenElevation
            {
                <#
                The buffer receives a TOKEN_ELEVATION structure that specifies whether the token is elevated.                                    
                    TOKEN_ELEVATION (Structure)
                #>
                Write-Output $TokenPtr
            }
            TokenHasRestrictions
            {
                # The buffer receives a DWORD value that is nonzero if the token has ever been filtered.
                Write-Output $TokenPtr
            }
            TokenAccessInformation
            {
                <#
                The buffer receives a TOKEN_ACCESS_INFORMATION structure that specifies security information contained in the token.
                    TOKEN_ACCESS_INFORMATION (Structure)
                    SID_AND_ATTRIBUTES_HASH (Structure)
                    SID_HASH_ENTRY (Structure)
                    TOKEN_PRIVILEGES (Structure)
                    LUID_AND_ATTRIBUTES (Structure)
                    LUID (Structure)
                    TOKEN_TYPE (Enumeration)
                    SECURITY_IMPERSONATION_LEVEL (Enumeration)
                    TOKEN_MANDATORY_POLICY (Structure)
                #>
                Write-Output $TokenPtr
            }
            TokenVirtualizationAllowed
            {
                # The buffer receives a DWORD value that is nonzero if virtualization is allowed for the token.
                Write-Output $TokenPtr
            }
            TokenVirtualizationEnabled
            {
                # The buffer receives a DWORD value that is nonzero if virtualization is allowed for the token.
                Write-Output $TokenPtr
            }
            TokenIntegrityLevel
            {
                <#
                The buffer receives a TOKEN_MANDATORY_LABEL structure that specifies the token's integrity level.
                    TOKEN_MANDATORY_LABEL
                    ConvertSidToStringSid
                #>
                $TokenIntegrity = $TokenPtr -as $TOKEN_MANDATORY_LABEL
                switch(ConvertSidToStringSid -SidPointer $TokenIntegrity.Label.Sid)
                {
                    S-1-16-0
                    {
                        Write-Output "UNTRUSTED_MANDATORY_LEVEL"
                    }
                    S-1-16-4096
                    {
                        Write-Output "LOW_MANDATORY_LEVEL"
                    }
                    S-1-16-8192
                    {
                        Write-Output "MEDIUM_MANDATORY_LEVEL"
                    }
                    S-1-16-8448
                    {
                        Write-Output "MEDIUM_PLUS_MANDATORY_LEVEL"
                    }
                    S-1-16-12288
                    {
                        Write-Output "HIGH_MANDATORY_LEVEL"
                    }
                    S-1-16-16384
                    {
                        Write-Output "SYSTEM_MANDATORY_LEVEL"
                    }
                    S-1-16-20480
                    {
                        Write-Output "PROTECTED_PROCESS_MANDATORY_LEVEL"
                    }
                    S-1-16-28672
                    {
                        Write-Output "SECURE_PROCESS_MANDATORY_LEVEL"
                    }
                }
            }
            TokenUIAccess
            {
                # The buffer receives a DWORD value that is nonzero if the token has the UIAccess flag set.
                Write-Output $TokenPtr
            }
            TokenMandatoryPolicy
            {
                <#
                The buffer receives a TOKEN_MANDATORY_POLICY structure that specifies the token's mandatory integrity policy.
                    TOKEN_MANDATORY_POLICY
                #>
                Write-Output $TokenPtr
            }
            TokenLogonSid
            {
                <#
                The buffer receives a TOKEN_GROUPS structure that specifies the token's logon SID.
                    TOKEN_GROUPS (Structure)
                    SID_AND_ATTRIBUTES (Structure)
                #>
                Write-Output $TokenPtr
            }
            TokenIsAppContainer
            {
                # The buffer receives a DWORD value that is nonzero if the token is an app container token. Any callers who check the TokenIsAppContainer and have it return 0 should also verify that the caller token is not an identify level impersonation token. If the current token is not an app container but is an identity level token, you should return AccessDenied.
                Write-Output $TokenPtr
            }
            TokenCapabilities
            {
                <#
                The buffer receives a TOKEN_GROUPS structure that contains the capabilities associated with the token.
                    TOKEN_GROUPS (Structure)
                    SID_AND_ATTRIBUTES (Structure)
                #>
                Write-Output $TokenPtr
            }
            TokenAppContainerSid
            {
                <#
                The buffer receives a TOKEN_APPCONTAINER_INFORMATION structure that contains the AppContainerSid associated with the token. If the token is not associated with an app container, the TokenAppContainer member of the TOKEN_APPCONTAINER_INFORMATION structure points to NULL.
                    TOKEN_APPCONTAINER_INFORMATION (Structure)
                #>
                Write-Output $TokenPtr
            }
            TokenAppContainerNumber
            {
                # The buffer receives a DWORD value that includes the app container number for the token. For tokens that are not app container tokens, this value is zero.
                Write-Output $TokenPtr
            }
            TokenUserClaimAttributes
            {
                <#
                The buffer receives a CLAIM_SECURITY_ATTRIBUTES_INFORMATION structure that contains the user claims associated with the token.
                    CLAIM_SECURITY_ATTRIBUTES_INFORMATION (Structure)
                    CLAIM_SECURITY_ATTRIBUTE_V1 (Structure)
                    CLAIM_SECURITY_ATTRIBUTE_FQBN_VALUE (Structure)
                    CLAIM_SECURITY_ATTRIBUTE_OCTET_STRING_VALUE (Structure)
                #>
                Write-Output $TokenPtr
            }
            TokenDeviceClaimAttributes
            {
                <#
                The buffer receives a CLAIM_SECURITY_ATTRIBUTES_INFORMATION structure that contains the device claims associated with the token.
                    CLAIM_SECURITY_ATTRIBUTES_INFORMATION (Structure)
                    CLAIM_SECURITY_ATTRIBUTE_V1 (Structure)
                    CLAIM_SECURITY_ATTRIBUTE_FQBN_VALUE (Structure)
                    CLAIM_SECURITY_ATTRIBUTE_OCTET_STRING_VALUE (Structure)
                #>
                Write-Output $TokenPtr
            }
            TokenDeviceGroups
            {
                <#
                The buffer receives a TOKEN_GROUPS structure that contains the device groups that are associated with the token.
                    TOKEN_GROUPS (Structure)
                    SID_AND_ATTRIBUTES (Structure)
                #>
                Write-Output $TokenPtr
            }
            TokenRestrictedDeviceGroups
            {
                <#
                The buffer receives a TOKEN_GROUPS structure that contains the restricted device groups that are associated with the token.
                    TOKEN_GROUPS (Structure)
                    SID_AND_ATTRIBUTES (Structure)
                #>
                Write-Output $TokenPtr
            }
        }

        [System.Runtime.InteropServices.Marshal]::FreeHGlobal($TokenPtr)
    }
    else
    {
        Write-Debug "GetTokenInformation Error: $(([ComponentModel.Win32Exception] $LastError).Message)"
    }        
}