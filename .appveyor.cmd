@echo off

if not defined perl_type set perl_type=system
if "%perl_type%" == "strawberry" (
  if not defined perl_version (
    cinst -y StrawberryPerl
  ) else (
    cinst -y StrawberryPerl --version %perl_version%
  )
  set "PATH=C:\Strawberry\perl\bin;C:\Strawberry\perl\site\bin;C:\Strawberry\c\bin;%PATH%"
) else if "%perl_type%" == "system" (
  mkdir c:\dmake
  cinst -y curl
  curl http://www.cpan.org/authors/id/S/SH/SHAY/dmake-4.12.2.2.zip -o c:\dmake\dmake.zip
  7z x c:\dmake\dmake.zip -oc:\ >NUL
  set "PATH=c:\dmake;C:\MinGW\bin;%PATH%"
) else (
  echo.Unknown perl type "%perl_type%"! 1>&2
  exit /b 1
)
for /f "usebackq delims=" %%d in (`perl -MConfig -e"print $Config{make}"`) do set make=%%d
set "perl=perl"
set TAR_OPTIONS=--warning=no-unknown-keyword

:eof
