{
  # noda-js: the native addon for noda-js-win32-x64 and noda-js-win32-arm64 (built by scripts/native/build-native.ts).
  # A plain C Node-API module, built with LLVM (Visual Studio's clang-cl and lld-link). The .node and its PDB (next to it
  # in build/Release, not packed) are reproducible, wherever the repository is checked out: no timestamps (/Brepro), a
  # content-hash PDB GUID, and no absolute paths of the checkout (the equivalent of .NET's PathMap).
  "targets": [
    {
      "target_name": "time-zones",
      "msbuild_toolset": "ClangCL",
      "sources": ["time-zones.c", "windows-time-zones.c"],
      "defines": ["NAPI_VERSION=8"],
      "libraries": ["advapi32.lib", "user32.lib"],
      # Relative (to build/), so the linker's command line in the PDB names /OUT and /PDB without the checkout's path.
      "msvs_configuration_attributes": { "OutputDirectory": "$(Configuration)\\" },
      "msvs_settings": {
        "VCCLCompilerTool": {
          "AdditionalOptions": [
            "/Brepro", "/utf-8", "/W4", "/WX",
            # Sources and objects named relative to this folder (node-gyp's under node-gyp), no compiler command line.
            "/clang:-ffile-prefix-map=<(module_root_dir)=.", "/clang:-ffile-prefix-map=<(node_gyp_dir)=node-gyp",
            "/clang:-fdebug-compilation-dir=.", "/clang:-gno-codeview-command-line",
          ],
          # From Node's common.gypi: -std:c++20 (clang-cl rejects it for C); Node's own PGO profile (Node's builds with
          # enable_pgo_use), which an addon doesn't have.
          "AdditionalOptions!": ["-std:c++20", "-fprofile-use=$(SolutionDir)node.profdata"],
          # /Z7: debug info in the objects, for the linker's PDB.
          "DebugInformationFormat": "1",
        },
        "VCLinkerTool": {
          # /PDBSOURCEPATH:.: relative paths (the CRT's, ours) stay relative instead of taking the linker's directory.
          "AdditionalOptions": [
            "/Brepro", "/DEBUG:FULL", "/PDBALTPATH:%_PDB%", "/PDBSOURCEPATH:.", "/OPT:REF", "/OPT:ICF", "/INCREMENTAL:NO",
          ],
          "AdditionalOptions!": ["-fprofile-use=$(SolutionDir)node.profdata"],
          "GenerateDebugInformation": "true",
        },
      },
    },
  ],
}
