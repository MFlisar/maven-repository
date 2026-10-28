# maven-repository

Public Maven repository hosting my open source libraries.

## Content

Latest version per artifact group, including prereleases, taken from the most recently updated Maven metadata.

<!-- artifacts:start -->
| Artifact group | Latest version |
| --- | --- |
| [io.github.mflisar.composestyledcomponents](artifacts/io/github/mflisar/composestyledcomponents) | <code>0.0.1-alpha02</code> |
| [io.github.mflisar.composetable](artifacts/io/github/mflisar/composetable) | <code>0.0.1-alpha01</code> |
<!-- artifacts:end -->

## Maintenance

| Trigger | Action |
| --- | --- |
| Push to `main` | Update the artifact table. |
| Push deleting files under `artifacts/` | Rebuild Maven metadata and checksums, then update the table. |
| Manual: **Update README** | Refresh the table only. |
| Manual: **Rebuild Maven metadata** | Rebuild metadata and checksums, then update the table. |

Manual workflows are available under **Actions**.

> **External publishers:** Pushes made with `GITHUB_TOKEN` do not trigger workflows.
> To refresh the table, explicitly trigger `workflow_dispatch` for **Update README**
> or send a `repository_dispatch` event with type `artifacts-published`.

### Metadata rebuild

- Derives version lists from published POM directories using Maven version ordering.
- Removes orphaned artifact metadata and regenerates MD5, SHA-1, SHA-256 and SHA-512 checksums.
- Uses each artifact's latest POM commit for `lastUpdated`.
- Leaves versioned files and snapshot-level metadata unchanged.
- Rejects signed metadata, which requires re-signing.

Metadata and the updated table are saved in the same commit.