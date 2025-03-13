# About

This is my personal blog. I write about my technical projects and other stuff usually somewhat related to functional programming. If you're interested, here's the link: https://jonathanrlouie.github.io/

# Building and Deploying

Run `deploy.sh`, which runs the following commands:

```bash
# build site.hs
stack build

# clean build
stack exec site clean
stack exec site build
```
This will build the Hakyll site and output the generated files in a `docs/` folder. This folder must be checked in, since the project's settings on GitHub look for the generated files to deploy in this folder.

To deploy, simply push to `master` branch.

# Building and Testing Locally
```bash
# build site.hs
stack build

# clean build
stack exec site clean
stack exec site build

# local deployment
stack exec site watch
```
