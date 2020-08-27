Linux kernel
=========================================
This file was moved to Documentation/admin-guide/README.rst

Please notice that there are several guides for kernel developers and users.
These guides can be rendered in a number of formats, like HTML and PDF.

In order to build the documentation, use ``make htmldocs`` or
``make pdfdocs``.
=========================================
## Quantic Kernel for MIUI/AOSP Cepheus&Raphael

This kernel is made to work and all AOSP ROMs and MIUI ROMs on the Xiaomi Mi9 Cepheus
This kernel is made to work on all AOSP LOSFOD ROMs and MIUI ROMS on the Redmi k20 Pro

NOTES FOR k20 PRO:
- If you are using this kernel on LOSFOD rom and you face FOD Issues please delete Quantic FOD magisk module
NOTES FOR Mi9:
- If you are going to use this kernel on HavocOS or roms using OLD Fod implementation, kernel will not be able to read Fingerprint.

=========================================

## For ROM Builders

Thanks for using QK as your ROM kernel, please before compiling follow the next:

To avoid problems of ROM not booting please git checkout PELT and revert the following commits

- b4ad2de6c78611f7b816ab5c1d5a05d8b2435ec9
- 55cb2ffa6e654f50e750d6c8028ad381c0c3090a
- d7c6ea4efd7f695a552aba7035a26d6b4d349b22
- 3c947158dc9ca7aad8fc532564d9657f54f5135d

This however is not necessary if you are using Clang-11 versions or above.
