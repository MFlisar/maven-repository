# maven-repository

Public Maven repository hosting my open source libraries.

## Content

Latest version per artifact group, including prereleases, taken from the most recently updated Maven metadata.

<!-- artifacts:start -->
| Artifact group | Latest version |
| --- | --- |
| [io.github.mflisar.composetable](artifacts/io/github/mflisar/composetable) | <code>0.0.1-alpha01</code> |
<!-- artifacts:end -->

Updated automatically on pushes to `main`, or manually via **Update README**.
Publishers using `GITHUB_TOKEN` must explicitly trigger `workflow_dispatch` or send a `repository_dispatch` event with type `artifacts-published`, since their pushes do not trigger workflows.

Normal pushes only refresh the table. If a push deletes files under `artifacts/`, **Update README** first rebuilds Maven metadata. You can also run **Rebuild Maven metadata** manually under **Actions**. Rebuilding derives version lists from published POM directories using Maven version ordering, removes orphaned artifact metadata, regenerates MD5/SHA-1/SHA-256/SHA-512 checksums, and then updates this table in the same commit. Versioned files and snapshot-level metadata remain unchanged. `lastUpdated` comes from each artifact's latest POM commit. Signed metadata is rejected because rebuilding it requires re-signing.