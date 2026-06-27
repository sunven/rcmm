# ADR-0002: Deepen Script Compilation Pipeline

Status: accepted — 2026-06-27

`ScriptSyncCoordinator` was a shallow module: callers had to pass Menu Entry values, while the implementation still reloaded saved configuration, updated Publish State and errors, posted Cross-Process Sync, and serialized file writes. We replaced that seam with `ScriptCompilationPipeline.publishCurrentConfiguration()`: callers save configuration first, then ask the pipeline to publish the current saved configuration and receive the results, Publish State snapshot, and error snapshot.

The pipeline owns the serial queue and Darwin notification because they are part of the same implementation concern as writing `.scpt` files and shared publish records. `ScriptInstallerService` remains a lower-level implementation detail for script generation, compilation, and file lifecycle work. This supersedes ADR-0001's `ScriptSyncCoordinator` shape while preserving flat composition in `AppCoordinator`.
