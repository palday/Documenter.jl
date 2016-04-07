__precompile__(true)

"""
Main module for `Documenter.jl` -- a documentation generation package for Julia.

Two functions are exported from this module for public use:

- [`makedocs`]({ref}). Generates documentation from docstrings and templated markdown files.
- [`deploydocs`]({ref}). Deploys generated documentation from *Travis-CI* to *GitHub Pages*.

"""
module Documenter

using Compat

# Submodules.
# -----------

submodule(name) = include(joinpath("modules", string(name, ".jl")))

submodule(:Utilities)
submodule(:Formats)
submodule(:Anchors)
submodule(:Documents)
submodule(:Builder)
submodule(:Expanders)
submodule(:Walkers)
submodule(:CrossReferences)
submodule(:DocChecks)
submodule(:Writers)

# User Interface.
# ---------------

export makedocs, deploydocs

"""
    makedocs(
        root    = "<current-directory>",
        source  = "src",
        build   = "build",
        clean   = true,
        doctest = true,
        modules = Module[],
    )

Combines markdown files and inline docstrings into an interlinked document.
In most cases [`makedocs`]({ref}) should be run from a `make.jl` file:

```julia
using Documenter
makedocs(
    # keywords...
)
```

which is then run from the command line with:

    \$ julia make.jl

The folder structure that [`makedocs`]({ref}) expects looks like:

    docs/
        build/
        src/
        make.jl

**Keywords**

**`root`** is the directory from which `makedocs` should run. When run from a `make.jl` file
this keyword does not need to be set. It is, for the most part, needed when repeatedly
running `makedocs` from the Julia REPL like so:

    julia> makedocs(root = Pkg.dir("MyPackage", "docs"))

**`source`** is the directory, relative to `root`, where the markdown source files are read
from. By convention this folder is called `src`. Note that any non-markdown files stored
in `source` are copied over to the build directory when [`makedocs`]({ref}) is run.

**`build`** is the directory, relative to `root`, into which generated files and folders are
written when [`makedocs`]({ref}) is run. The name of the build directory is, by convention,
called `build`, though, like with `source`, users are free to change this to anything else
to better suit their project needs.

**`clean`** tells [`makedocs`]({ref}) whether to remove all the content from the `build`
folder prior to generating new content from `source`. By default this is set to `true`.

**`doctest`** instructs [`makedocs`]({ref}) on whether to try to test Julia code blocks
that are encountered in the generated document. By default this keyword is set to `true`.
Doctesting should only ever be disabled when initially setting up a newly developed package
where the developer is just trying to get their package and documentation structure correct.
After that, it's encouraged to always make sure that documentation examples are runnable and
produce the expected results. See the [Doctests]({ref}) manual section for details about
running doctests.

**`modules`** specifies a vector of modules that should be documented in `source`. If any
inline docstrings from those modules are seen to be missing from the generated content then
a warning will be printed during execution of [`makedocs`]({ref}). By default no modules are
passed to `modules` and so no warnings will appear. This setting can be used as an indicator
of the "coverage" of the generated documentation.
For example Documenter's `make.jl` file contains:

```julia
$(strip(readstring(joinpath(dirname(@__FILE__), "..", "docs", "make.jl"))))
```

and so any docstring from the module `Documenter` that is not spliced into the generated
documentation in `build` will raise a warning.

**See Also**

A guide detailing how to document a package using Documenter's [`makedocs`]({ref}) is provided
in the [Usage]({ref}) section of the manual.
"""
function makedocs(; debug = false, args...)
    document = Documents.Document(; args...)
    pipeline = Builder.DEFAULT_PIPELINE
    cd(document.user.root) do
        Builder.process(pipeline, document)
    end
    debug ? document : nothing
end

"""
    deploydocs(
        root   = "<current-directory>",
        target = "site",
        repo   = "<required>",
        branch = "gh-pages",
        latest = "master",
        osname = "linux",
        julia  = "nightly",
        deps   = <Function>,
        make   = <Function>,
    )

Converts markdown files generated by [`makedocs`]({ref}) to HTML and pushes them to `repo`.
This function should be called from within a package's `docs/make.jl` file after the call to
[`makedocs`]({ref}), like so

```julia
using Documenter, PACKAGE_NAME
makedocs(
    # options...
)
deploydocs(
    repo = "github.com/..."
)
```

**Keywords**

**`root`** has the same purpose as the `root` keyword for [`makedocs`]({ref}).

**`target`** is the directory, relative to `root`, where generated HTML content should be
written to. This directory **must** be added to the repository's `.gitignore` file. The
default value is `"site"`.

**`repo`** is the remote repository where generated HTML content should be pushed to. This
keyword *must* be set and will throw an error when left undefined. For example this package
uses the following `repo` value:

    repo = "github.com/MichaelHatherly/Documenter.jl.git"

**`branch`** is the branch where the generated documentation is pushed. By default this
value is set to `"gh-pages"`.

**`latest`** is the branch that "tracks" the latest generated documentation. By default this
value is set to `"master"`.

**`osname`** is the operating system which will be used to deploy generated documentation.
This defaults to `"linux"`. This value must be one of those specified in the `os:` section
of the `.travis.yml` configuration file.

**`julia`** is the version of Julia that will be used to deploy generated documentation.
This defaults to `"nightly"`. This value must be one of those specified in the `julia:`
section of the `.travis.yml` configuration file.

**`deps`** is the function used to install any dependancies needed to build the
documentation. By default this function installs `pygments` and `mkdocs`:

    deps = () -> run(`pip install --user pygments mkdocs`)

**`make`** is the function used to convert the markdown files to HTML. By default this just
runs `mkdocs build` which populates the `target` directory.

**See Also**

The [Hosting Documentation]({ref}) section of the manual provides a step-by-step guide to
using the [`deploydocs`]({ref}) function to automatically generate docs and push then to
GitHub.
"""
function deploydocs(;
        root   = Utilities.currentdir(),
        target = "site",

        repo   = error("no 'repo' keyword provided."),
        branch = "gh-pages",
        latest = "master",

        osname = "linux",
        julia  = "nightly",

        deps   = () -> run(`pip install --user pygments mkdocs`),
        make   = () -> run(`mkdocs build`),
    )
    # Get environment variables.
    github_api_key      = get(ENV, "GITHUB_API_KEY",       "")
    travis_branch       = get(ENV, "TRAVIS_BRANCH",        "")
    travis_pull_request = get(ENV, "TRAVIS_PULL_REQUEST",  "")
    travis_repo_slug    = get(ENV, "TRAVIS_REPO_SLUG",     "")
    travis_tag          = get(ENV, "TRAVIS_TAG",           "")
    travis_osname       = get(ENV, "TRAVIS_OS_NAME",       "")
    travis_julia        = get(ENV, "TRAVIS_JULIA_VERSION", "")
    git_rev             = readchomp(`git rev-parse --short HEAD`)

    # When should a deploy be attempted?
    should_deploy =
        contains(repo, travis_repo_slug) &&
        travis_pull_request == "false"   &&
        github_api_key      != ""        &&
        travis_osname       == osname    &&
        travis_julia        == julia     &&
        (
            travis_branch == latest ||
            travis_tag    != ""
        )

    # When env variable `DOCUMENTER_DEBUG == "true"` then print some debugging info.
    debugdeploy(
        github_api_key,
        travis_repo_slug,
        travis_pull_request,
        travis_osname,
        travis_julia,
        travis_branch,
        travis_tag,
    )

    if should_deploy
        # Add local bin path if needed.
        updatepath!(localbin)
        # Install dependancies.
        Utilities.log("installing dependancies.")
        deps()
        # Change to the root directory and try to deploy the docs.
        cd(root) do
            Utilities.log("setting up target directory.")
            Utilities.cleandir(target)
            Utilities.log("building documentation.")
            make()
            Utilities.log("pushing new documentation to remote: $repo:$branch.")
            mktempdir() do temp
                # Versioned docs directories.
                latest_dir = joinpath(temp, "latest")
                stable_dir = joinpath(temp, "stable")
                tagged_dir = joinpath(temp, travis_tag)
                # Git repo setup.
                cd(temp) do
                    run(`git init`)
                    run(`git config user.name  "autodocs"`)
                    run(`git config user.email "autodocs"`)
                    success(`git remote add upstream "https://$github_api_key@$repo"`) ||
                        error("failed to add remote.")
                    success(`git fetch upstream`) ||
                        error("failed to fetch from remote.")
                    success(`git checkout -b $branch upstream/$branch`) ||
                        error("failed to checkout remote.")
                end
                # Copy generated from target to versioned doc directories.
                if travis_tag == ""
                    Utilities.cleandir(latest_dir)
                    cp(target, latest_dir, remove_destination = true)
                else
                    Utilities.cleandir(stable_dir)
                    Utilities.cleandir(tagged_dir)
                    cp(target, stable_dir, remove_destination = true)
                    cp(target, tagged_dir, remove_destination = true)
                end
                # Commit the generated content to the repo.
                cd(temp) do
                    run(`git add -A .`)
                    run(`git commit -m "build based on $git_rev"`)
                    success(`git push -q upstream HEAD:$branch`) ||
                        error("failed to push to remote.")
                end
            end
        end
    else
        Utilities.log("skipping docs deployment.")
    end
end

function debugdeploy(
        github_api_key,
        travis_repo_slug,
        travis_pull_request,
        travis_osname,
        travis_julia,
        travis_branch,
        travis_tag,
    )
    if get(ENV, "DOCUMENTER_DEBUG", "") == "true"
        Utilities.debug("GITHUB_API_KEY empty = $(github_api_key == "")")
        Utilities.debug("TRAVIS_REPO_SLUG     = \"$travis_repo_slug\"")
        Utilities.debug("TRAVIS_PULL_REQUEST  = \"$travis_pull_request\"")
        Utilities.debug("TRAVIS_OS_NAME       = \"$travis_osname\"")
        Utilities.debug("TRAVIS_JULIA_VERSION = \"$travis_julia\"")
        Utilities.debug("TRAVIS_BRANCH        = \"$travis_branch\"")
        Utilities.debug("TRAVIS_TAG           = \"$travis_tag\"")
    end
end

const localbin = joinpath(homedir(), ".local", "bin")

updatepath!(p) = contains(ENV["PATH"], p) ? ENV["PATH"] : (ENV["PATH"] = "$p:$(ENV["PATH"])")

end
