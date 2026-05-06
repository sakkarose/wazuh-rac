/* Peaklight Ransomware */

rule M_AES_Encrypted_payload {
   meta:
      author = "MAS"
      reference = "https://www.mandiant.com/"
      description = "This rule is desgined to detect on events that exhibits indicators of utilizing AES encryption for payload obfuscation."
      target_entity = "Process"
  strings:
    $a = /(\$\w+\.Key(\s|)=((\s|)(\w+|));|\$\w+\.Key(\s|)=(\s|)\w+\('\w+'\);)/
    $b = /\$\w+\.IV/
    $c = /System\.Security\.Cryptography\.(AesManaged|Aes)/
  condition:
    all of them
}

rule M_Downloader_PEAKLIGHT_1 {
   meta:
      author = "MAS"
      reference = "https://www.mandiant.com/"
      description = "This rule is designed to detect events related to Peaklight. PEAKLIGHT is an obfuscated PowerShell-based downloader which checks for the presence of hard-coded filenames and downloads files from a remote CDN if the files are not present."
      category = "Malware"
   strings:
      $str1 = /function\s{1,16}\w{1,32}\(\$\w{1,32},\s{1,4}\$\w{1,32}\)\{\[IO\.File\]::WriteAllBytes\(\$\w{1,32},\s{1,4}\$\w{1,32}\)\}/ ascii wide 
      $str2 = /Expand-Archive\s{1,16}-Path\s{1,16}\$\w{1,32}\s{1,16}-DestinationPath/ ascii wide
      $str3 = /\(\w{1,32}\s{1,4}@\((\d{3,6},){3,12}/ ascii wide
      $str4 = ".DownloadData(" ascii wide
      $str5 = "[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::TLS12" ascii wide
      $str6 = /\.EndsWith\(((["']\.zip["'])|(\(\w{1,32}\s{1,16}@\((\d{3,6},){3}\d{3,6}\)\)))/ ascii wide
      $str7 = "Add -Type -Assembly System.IO.Compression.FileSystem" ascii wide
     $str8 = "[IO.Compression.ZipFile]::OpenRead"
   condition:
     4 of them and filesize < 10KB         
}

/* BrainCipher Ransomware */

rule BrainCipher_ransomware {
   meta:
      description = "Brain Cipher ransomware executable detection"
      author = "Aishat Motunrayo Awujola"
      reference = "https://github.com/Neo23x0/yarGen"
      date = "2025-01-20"
    hash1= "eb82946fa0de261e92f8f60aa878c9fef9ebb34fdababa66995403b110118b12"

  strings:
      $s1 = "L%nu%s\"^6" fullword ascii
      $s2 = "D$PWSP" fullword ascii /* Goodware String - occurred 1 times */
      $s3 = "2'2b2v2" fullword ascii /* Goodware String - occurred 1 times */
      $s4 = "Loyn?P00" fullword ascii
      $s5 = "4f5l5x5~5" fullword ascii /* Goodware String - occurred 1 times */
      $s6 = "4 444u4" fullword ascii /* Goodware String - occurred 1 times */
      $s7 = "wSYM ,9" fullword ascii
      $s8 = "=V=\\={=" fullword ascii /* Goodware String - occurred 1 times */
      $s9 = "5E6L6S6Z6" fullword ascii /* Goodware String - occurred 1 times */
      $s10 = ";&;P;_;" fullword ascii /* Goodware String - occurred 1 times */
      $s11 = "?0N0]0l0" fullword ascii /* Goodware String - occurred 1 times */
      $s12 = "9D$$ua" fullword ascii /* Goodware String - occurred 2 times */
      $s13 = "4.4=4L4" fullword ascii /* Goodware String - occurred 2 times */
      $s14 = "SQRVW3" fullword ascii
      $s15 = "_^ZY[]" fullword ascii /* Goodware String - occurred 3 times */
      $s16 = "?%U$38O" fullword ascii
      $s17 = "9&9,949" fullword ascii
      $s18 = "303M3W3" fullword ascii
      $s19 = "7+7:7I7H8R8z8" fullword ascii
      $s20 = "+D$H[_]^" fullword ascii
   condition:
      uint16(0) == 0x5a4d and filesize < 400KB and
      8 of them
}

/* BLX Stealer */

rule BLX_Stealer_rule {
    
    meta:
        description = "Detects BLX Stealer malware"
        author = "Wazuh"
        date = "2024-11-01"
        reference = "https://www.cyfirma.com/research/blx-stealer/"
        
    
    strings:
        $str0 = { 20 20 20 20 70 6f 6c 69 63 79 2e 6d 61 6e 69 66 65 73 74 2e 61 73 73 65 72 74 49 6e 74 65 67 72 69 74 79 28 6d 6f 64 75 6c 65 55 52 4c 2c 20 63 6f 6e 74 65 6e 74 29 3b }
        $str1 = { 20 20 41 72 72 61 79 50 72 6f 74 6f 74 79 70 65 53 68 69 66 74 2c }
        $str2 = { 20 20 69 66 20 28 21 73 74 61 74 65 2e 6b 65 65 70 41 6c 69 76 65 54 69 6d 65 6f 75 74 53 65 74 29 }
        $str3 = { 20 20 72 65 74 75 72 6e 20 72 65 71 75 69 72 65 28 27 74 6c 73 27 29 2e 44 45 46 41 55 4c 54 5f 43 49 50 48 45 52 53 3b }
        $str4 = { 21 47 7e 79 5f 3b }
        $str5 = { 3f 52 65 64 75 63 65 53 74 61 72 74 40 42 72 61 6e 63 68 45 6c 69 6d 69 6e 61 74 69 6f 6e 40 63 6f 6d 70 69 6c 65 72 40 69 6e 74 65 72 6e 61 6c 40 76 38 40 40 41 45 41 41 3f 41 56 52 65 64 75 63 74 69 6f 6e 40 32 33 34 40 50 45 41 56 4e 6f 64 65 40 32 33 34 40 40 5a }
        $str6 = { 40 55 56 57 48 }
        $str7 = { 41 49 5f 41 44 44 52 43 4f 4e 46 49 47 }
        $str8 = { 44 24 70 48 }
        $str9 = { 45 56 50 5f 4d 44 5f 43 54 58 5f 73 65 74 5f 75 70 64 61 74 65 5f 66 6e }
        $str10 = { 46 61 69 6c 65 64 20 74 6f 20 64 65 73 65 72 69 61 6c 69 7a 65 20 64 6f 6e 65 5f 73 74 72 69 6e 67 }
        $str11 = { 49 63 4f 70 }
        $str12 = { 54 24 48 48 }
        $str13 = { 5c 24 30 48 }
        $str14 = { 5c 24 58 48 }
        $str15 = { 64 24 40 48 }
        $str16 = { 67 65 74 73 6f 63 6b 6f 70 74 }
        $str17 = { 73 74 72 65 73 73 20 74 68 65 20 47 43 20 63 6f 6d 70 61 63 74 6f 72 20 74 6f 20 66 6c 75 73 68 20 6f 75 74 20 62 75 67 73 20 28 69 6d 70 6c 69 65 73 20 2d 2d 66 6f 72 63 65 5f 6d 61 72 6b 69 6e 67 5f 64 65 71 75 65 5f 6f 76 65 72 66 6c 6f 77 73 29 }
        $str18 = { 74 24 38 48 }
        $str19 = { 74 24 60 48 }
        
        $blx_stealer_network = "https://api.ipify.org" ascii wide nocase
        $blx_stealer_network1 = "https://geolocation-db.com" ascii wide nocase
        $blx_stealer_network2 = "https://discord.com/api/webhooks" ascii wide nocase
        
        $blx_stealer_hash1 = "8c4daf5e4ced10c3b7fd7c17c7c75a158f08867aeb6bccab6da116affa424a89"
        $blx_stealer_hash2 = "e74dac040ec85d4812b479647e11c3382ca22d6512541e8b42cf8f9fbc7b4af6"
        $blx_stealer_hash3 = "32abb4c0a362618d783c2e6ee2efb4ffe59a2a1000dadc1a6c6da95146c52881"
        $blx_stealer_hash4 = "5b46be0364d317ccd66df41bea068962d3aae032ec0c8547613ae2301efa75d6"

    condition:
        (all of ($str*) or any of ($blx_stealer_network*) or any of ($blx_stealer_hash*))

}

/* Medusa ransomware */

rule Medusa_ransomware {
   meta:
      description = "Medusa Ransomware"
      author = "Obinna Uchubilo"
      reference = "https://github.com/Neo23x0/yarGen"
      date = "2025-04-16"
      hash1 = "3a6d5694eec724726efa3327a50fad3efdc623c08d647b51e51cd578bddda3da"
   strings:
      $s1 = "api-ms-win-core-synch-l1-2-0.dll" fullword wide /* reversed goodware string 'lld.0-2-1l-hcnys-eroc-niw-sm-ipa' */
      $s2 = "powershell -executionpolicy bypass -File %s" fullword ascii
      $s3 = "powershell -Command \"& {%s}\"" fullword ascii
      $s4 = "cmd /c ping localhost -n 3 > nul & del %s" fullword ascii
      $s5 = "AppPolicyGetProcessTerminationMethod" fullword ascii
      $s6 = "preprocess" fullword ascii
      $s7 = "G:\\Medusa\\Release\\gaze.pdb" fullword ascii
      $s8 = "kill_processes %s" fullword ascii
      $s9 = "        <requestedExecutionLevel level='asInvoker' uiAccess='false' />" fullword ascii
      $s10 = "load_encryption_key:File open error" fullword ascii
      $s11 = "kill_services processes" fullword ascii
      $s12 = ":do not use preprocess" fullword ascii
      $s13 = "encrypt system" fullword ascii
      $s14 = "VVVQVP" fullword ascii /* reversed goodware string 'PVQVVV' */
      $s15 = ": option requires an argument -- " fullword ascii
      $s16 = "File is already encrypted." fullword ascii
      $s17 = ": illegal option -- " fullword ascii
      $s18 = "AppPolicyGetThreadInitializationType" fullword ascii
      $s19 = "encrypt %d %ls %ld" fullword wide
      $s20 = "KVK.xKKOCmOZOBAI}XM.clk@J^AG@ZoIK@Z.c}}" fullword ascii
   condition:
      uint16(0) == 0x5a4d and filesize < 2000KB and
      8 of them
}

/* BlackSuit ransomware */

rule BlackSuit_ransomware {
   meta:
      description = "BlackSuit ransomware executable detection"
      author = "Aishat Motunrayo Awujola"
      reference = "https://github.com/Neo23x0/yarGen"
      date = "2024-10-03"
hash1= "90ae0c693f6ffd6dc5bb2d5a5ef078629c3d77f874b2d2ebd9e109d8ca049f2c"
   strings:
      $x1 = "C:\\Users\\pipi-\\source\\repos\\encryptor\\Release\\encryptor.pdb" fullword ascii
      $s2 = "api-ms-win-core-synch-l1-2-0.dll" fullword wide /* reversed goodware string 'lld.0-2-1l-hcnys-eroc-niw-sm-ipa' */
      $s3 = "C:\\Users\\Adm\\vcpkg\\packages\\openssl_x86-windows-static\\bin" fullword ascii
      $s4 = "C:\\Users\\Adm\\vcpkg\\buildtrees\\openssl\\x86-windows-static-rel\\providers\\implementations\\ciphers\\cipher_aes_hw_aesni.inc" ascii
      $s5 = "C:\\Users\\Adm\\vcpkg\\buildtrees\\openssl\\x86-windows-static-rel\\providers\\implementations\\ciphers\\cipher_aes_cts.inc" fullword ascii
      $s6 = "C:\\Users\\Adm\\vcpkg\\buildtrees\\openssl\\x86-windows-static-rel\\providers\\implementations\\macs\\blake2_mac_impl.c" fullword ascii
      $s7 = "get_payload_private_key" fullword ascii
      $s8 = "C:\\Users\\Adm\\vcpkg\\packages\\openssl_x86-windows-static\\lib\\engines-3" fullword ascii
      $s9 = "C:\\Users\\Adm\\vcpkg\\packages\\openssl_x86-windows-static" fullword ascii
      $s10 = "get_payload_public_key" fullword ascii
      $s11 = "C:\\Users\\Adm\\vcpkg\\buildtrees\\openssl\\x86-windows-static-rel\\crypto\\err\\err_local.h" fullword ascii
      $s12 = "C:\\Users\\Adm\\vcpkg\\buildtrees\\openssl\\x86-windows-static-rel\\providers\\implementations\\ciphers\\cipher_camellia_cts.inc" ascii
      $s13 = "C:\\Windows\\Sysnative\\bcdedit.exe" fullword wide
      $s14 = "C:\\Windows\\Sysnative\\vssadmin.exe" fullword wide
      $s15 = "error processing message" fullword ascii
      $s16 = "C:\\Users\\Adm\\vcpkg\\buildtrees\\openssl\\x86-windows-static-rel\\engines\\e_capi_err.c" fullword ascii
      $s17 = "AppPolicyGetProcessTerminationMethod" fullword ascii
      $s18 = "get_dh_dsa_payload_p" fullword ascii
      $s19 = "loader incomplete" fullword ascii
      $s20 = "get_payload_group_name" fullword ascii
   condition:
      uint16(0) == 0x5a4d and filesize < 7000KB and
      1 of ($x*) and 4 of them
}

/* DOGE Big Balls ransomware */
rule _DOGE_Big_Balls_Ransomware {
   meta:
      description = "DOGE Big Balls ransomware executable detection"
      author = "Anthony Faruna"
      reference = "https://github.com/Neo23x0/yarGen"
      date = "2025-05-19"
   strings:
      $s1 = "Failed to open file. ShellExecute error: %d" fullword ascii
      $s2 = "AppPolicyGetProcessTerminationMethod" fullword ascii
      $s3 = "\\RANSOMNOTE.txt" fullword ascii
      $s4 = "Failed to get Desktop path." fullword ascii
      $s5 = "%s\\Desktop\\RANSOMNOTE.txt" fullword ascii
      $s6 = "Open RANSOMNOTE.txt?" fullword ascii
      $s7 = " Type Descriptor'" fullword ascii
      $s8 = "operator co_await" fullword ascii
      $s9 = "User clicked OK." fullword ascii
      $s10 = "api-ms-win-appmodel-runtime-l1-1-2" fullword wide
      $s11 = "User clicked Cancel or closed the MessageBox." fullword ascii
      $s12 = " Class Hierarchy Descriptor'" fullword ascii
      $s13 = " Base Class Descriptor at (" fullword ascii
      $s14 = "COM256" fullword ascii
      $s15 = "F9]%c%" fullword ascii
      $s16 = " Complete Object Locator'" fullword ascii
      $s17 = "\"^4]%* " fullword ascii
      $s18 = "(- d|X" fullword ascii
      $s19 = "USERPROFILE" fullword ascii /* Goodware String - occured 154 times */
      $s20 = "network down" fullword ascii /* Goodware String - occured 567 times */
   condition:
      ( uint16(0) == 0x5a4d and filesize < 1000KB and ( 8 of them )
      ) or ( all of them )
}

/* Mamona ransomware */
rule Mamona_ransomware {
    meta:
        description = "Detects Mamona ransomware or similar variants"
        author = "Oluwaseyi Soneye"
        reference = "Strings output analysis"
        date = "2025-05-22"

    strings:
        $s1 = "YOUR FILES HAVE BEEN ENCRYPTED!" nocase
        $s2 = "CHECK README." nocase
        $s3 = "README." nocase
        $s4 = "password OK" nocase
        $s5 = "wrong pass" nocase
        $s6 = "provide pass" nocase
        $s7 = "encryption mode" nocase
        $s8 = "Mamona" nocase
        $s9 = "cleared event logs" nocase
        $s10 = "WinDefend" nocase
        $s11 = "SecurityHealthService" nocase
        $s12 = "TerminateProcess" nocase
        $s13 = "killed process" nocase
        $s14 = "killed service" nocase
        $s15 = "WNetAddConnection2W" nocase
        $s16 = "NetShareEnum" nocase
        $s17 = "\\%s\\IPC$" nocase
        $s18 = "encrypting file" nocase
        $s19 = "encrypting directory" nocase
        $s20 = "Del /f /q" nocase
        $s21 = "cmd.exe /C ping 127.0.0.7 -n 3 > Nul & Del /f /q" nocase
        $s22 = "PrintMe22" nocase
        $s23 = "printed note to printer" nocase

    condition:
        (uint16(0) == 0x5A4D) and  // PE header check
        (
            any of ($s*) or
            (3 of ($s1, $s2, $s3, $s4, $s5, $s6, $s7, $s8)) or
            (2 of ($s9, $s10, $s11, $s12, $s13, $s14)) or
            (2 of ($s15, $s16, $s17)) or
            (2 of ($s18, $s19, $s20, $s21, $s22, $s23))
        )
}

/* Mint Stealer malware */
rule MintStealer
{
meta:
        Author = "Benjamin Nworah"
        Description = "Detect Mint Stealer malware"
        Date = "13-09-2024"
        Hash1 = "1064ab9e734628e74c580c5aba71e4660ee3ed68db71f6aa81e30f148a5080fa" // SHA-256 Hash
        Hash2 = "cc93a4627a459d505c46de6fac342f856fb8f95b6a4fdcbd5e48be59aa4cbb7b" // SHA-256 Hash

    strings:
        $a1 = "FindResource"
        $a2 = "GetSystemTimeAsFileTime"
        $a3 = /NUITKA.{1,15}/
     
    condition:
        all of ($a*)
}

/* Daolpu malware */
rule Daolpu_infostealer 
{
    meta:
        Author = "Benjamin Nworah"
        Description = "Detect Daolpu malware"
        Date = "16-08-2024"
        Hash1 = "3a9323a939fbecbc6d0ceb5c1e1f3ebde91e9f186b46fdf3ba1aee03d1d41cd8"
        Hash2 = "4ad9845e691dd415420e0c253ba452772495c0b971f48294b54631e79a22644a"

    strings:
        $a1 = "D:\\c++\\Mal_Cookie_x64\\x64\\Release\\mscorsvc.pdb"
        $a2 = "C:\\Windows\\Temp\\result.txt"
     
    condition:
        all of ($a*)
}

/* Apos malware */
rule Apos_malware {
   meta:
      description = "Detects Apos malware"
      author = "Aishat Awujola"
      reference = "https://github.com/Neo23x0/yarGen"
      date = "2025-08-26"
   strings:
      $x1 = "srvcli.dll" fullword wide /* reversed goodware string 'lld.ilcvrs' */
      $x2 = "devrtl.dll" fullword wide /* reversed goodware string 'lld.ltrved' */
      $x3 = "dfscli.dll" fullword wide /* reversed goodware string 'lld.ilcsfd' */
      $x4 = "browcli.dll" fullword wide /* reversed goodware string 'lld.ilcworb' */
      $x5 = "linkinfo.dll" fullword wide /* reversed goodware string 'lld.ofniknil' */
      $s6 = "atl.dll" fullword wide /* reversed goodware string 'lld.lta' */
      $s7 = "api-ms-win-core-synch-l1-2-0.dll" fullword wide /* reversed goodware string 'lld.0-2-1l-hcnys-eroc-niw-sm-ipa' */
      $s8 = "SSPICLI.DLL" fullword wide
      $s9 = "UXTheme.dll" fullword wide
      $s10 = "oleaccrc.dll" fullword wide
      $s11 = "dnsapi.DLL" fullword wide
      $s12 = "iphlpapi.DLL" fullword wide
      $s13 = "WINNSI.DLL" fullword wide
      $s14 = "sfxrar.exe" fullword ascii
      $s15 = "Cannot create folder %sHChecksum error in the encrypted file %s. Corrupt file or wrong password." fullword wide
      $s16 = "libffi-8.dll" fullword ascii
      $s17 = "libpcre2-8-0.dll" fullword ascii
      $s18 = "D:\\Projects\\WinRAR\\sfx\\build\\sfxrar64\\Release\\sfxrar.pdb" fullword ascii
      $s19 = "233333333333333333" ascii /* hex encoded string '#33333333' */
      $s20 = "$GETPASSWORD1:IDC_PASSWORDENTER" fullword ascii
   condition:
      uint16(0) == 0x5a4d and filesize < 8000KB and
      1 of ($x*) and 4 of them
}

/* Funklocker ransomware */
rule funklocker_ransomware {
   meta:
      description = "Detects Funklocker ransomware or similar variants"
      author = "Oluwaseyi Soneye"
      reference = "Strings output analysis"
      date = "2025-11-10"

   strings:
      // Ransomware commands
      $x1 = "Set-MpPreference -DisableRealtimeMonitoring" nocase
      $x2 = "wevtutil sl Security /e:false" nocase
      $x3 = "wevtutil sl Application /e:false" nocase
      $x4 = "Set-ExecutionPolicy Bypass -Scope Process" nocase
      $x5 = "Set-MpPreference -DisableRealtimeMonitoring $truewevtutil sl Security /e:falsewevtutil sl Application /e:falseSet-ExecutionPolicy" nocase
      $x6 = "vssadmindelete shadows/all/quiet" nocase
      $x7 = "taskkill/F/IM" nocase
      // Ransomware artifacts
      $x8 = "RansomwarePassword123" nocase
      $x9 = "device has been successfully infiltrated by funksec ransomware!" nocase
      $x10 = "funksec" nocase
   condition:
      uint16(0) == 0x5a4d and
        (
                (5 of ($x1, $x2, $x3, $x4, $x5, $x6, $x7)) or
                (2 of ($x8, $x9, $x10))
        )
}

/* Cephalus ransomware*/
rule Cephalus_ransomware {
   meta:
      description = "Detects Cephalus ransomware"
      author = "Aishat Awujola"
      reference = "https://github.com/Neo23x0/yarGen"
      date = "2025-11-20"
      
   strings:
      $x1 = "pacer: assist ratio=workbuf is not emptybad use of bucket.mpbad use of bucket.bpruntime: double waitpreempt off reason: forcegc:" ascii
      $x2 = "_cgo_pthread_key_created missingruntime: sudog with non-nil elemruntime: sudog with non-nil nextruntime: sudog with non-nil prev" ascii
      $x3 = "runtime: bad notifyList size - sync=accessed data from freed user arena runtime: wrong goroutine in newstackruntime: invalid pc-" ascii
      $x4 = "lock: sleeping while lock is availableP has cached GC work at end of mark terminationfailed to acquire lock to start a GC transi" ascii
      $x5 = " (types from different scopes)notetsleep - waitm out of syncfailed to get system page sizeruntime: found in object at *( in prep" ascii
      $x6 = ", locked to threadruntime.semacreateruntime.semawakeupCuba Standard TimeOmsk Standard TimeArab Standard TimeIran Standard TimeRu" ascii
      $x7 = "tried to trace goroutine with invalid or unsupported statussync: WaitGroup is reused before previous Wait has returnedecdsa: int" ascii
      $x8 = "runtime.Pinner: object already unpinnedsuspendG from non-preemptible goroutineruntime: casfrom_Gscanstatus failed gp=stack growt" ascii
      $x9 = " runqueue= stopwait= runqsize= gfreecnt= throwing= spinning=atomicand8float64nanfloat32nanException  ptrSize=  targetpc= until p" ascii
      $x10 = "lock: lock countbad system huge page sizearena already initialized to unused region of span bytes failed with errno=runtime: Vir" ascii
      $x11 = "internal error: polling on unsupported descriptor typemheap.freeSpanLocked - invalid free of user arena chunkcasfrom_Gscanstatus" ascii
      $x12 = "stopm spinning nmidlelocked= needspinning=randinit twicestore64 failedsemaRoot queuebad allocCountbad span statestack overflow u" ascii
      $x13 = "unlock: lock countprogToPointerMask: overflow/gc/cycles/forced:gc-cycles/memory/classes/other:bytes/memory/classes/total:bytesfa" ascii
      $x14 = "runtime.newosprocruntime/internal/internal/runtime/thread exhaustionlocked m0 woke upentersyscallblock spinningthreads=gp.waitin" ascii
      $x15 = "time: bad [0-9]*exec: no commandinvalid exchangeno route to hostinvalid argumentmessage too longobject is remoteremote I/O error" ascii
      $x16 = "ckWSAGetOverlappedResultexit hook invoked exit%SystemRoot%\\system32\\sha3: Write after ReadC:\\ProgramData\\temp.datDEFGHIJKLMN" ascii
      $x17 = "DetECDSA P-256 SHA2-512 signinvalid P224Element encodinginvalid P384Element encodinginvalid P521Element encodingC:\\Windows\\Tem" ascii
      $x18 = "Value.SetIntGetAdaptersAddressesNtSetInformationFileGetProcessMemoryInfobcryptprimitives.dllhttplaxcontentlengthsha3: Sum after " ascii
      $x19 = "orC:\\Windows\\Tempx509usepoliciesGetProcessTimesDuplicateHandleallocmRInternalGC (fractional)write heap dumpasyncpreemptoffforc" ascii
      $x20 = "span set block with unpopped elements found in resetruntime: GetQueuedCompletionStatusEx failed (errno= runtime: NtCreateWaitCom" ascii
   condition:
      uint16(0) == 0x5a4d and filesize < 9000KB and
      1 of ($x*)
}