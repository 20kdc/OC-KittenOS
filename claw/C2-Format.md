# Claw2 Formats

## .c2l format

The .c2l format is the server package list for Claw2.

In an exception to the rule, this file only exists on the server.

It is used solely in the main package list panel.

It is a file made up of lines.

Each line contains a package name, followed by a dot, followed by the package version.

## .V.c2p format

The .V.c2p (where V is the version) format is the entire contents of the package view panel,
 as text, with newlines, in UTF-8.

This is used when a package is selected in Claw2.

## .c2x format

The .c2x format is the actual installation script for the package.

It is executed by svc-claw-worker.

It's loaded in all-at-once, then it's gmatched
 with the pattern [^\n]+.

A line starting with "?" represents a dependency.

A line starting & ending with "/" represents a directory creation.

And a line starting with "+" represents a file.

Package metadata is not implied.

Thus, a valid .c2x is:

```
    ?neo
    /apps/
    +apps/app-carrot.0.c2p
    +apps/app-carrot.c2x
```

## Claw2 Architecture

app-claw is a very dumb client, but the only thing that'll bother
 to parse a .c2l (because it has package list/search),
 and the only thing that cares about version numbers.

The purpose of it is to provide an older-CLAW-style GUI.

It *may* take an argument, in which case a package panel is opened,
 otherwise the main search panel is opened.

When it wants to do anything, it shuts itself down, running svc-claw-worker.

svc-app-claw-worker does all package consistency & such work.

It can only be run from app-claw, and runs app-claw after it's done.

It takes 4 arguments:

1. The target filesystem proxy.
2. The target package name. This package is viewed in app-claw after completion.
3. The source to download files from.
   If nil, the package is being deleted.
   Otherwise, can either be a proxy or a string.
   Proxy means it's a filesystem,
    string means it's an internet base.
4. Checked flag
