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

Updated automatically on pushes to `main`, or manually via **Update README**. Publishers using `GITHUB_TOKEN` must explicitly trigger `workflow_dispatch` or send a `repository_dispatch` event with type `artifacts-published`, since their pushes do not trigger workflows.