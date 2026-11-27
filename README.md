# maven-repository

Public Maven repository hosting my open source libraries.

## Content

Latest version per artifact group, including prereleases, taken from the most recently updated Maven metadata. Repository links come from the artifact's latest POM.

<!-- artifacts:start -->

| Artifact group | Latest version | Repository |
| --- | --- | --- |
| [io.github.mflisar.composedialogs](https://github.com/MFlisar/maven-repository/tree/main/artifacts/io/github/mflisar/composedialogs) | <code>5.0.0-alpha10</code> | [ComposeDialogs](https://github.com/MFlisar/ComposeDialogs) |
| [io.github.mflisar.composestyled](https://github.com/MFlisar/maven-repository/tree/main/artifacts/io/github/mflisar/composestyled) | <code>0.0.1-alpha44</code> | [ComposeStyled](https://github.com/MFlisar/ComposeStyled) |
| [io.github.mflisar.composetable](https://github.com/MFlisar/maven-repository/tree/main/artifacts/io/github/mflisar/composetable) | <code>0.0.1-alpha06</code> | [ComposeTable](https://github.com/MFlisar/ComposeTable) |
| [io.github.mflisar.composethemer](https://github.com/MFlisar/maven-repository/tree/main/artifacts/io/github/mflisar/composethemer) | <code>2.0.1-testonly</code> | [ComposeThemer](https://github.com/MFlisar/ComposeThemer) |
| [io.github.mflisar.kmpdevtools](https://github.com/MFlisar/maven-repository/tree/main/artifacts/io/github/mflisar/kmpdevtools) | <code>9.4.2</code> | [kmp-devtools](https://github.com/MFlisar/kmp-devtools) |
| [io.github.mflisar.kmpdevtools.plugins-build-gradle](https://github.com/MFlisar/maven-repository/tree/main/artifacts/io/github/mflisar/kmpdevtools/plugins-build-gradle) | <code>9.4.2</code> | [kmp-devtools](https://github.com/MFlisar/kmp-devtools) |
| [io.github.mflisar.kmpdevtools.plugins-settings-gradle](https://github.com/MFlisar/maven-repository/tree/main/artifacts/io/github/mflisar/kmpdevtools/plugins-settings-gradle) | <code>9.4.2</code> | [kmp-devtools](https://github.com/MFlisar/kmp-devtools) |
| [io.github.mflisar.toolbox](https://github.com/MFlisar/maven-repository/tree/main/artifacts/io/github/mflisar/toolbox) | <code>8.0.0-alpha15</code> | [Toolbox](https://github.com/MFlisar/Toolbox) |

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
